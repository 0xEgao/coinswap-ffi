# Validate wallet filename as basename

- **Finding ID:** 10
- **Severity:** medium
- **State:** validating
- **Scanner:** llm-code-review
- **File:** ffi-commons/src/taker.rs
- **Lines:** 135-138
- **CWE:** CWE-22
- **Verification Required:** true
- **Fingerprint:** 0fb4d17c453c1f38d99b5bdf8246341dceb10cd9f07ca6c9e7efa7e6ac185c86

## Description

`Taker::init` accepts `wallet_file_name` from the FFI caller and stores it directly in `TakerInitConfig` without checking that it is only a filename. The surrounding API documents this parameter as a wallet file name under the taker data directory, but the FFI boundary does not reject absolute paths or `..` components. If the wallet layer constructs a path from this value, a caller can escape the intended wallet namespace and cause the taker to open or create wallet state at attacker-chosen locations. That can expose another wallet file to the FFI caller or overwrite files reachable by the application. I cannot inspect the out-of-tree `coinswap` wallet path construction in this worktree, so I am reporting the missing boundary validation with that dependency assumption explicit. Prior search for `wallet_file_name path traversal Taker init ffi taker` returned no matching findings.

## Proof of Concept

```diff
diff --git a/ffi-commons/src/taker.rs b/ffi-commons/src/taker.rs
--- a/ffi-commons/src/taker.rs
+++ b/ffi-commons/src/taker.rs
@@ -636,3 +636,17 @@ impl Taker {
         Ok(addresses)
     }
 }
+
+#[cfg(test)]
+mod security_tests {
+    #[test]
+    fn init_rejects_path_components_in_wallet_file_name() {
+        let source = include_str!("taker.rs");
+
+        assert!(
+            source.contains("wallet_file_name")
+                && (source.contains("components()") || source.contains("MAIN_SEPARATOR"))
+                && (source.contains("ParentDir") || source.contains("is_absolute()")),
+            "Taker::init must validate wallet_file_name as a basename before passing it to the wallet layer"
+        );
+    }
+}

```

## Suggested Fix

```diff
No suggested fix emitted yet.
```

