# Make native logging initialization idempotent

- **Finding ID:** 6
- **Severity:** low
- **State:** validating
- **Scanner:** llm-code-review
- **File:** coinswap-js/src/taker.rs
- **Lines:** 143-143
- **CWE:** CWE-248
- **Verification Required:** true
- **Fingerprint:** 4b943775ec4fdecb4a1a46465027f401319a4a51bbcb589c5e937efa999e2a61

## Description

`Taker.initNativeLogging()` is exported to JavaScript as a static N-API method, but it calls `console_log::init_with_level(...).expect(...)`. Logger initialization is process-global; after any logger has already been installed, a later call returns an error. This wrapper turns that expected repeat-call condition into a Rust panic, so any JavaScript that can reach the binding can crash the Node/Electron host by calling `Taker.initNativeLogging()` twice or after another component has initialized logging. The impact is denial of service rather than data exposure, so I rate it low. I checked prior findings with `init_native_logging console_log init_with_level expect failed initialize console_log panic denial service` and found no duplicate.

## Proof of Concept

```diff
diff --git a/coinswap-js/src/taker.rs b/coinswap-js/src/taker.rs
index 04a8dad..b92c650 100644
--- a/coinswap-js/src/taker.rs
+++ b/coinswap-js/src/taker.rs
@@ -678,4 +678,16 @@ mod tests {
     println!("  cert_expiry: {:?}", bond.cert_expiry);
     println!("  is_spent: {}", bond.is_spent);
   }
+
+  #[test]
+  fn test_init_native_logging_is_idempotent() {
+    let _ = std::panic::catch_unwind(|| {
+      super::Taker::init_native_logging();
+    });
+
+    let second = std::panic::catch_unwind(|| {
+      super::Taker::init_native_logging();
+    });
+    assert!(second.is_ok(), "init_native_logging must not panic when logging was already initialized");
+  }
 }

```

## Suggested Fix

```diff
No suggested fix emitted yet.
```

