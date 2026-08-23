import Foundation
import XCTest
import Openswap

/// Live swap suite covering the full backend x protocol matrix.
///
/// CI filters each method into a separate XCTest process while keeping the
/// Docker stack alive. This prevents completed takers from retaining Tor
/// resources needed by a later scenario.
final class LiveSwapTests: XCTestCase {
    /// Sats swapped per taker (funded with 1.0 BTC, well above this).
    private let swapAmount: UInt64 = 500_000
    private let makerCount: UInt32 = 2
    private static let makerContainers = ["openswap-makerd1", "openswap-makerd2"]
    private static let retentionLock = NSLock()
    /// Keep native takers alive until this dedicated test process exits. Their
    /// upstream watcher destructor can otherwise block the language-binding CI.
    private static var liveTakers: [Taker] = []

    func testLegacyRpc() throws {
        try runSwap(name: "legacyRpc", backend: .rpc, protocol: "Legacy",
                    addrType: "P2WPKH", wallet: "swift_legacy_rpc_wallet")
    }

    func testTaprootRpc() throws {
        try runSwap(name: "taprootRpc", backend: .rpc, protocol: "Taproot",
                    addrType: "P2TR", wallet: "swift_taproot_rpc_wallet")
    }

    func testLegacyElectrum() throws {
        try runSwap(name: "legacyElectrum", backend: .electrum, protocol: "Legacy",
                    addrType: "P2WPKH", wallet: "swift_legacy_electrum_wallet")
    }

    func testTaprootElectrum() throws {
        try runSwap(name: "taprootElectrum", backend: .electrum, protocol: "Taproot",
                    addrType: "P2TR", wallet: "swift_taproot_electrum_wallet")
    }

    /// Runs one taker end-to-end for the given backend/protocol/address type.
    private func runSwap(
        name: String,
        backend: Backend,
        protocol proto: String,
        addrType: String,
        wallet: String
    ) throws {
        try requireLiveTestsEnabled()
        print("\n=== \(name) (\(backend) / \(proto) / \(addrType)) ===")
        try cleanupOpenswapData(walletName: wallet)

        let config = try LiveTestConfig(walletNameOverride: wallet)

        // RPC backend: RpcConfig + backendConfig nil.
        // Electrum backend: rpcConfig nil + electrum BackendConfig.
        let rpcConfig: RpcConfig? = backend == .rpc ? config.rpcConfig : nil
        let backendConfig: BackendConfig? = backend == .electrum ? electrumBackendConfig() : nil
        let makerAddresses = try localMakerAddresses()

        let taker = try Taker.`init`(
            dataDir: config.dataDir,
            walletFileName: config.walletName,
            rpcConfig: rpcConfig,
            controlPort: config.torControlPort,
            torAuthPassword: config.torAuthPassword,
            zmqAddr: config.zmqAddr,
            password: config.walletPassword,
            // Public Nostr cannot isolate concurrent, independent regtest jobs.
            nostrRelays: [],
            backendConfig: backendConfig
        )
        Self.retentionLock.lock()
        Self.liveTakers.append(taker)
        Self.retentionLock.unlock()

        try taker.setupLogging(dataDir: config.dataDir, logLevel: "Info")
        try waitForSuitableMakers(
            taker, name: name, protocol: proto, addresses: makerAddresses)
        XCTAssertEqual(try taker.getWalletName(), config.walletName)

        // Fund with 0.25 BTC across 4 fresh external addresses (1.0 BTC total),
        // then wait for the balance to become spendable (tolerates Electrum lag).
        try fundFreshAddresses(taker, addrType: addrType, config: config)
        let funded = try waitForSpendable(taker, target: Int64(swapAmount))
        XCTAssertGreaterThanOrEqual(
            funded.spendable, Int64(swapAmount),
            "\(name): spendable should cover the swap amount")

        // 2-maker openswap, single funding tx, 1 required confirmation.
        let params = SwapParams(
            protocol: proto,
            sendAmount: swapAmount,
            makerCount: makerCount,
            txCount: 1,
            requiredConfirms: 1,
            manuallySelectedOutpoints: nil,
            preferredMakers: makerAddresses,
            paymentAddress: nil
        )
        let swapId = try taker.prepareOpenswap(swapParams: params)
        let report = try taker.startOpenswap(swapId: swapId)

        XCTAssertEqual(
            report.makersCount, 2,
            "\(name): swap should route through 2 makers")
        // `status` is a display string (may carry ANSI color); match on content.
        XCTAssertTrue(
            report.status.uppercased().contains("SUCCESS"),
            "\(name): swap status was \(report.status)")

        print("✓ \(name) passed (swap_id \(report.swapId))")
        fflush(stdout)
    }

