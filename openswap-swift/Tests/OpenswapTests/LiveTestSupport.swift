import Foundation
import XCTest
import Openswap

struct LiveTestConfig {
    let rpcConfig: RpcConfig
    let zmqAddr: String
    let walletName: String
    let dataDir: String?
    let walletPassword: String?
    let torControlPort: UInt16
    let torAuthPassword: String
    let bitcoinNetwork: String
    let dockerContainer: String
    let fundingWallet: String
    let bitcoinRpcPort: String

    init(walletNameOverride: String? = nil) throws {
        let walletName = walletNameOverride ?? "swift_test_wallet"

        self.rpcConfig = RpcConfig(url: "127.0.0.1:18442", username: "user", password: "password", walletName: walletName)
        self.zmqAddr = "tcp://127.0.0.1:28332"
        self.walletName = walletName
        self.dataDir = nil
        self.walletPassword = "ffi-live-test-wallet-password"
        self.torControlPort = 9051
        self.torAuthPassword = "openswap"
        self.bitcoinNetwork = "regtest"
        self.dockerContainer = "openswap-bitcoind"
        self.fundingWallet = "test"
        self.bitcoinRpcPort = "18442"
    }
}

func requireLiveTestsEnabled() throws {
    let disabled = ProcessInfo.processInfo.environment["OPENSWAP_LIVE_TESTS"] == "0"
    if disabled {
        throw XCTSkip("Set OPENSWAP_LIVE_TESTS=1 to disable the live tests")
    }
}

/// Backend selection for a live swap run.
enum Backend {
    case rpc
    case electrum
}

/// Electrum backend config pointing at the Docker regtest electrs server.
/// RPC backend is expressed via `RpcConfig` + `backendConfig: nil` instead.
func electrumBackendConfig() -> BackendConfig {
    BackendConfig(
        kind: "electrum",
        url: "tcp://localhost:50001",
        username: nil,
        password: nil,
        walletName: nil,
        zmqAddr: nil,
        socks5: nil,
        timeout: nil,
        pollIntervalSecs: nil,
        maxRetries: nil
    )
}

/// Polls `syncAndSave` + `getBalances` until spendable reaches `target`.
/// Needed because the Electrum backend lags electrs indexing; ~30 tries / 3s.
func waitForSpendable(_ taker: Taker, target: Int64) throws -> Balances {
    for _ in 0..<30 {
        try taker.syncAndSave()
        let balances = try taker.getBalances()
        if balances.spendable >= target {
            return balances
        }
        Thread.sleep(forTimeInterval: 3.0)
    }
    return try taker.getBalances()
}

@discardableResult
func runProcess(command: String, args: [String]) throws -> String {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/bin/bash")
    let fullCommand = ([command] + args).joined(separator: " ")
    process.arguments = ["-c", fullCommand]

    let pipe = Pipe()
    process.standardOutput = pipe
    process.standardError = pipe

    try process.run()
    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    process.waitUntilExit()
    let output = String(data: data, encoding: .utf8) ?? ""

    if process.terminationStatus != 0 {
        throw NSError(domain: "OpenswapLiveTests", code: Int(process.terminationStatus), userInfo: [
            NSLocalizedDescriptionKey: "Command failed: \(command) \(args.joined(separator: " "))\n\(output)"
        ])
    }
    return output
}

/// Cleans up a specific wallet in ~/.openswap/taker/wallets before running tests.
func cleanupOpenswapData(walletName: String) throws {
    let fileManager = FileManager.default
    let walletPath = URL(fileURLWithPath: NSHomeDirectory())
        .appendingPathComponent(".openswap/taker/wallets")
        .appendingPathComponent(walletName)

    if fileManager.fileExists(atPath: walletPath.path) {
        try fileManager.removeItem(at: walletPath)
        print("[INFO] Cleaned up wallet: \(walletPath.path)")
    }
}
