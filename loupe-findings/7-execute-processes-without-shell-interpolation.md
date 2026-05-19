# Execute processes without shell interpolation

- **Finding ID:** 7
- **Severity:** medium
- **State:** validating
- **Scanner:** llm-code-review
- **File:** coinswap-swift/Tests/CoinswapTests/LiveTestSupport.swift
- **Lines:** 69-71
- **CWE:** CWE-78
- **Verification Required:** true
- **Fingerprint:** 4a7029119253f80750c512d2e8350d0038cb7545bbe9008d488bc0a53d88cf38

## Description

`runProcess` builds a command line by joining `command` and every argument with spaces, then hands the result to `/bin/bash -c`. Any shell metacharacter in an argument is interpreted before the intended tool runs. `fundAddress` passes the wallet-derived Bitcoin address as one of those arguments; the Swift wrapper/binary target is outside this review scope, so the address format invariant is not locally enforceable here. A compromised or malicious address-producing path, or any future caller that passes untrusted input to this helper, can execute arbitrary commands in the developer or CI account running live tests. I searched prior findings for `LiveTestSupport runProcess bash command injection fundAddress address` and found no duplicate.

## Proof of Concept

```diff
diff --git a/coinswap-swift/Tests/CoinswapTests/LiveTestSupportRunProcessSecurityTests.swift b/coinswap-swift/Tests/CoinswapTests/LiveTestSupportRunProcessSecurityTests.swift
new file mode 100644
index 0000000..dfd097b
--- /dev/null
+++ b/coinswap-swift/Tests/CoinswapTests/LiveTestSupportRunProcessSecurityTests.swift
@@ -0,0 +1,17 @@
+import Foundation
+import XCTest
+
+final class LiveTestSupportRunProcessSecurityTests: XCTestCase {
+    func testRunProcessDoesNotInterpretArgumentShellMetacharacters() throws {
+        let marker = FileManager.default.temporaryDirectory
+            .appendingPathComponent("coinswap-shell-injection-\(UUID().uuidString)")
+        defer { try? FileManager.default.removeItem(at: marker) }
+
+        try runProcess(command: "/usr/bin/printf", args: ["ok; /usr/bin/touch \(marker.path)"])
+
+        XCTAssertFalse(
+            FileManager.default.fileExists(atPath: marker.path),
+            "runProcess must execute the requested program with literal arguments, not via a shell"
+        )
+    }
+}

```

## Suggested Fix

```diff
No suggested fix emitted yet.
```