    /// Read the two onion addresses belonging to this job's Docker stack.
    private func localMakerAddresses() throws -> [String] {
        let marker = "Generated new Tor Hidden Service Hostname:"
        return try Self.makerContainers.map { container in
            let logs = try runProcess(command: "docker", args: ["logs", container])
            let matches = logs.split(whereSeparator: \.isNewline).compactMap { line -> String? in
                guard let markerRange = line.range(of: marker) else { return nil }
                return line[markerRange.upperBound...].split(whereSeparator: \.isWhitespace)
                    .first.map(String.init)
            }
            guard let address = matches.last else {
                throw NSError(
                    domain: "OpenswapLiveTests", code: 1,
                    userInfo: [NSLocalizedDescriptionKey:
                        "\(container): maker onion address not found in logs"])
            }
            return address
        }
    }

    /// Poll only this job's makers and wait for two usable offers.
    private func waitForSuitableMakers(
        _ taker: Taker, name: String, protocol proto: String, addresses: [String]
    ) throws {
        let attempts = 3
        var suitableCount = 0

        for attempt in 1...attempts {
            for address in addresses {
                do {
                    print("  polling local maker \(address)")
                    _ = try taker.pollMaker(address: address)
                } catch {
                    print("  poll failed for \(address): \(error)")
                }
            }

            let offerbook = try taker.fetchOffers()
            let suitable = offerbook.makers.filter { maker in
                maker.state.stateType == "Good"
                    && (maker.protocol?.protocolType == proto
                        || maker.protocol?.protocolType == "Unified")
                    && maker.offer != nil
                    && maker.offer!.minSize <= Int64(swapAmount)
                    && Int64(swapAmount) <= maker.offer!.maxSize
            }
            suitableCount = suitable.count
            print(
                "\(name): offerbook attempt \(attempt)/\(attempts): " +
                "\(offerbook.makers.count) total, \(suitableCount) suitable \(proto) makers")
            for maker in offerbook.makers {
                let makerProtocol = maker.protocol?.protocolType ?? "None"
                let amountRange = maker.offer.map {
                    "\($0.minSize)..\($0.maxSize) sats"
                } ?? "no offer"
                print(
                    "  \(maker.address.address): state=\(maker.state.stateType), " +
                    "protocol=\(makerProtocol), amount=\(amountRange)")
            }
            fflush(stdout)

            if suitableCount >= Int(makerCount) { return }
            if attempt < attempts { Thread.sleep(forTimeInterval: 10) }
        }

        throw NSError(
            domain: "OpenswapLiveTests", code: 1,
            userInfo: [NSLocalizedDescriptionKey:
                "\(name): expected \(makerCount) suitable \(proto) makers for " +
                "\(swapAmount) sats, found \(suitableCount)"])
    }

    /// Funds `taker` with 0.25 BTC across 4 fresh external addresses.
    private func fundFreshAddresses(
        _ taker: Taker, addrType: String, config: LiveTestConfig
    ) throws {
        for _ in 0..<4 {
            let addr = try taker.getNextExternalAddress(
                addressType: AddressType(addrType: addrType)
            ).addr
            try runProcess(command: "docker", args: [
                "exec", config.dockerContainer, "bitcoin-cli",
                "-\(config.bitcoinNetwork)",
                "-rpcport=\(config.bitcoinRpcPort)",
                "-rpcwallet=\(config.fundingWallet)",
                "-rpcuser=user", "-rpcpassword=password",
                "sendtoaddress", addr, "0.25",
            ])
        }
        Thread.sleep(forTimeInterval: 1.0)
    }
}
