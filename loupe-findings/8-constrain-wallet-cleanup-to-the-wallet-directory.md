# Constrain wallet cleanup to the wallet directory

- **Finding ID:** 8
- **Severity:** low
- **State:** validating
- **Scanner:** llm-code-review
- **File:** coinswap-swift/Tests/CoinswapTests/LiveTestSupport.swift
- **Lines:** 114-119
- **CWE:** CWE-22
- **Verification Required:** true
- **Fingerprint:** 62e3a63283314a7b42b9a7705d09d4715181281a9f3d5b36d82a94cbb0788913

## Description

`cleanupCoinswapData` appends caller-controlled `walletName` to `~/.coinswap/taker/wallets` and deletes the resulting URL without rejecting `..`, absolute-looking names, or resolving and checking that the target remains under the wallets directory. A malicious wallet name such as `../some-dir` removes a sibling of `wallets`; with additional traversal components it can target other paths relative to the user's home directory when live tests run. Current in-tree tests pass constants, but the helper itself accepts arbitrary names and `LiveTestConfig` also has a wallet-name override, so the safety property depends on every caller preserving an invariant not enforced at the deletion sink. I searched prior findings for `LiveTestSupport cleanupCoinswapData walletName path traversal removeItem` and found no duplicate.

## Proof of Concept

```diff
diff --git a/coinswap-swift/Tests/CoinswapTests/LiveTestSupportCleanupSecurityTests.swift b/coinswap-swift/Tests/CoinswapTests/LiveTestSupportCleanupSecurityTests.swift
new file mode 100644
index 0000000..78c7fd7
--- /dev/null
+++ b/coinswap-swift/Tests/CoinswapTests/LiveTestSupportCleanupSecurityTests.swift
@@ -0,0 +1,28 @@
+import Foundation
+import XCTest
+
+final class LiveTestSupportCleanupSecurityTests: XCTestCase {
+    func testCleanupCoinswapDataRejectsWalletTraversalOutsideWalletDirectory() throws {
+        let fileManager = FileManager.default
+        let takerDir = URL(fileURLWithPath: NSHomeDirectory())
+            .appendingPathComponent(".coinswap/taker")
+        let walletsDir = takerDir.appendingPathComponent("wallets")
+        let escapedTarget = takerDir
+            .appendingPathComponent("coinswap-cleanup-traversal-\(UUID().uuidString)")
+
+        try fileManager.createDirectory(at: walletsDir, withIntermediateDirectories: true)
+        try fileManager.createDirectory(at: escapedTarget, withIntermediateDirectories: true)
+        defer {
+            try? fileManager.removeItem(at: escapedTarget)
+        }
+
+        let traversalName = "../\(escapedTarget.lastPathComponent)"
+
+        try cleanupCoinswapData(walletName: traversalName)
+
+        XCTAssertTrue(
+            fileManager.fileExists(atPath: escapedTarget.path),
+            "cleanupCoinswapData must not allow walletName to remove paths outside ~/.coinswap/taker/wallets"
+        )
+    }
+}

```

## Suggested Fix

```diff
No suggested fix emitted yet.
```

