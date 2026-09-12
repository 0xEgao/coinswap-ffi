import asyncio
from pathlib import Path
import sys
import tempfile
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from ci_socks_proxy import address, handle


class ProxyTests(unittest.IsolatedAsyncioTestCase):
    async def asyncSetUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.routes = Path(self.tmp.name) / "makers"
        self.onion = "a" * 56 + ".onion"
        self.tor_requests = []
        self.workers = set()
        self.real_tor = False
        self.backend = await self.server(self.echo)
        self.tor = await self.server(self.fake_tor)
        self.proxy = await self.server(self.proxy_client)
        self.routes.write_text(f"{self.onion} {self.backend}\n")

    async def server(self, handler):
        def track(reader, writer):
            task = asyncio.create_task(handler(reader, writer))
            self.workers.add(task)
            task.add_done_callback(self.workers.discard)
        server = await asyncio.start_server(track, "127.0.0.1", 0)
        self.addAsyncCleanup(server.wait_closed)
        self.addCleanup(server.close)
        return server.sockets[0].getsockname()[1]

    async def echo(self, reader, writer):
        try:
            while data := await reader.read(65536):
                writer.write(data)
                await writer.drain()
            writer.write(b"after-eof")
            await writer.drain()
        finally:
            writer.close()
            await writer.wait_closed()

    async def fake_tor(self, reader, writer):
        self.assertEqual(await reader.readexactly(3), b"\x05\x01\x00")
        writer.write(b"\x05\x00")
        self.assertEqual(await reader.readexactly(3), b"\x05\x01\x00")
        request, host, port = await address(reader)
        self.tor_requests.append((host.decode(), port))
        writer.write(b"\x05\x00\x00\x01" + bytes(6))
        await self.echo(reader, writer)

    async def proxy_client(self, reader, writer):
        await handle(reader, writer, self.routes, ("127.0.0.1", self.tor), self.real_tor)

    async def exchange(self, host, auth=False):
        reader, writer = await asyncio.open_connection("127.0.0.1", self.proxy)
        writer.write(b"\x05\x01" + bytes([2 if auth else 0]))
        self.assertEqual(await reader.readexactly(2), bytes([5, 2 if auth else 0]))
        if auth:
            writer.write(b"\x01\x01u\x01p")
            self.assertEqual(await reader.readexactly(2), b"\x01\x00")
        request = b"\x05\x01\x00\x03" + bytes([len(host)]) + host.encode() + b"\x00\x15"
        for byte in request:  # A CONNECT frame may arrive in separate TCP reads.
            writer.write(bytes([byte]))
            await writer.drain()
            await asyncio.sleep(0)
        self.assertEqual(await reader.readexactly(10), b"\x05\x00\x00\x01" + bytes(6))
        payload = bytes(range(256)) * 1024
        writer.write(payload)
        await writer.drain()
        writer.write_eof()
        self.assertEqual(await reader.read(), payload + b"after-eof")
        writer.close()
        await writer.wait_closed()
        await asyncio.sleep(0.01)
        self.assertFalse(self.workers, "connection handlers leaked after EOF")

    async def test_local_routing_and_authentication(self):
        await asyncio.wait_for(self.exchange(self.onion, auth=True), 5)
        self.assertEqual(self.tor_requests, [])

    async def test_fallback_and_real_tor_mode(self):
        await asyncio.wait_for(self.exchange("relay.example"), 5)
        self.real_tor = True
        await asyncio.wait_for(self.exchange(self.onion), 5)
        self.assertEqual(self.tor_requests, [("relay.example", 21), (self.onion, 21)])

    async def test_routes_reload_and_unsupported_auth(self):
        updated = self.routes.with_suffix(".tmp")
        updated.write_text("")
        updated.replace(self.routes)
        await asyncio.wait_for(self.exchange(self.onion), 5)
        self.assertEqual(self.tor_requests, [(self.onion, 21)])
        reader, writer = await asyncio.open_connection("127.0.0.1", self.proxy)
        writer.write(b"\x05\x01\x01")
        self.assertEqual(await asyncio.wait_for(reader.readexactly(2), 1), b"\x05\xff")
        await asyncio.wait_for(reader.read(), 1)
        writer.close()
        await writer.wait_closed()

    async def test_unreachable_maker_returns_failure(self):
        closed = await asyncio.start_server(self.echo, "127.0.0.1", 0)
        port = closed.sockets[0].getsockname()[1]
        closed.close()
        await closed.wait_closed()
        self.routes.write_text(f"{self.onion} {port}\n")
        reader, writer = await asyncio.open_connection("127.0.0.1", self.proxy)
        writer.write(b"\x05\x01\x00")
        self.assertEqual(await reader.readexactly(2), b"\x05\x00")
        writer.write(b"\x05\x01\x00\x03" + bytes([len(self.onion)]) + self.onion.encode() + b"\x00\x15")
        self.assertEqual(await asyncio.wait_for(reader.read(), 1), b"\x05\x01\x00\x01" + bytes(6))
        writer.close()
        await writer.wait_closed()
