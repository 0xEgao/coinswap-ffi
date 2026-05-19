# Validate restored wallet names before path construction

- **Finding ID:** 11
- **Severity:** medium
- **State:** validating
- **Scanner:** llm-code-review
- **File:** ffi-commons/src/types.rs
- **Lines:** 751-756
- **CWE:** CWE-22
- **Verification Required:** true
- **Fingerprint:** 46337e6ab2598bd2b9edfc78df990f81075ab6dc68c76f0d2244e3ecbb8d8f2f

## Description

`restore_wallet_gui_app` exposes `wallet_file_name` through UniFFI and forwards it unchanged to the underlying wallet restore helper. This wrapper documents that the destination is constructed as `{data_dir_or_default}/wallets/{wallet_file_name_or_default}`, but it does not reject absolute names, `..`, or path separators before handing the value off. A malicious or compromised FFI caller can therefore ask the restore path to escape the intended wallet directory and restore wallet material or overwrite files elsewhere under the process privileges, assuming the out-of-tree `coinswap::wallet::ffi::restore_wallet_gui_app` joins the name as documented. I could not inspect that dependency source in this worktree, so the report is intentionally scoped to the missing boundary validation in this file. Prior searches for `restore_wallet_gui_app wallet_file_name path traversal` found no duplicate findings.

## Proof of Concept

```diff
diff --git a/ffi-commons/src/types.rs b/ffi-commons/src/types.rs
index 55f3a57..2f7f1fb 100644
--- a/ffi-commons/src/types.rs
+++ b/ffi-commons/src/types.rs
@@ -789,3 +789,46 @@ pub fn setup_logging(data_dir: Option<String>) -> Result<(), TakerError> {
     coinswap::utill::setup_taker_logger(log::LevelFilter::Info, false, path);
     Ok(())
 }
+
+#[cfg(test)]
+mod tests {
+    use super::*;
+
+    #[test]
+    fn restore_wallet_rejects_traversal_wallet_name_before_reading_backup() {
+        let mut data_dir = std::env::temp_dir();
+        data_dir.push(format!(
+            "coinswap-ffi-restore-test-{}",
+            std::process::id()
+        ));
+        std::fs::create_dir_all(&data_dir).unwrap();
+
+        let mut missing_backup = data_dir.clone();
+        missing_backup.push("missing-backup.json");
+
+        let result = std::panic::catch_unwind(|| {
+            restore_wallet_gui_app(
+                Some(data_dir.to_string_lossy().into_owned()),
+                Some("../outside-wallet".to_string()),
+                create_default_rpc_config(),
+                missing_backup.to_string_lossy().into_owned(),
+                None,
+            );
+        });
+
+        let panic_message = match result {
+            Ok(()) => String::new(),
+            Err(payload) => {
+                if let Some(message) = payload.downcast_ref::<String>() {
+                    message.clone()
+                } else if let Some(message) = payload.downcast_ref::<&'static str>() {
+                    (*message).to_string()
+                } else {
+                    String::new()
+                }
+            }
+        };
+
+        assert!(
+            panic_message.contains("wallet_file_name")
+                && panic_message.contains("path traversal"),
+            "restore_wallet_gui_app must reject path traversal in wallet_file_name before using the backup path; got panic: {panic_message:?}"
+        );
+    }
+}

```

## Suggested Fix

```diff
No suggested fix emitted yet.
```

