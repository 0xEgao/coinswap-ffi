"""CI-only SOCKS5 routing: local maker onions bypass public Tor circuits."""
import asyncio
import os
from pathlib import Path


async def address(reader):
    kind = await reader.readexactly(1)
    size = {b"\x01": 4, b"\x04": 16}.get(kind)
    prefix = b""
    if kind == b"\x03":
        prefix = await reader.readexactly(1)
        size = prefix[0]
    if size is None:
        raise ValueError("unsupported SOCKS address type")
    host = await reader.readexactly(size)
    port = await reader.readexactly(2)
    return kind + prefix + host + port, host, int.from_bytes(port, "big")


async def negotiate(reader, writer):
    version, count = await reader.readexactly(2)
    methods = await reader.readexactly(count)
    method = 0 if 0 in methods else 2 if 2 in methods else 255
    writer.write(bytes([5, method]))
    await writer.drain()
    if version != 5 or method == 255:
        raise ValueError("unsupported SOCKS authentication")
    # Accept isolation credentials from the native SOCKS client in this test fixture.
    if method == 2:
        version, size = await reader.readexactly(2)
        await reader.readexactly(size)
        size = (await reader.readexactly(1))[0]
        await reader.readexactly(size)
        if version != 1:
            raise ValueError("invalid SOCKS authentication version")
        writer.write(b"\x01\x00")
    if await reader.readexactly(3) != b"\x05\x01\x00":
        raise ValueError("only SOCKS5 CONNECT is supported")
    return await address(reader)


async def pump(reader, writer):
    while data := await reader.read(65536):
        writer.write(data)
        await writer.drain()
    if writer.can_write_eof():
        writer.write_eof()
        await writer.drain()


async def handle(reader, writer, routes, tor=("127.0.0.1", 19050), real_tor=False):
    upstream = None
    tasks = []
    connected = False
    try:
        request, host, port = await asyncio.wait_for(negotiate(reader, writer), 10)
        mapping = dict(line.split() for line in routes.read_text().splitlines())
        name = host.decode("ascii") if request[0] == 3 else ""
        local_port = mapping.get(name) if not real_tor and port == 21 else None
        if local_port:
            peer, upstream = await asyncio.wait_for(
                asyncio.open_connection("127.0.0.1", int(local_port)), 10)
            print(f"Local maker: {name}:{port} -> 127.0.0.1:{local_port}", flush=True)
        else:
            peer, upstream = await asyncio.wait_for(asyncio.open_connection(*tor), 10)
            upstream.write(b"\x05\x01\x00")
            await upstream.drain()
            if await asyncio.wait_for(peer.readexactly(2), 10) != b"\x05\x00":
                raise ValueError("Tor rejected SOCKS authentication")
            upstream.write(b"\x05\x01\x00" + request)
            await upstream.drain()
            reply = await asyncio.wait_for(peer.readexactly(3), 30)
            bound, _, _ = await asyncio.wait_for(address(peer), 10)
            if reply != b"\x05\x00\x00":
                writer.write(reply + bound)
                await writer.drain()
                return
        writer.write(b"\x05\x00\x00\x01" + bytes(6))
        await writer.drain()
        connected = True
        tasks = [asyncio.create_task(pump(reader, upstream)),
                 asyncio.create_task(pump(peer, writer))]
        await asyncio.gather(*tasks)
    except (OSError, ValueError, asyncio.IncompleteReadError, asyncio.TimeoutError) as error:
        if not isinstance(error, asyncio.IncompleteReadError) or error.partial:
            print(f"SOCKS connection failed: {error}", flush=True)
        if not connected:
            writer.write(b"\x05\x01\x00\x01" + bytes(6))
    finally:
        for task in tasks:
            task.cancel()
        await asyncio.gather(*tasks, return_exceptions=True)
        for stream in (upstream, writer):
            if stream:
                stream.close()
                try:
                    await stream.wait_closed()
                except OSError:
                    pass


async def main():
    routes = Path("/routes/makers")
    real_tor = os.environ.get("OPENSWAP_REAL_TOR") == "1"
    server = await asyncio.start_server(
        lambda r, w: handle(r, w, routes, real_tor=real_tor), "0.0.0.0", 9050)
    print(f"CI SOCKS proxy ready; real Tor mode: {real_tor}", flush=True)
    async with server:
        await server.serve_forever()


if __name__ == "__main__":
    asyncio.run(main())
