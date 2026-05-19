# Reject negative send amounts before unsigned cast

- **Finding ID:** 9
- **Severity:** medium
- **State:** validating
- **Scanner:** llm-code-review
- **File:** ffi-commons/src/taker.rs
- **Lines:** 507-508
- **CWE:** CWE-195
- **Verification Required:** true
- **Fingerprint:** 59dc62a47d821e42b956f2c2f6867cab5fa02e049f11e1f8995d71035835cbcb

## Description

The UniFFI `Taker::send_to_address` method accepts `amount` as a signed `i64`, but forwards it to the wallet by casting with `amount as u64`. A caller crossing the FFI boundary can supply a negative amount; Rust then wraps it into a very large positive satoshi value before the wallet layer sees it. This violates the FFI boundary's money-value validation and can make downstream fee/selection/change logic operate on an attacker-chosen wrapped value instead of rejecting the request. I cannot inspect the out-of-tree `coinswap` dependency in this worktree, so I am not assuming its wallet implementation safely rejects every wrapped value before any security-sensitive behavior. The FFI wrapper should perform a checked conversion and reject `amount < 0` before calling `send_to_address`. Prior search for `send_to_address amount as u64 negative ffi taker` returned no matching findings.

## Proof of Concept

```diff
diff --git a/ffi-commons/src/taker.rs b/ffi-commons/src/taker.rs
--- a/ffi-commons/src/taker.rs
+++ b/ffi-commons/src/taker.rs
@@ -636,3 +636,18 @@ impl Taker {
         Ok(addresses)
     }
 }
+
+#[cfg(test)]
+mod security_tests {
+    #[test]
+    fn send_to_address_rejects_negative_amount_before_wallet_call() {
+        let source = include_str!("taker.rs");
+
+        assert!(
+            !source.contains(".send_to_address(\n                amount as u64,"),
+            "send_to_address must reject negative FFI amounts instead of casting them to u64"
+        );
+        assert!(
+            source.contains("u64::try_from(amount)") || source.contains("amount.try_into()"),
+            "the FFI boundary should perform a checked i64-to-u64 conversion before spending"
+        );
+    }
+}

```

## Suggested Fix

```diff
No suggested fix emitted yet.
```

