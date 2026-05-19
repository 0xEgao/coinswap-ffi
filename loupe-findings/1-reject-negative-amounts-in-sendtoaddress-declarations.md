# Reject negative amounts in sendToAddress declarations

- **Finding ID:** 1
- **Severity:** medium
- **State:** validating
- **Scanner:** llm-code-review
- **File:** coinswap-js/index.d.ts
- **Lines:** 20-20
- **CWE:** CWE-681
- **Verification Required:** true
- **Fingerprint:** 6c6f5c54bb56803c00c1fc56e570f0afc0287751a4f8f371319829dbe794c491

## Description

`Taker.sendToAddress` is a fund-moving API, but the TypeScript declaration exposes its `amount` parameter as an unrestricted `number`. The local N-API implementation takes this as a signed `i64` and then calls the wallet with `amount as u64` in `src/taker.rs`, so a negative JavaScript amount is not rejected at this boundary before it is converted into a very large unsigned satoshi value. A TypeScript/Electron caller that relies on the package declaration as the security contract can therefore accept `-1` or another negative value and ask the wallet to construct a spend to an attacker-controlled address with an unintended huge amount. Whether the downstream wallet later fails depends on wallet state and out-of-tree behavior, but this binding does not enforce the invariant before the security-sensitive cast. I searched prior findings for `sendAmount amount negative number u64 cast send_to_address SwapParams` and `negative amount`; no duplicate was returned.

## Proof of Concept

```diff
diff --git a/coinswap-js/__test__/amount-types.spec.ts b/coinswap-js/__test__/amount-types.spec.ts
new file mode 100644
index 0000000..7399537
--- /dev/null
+++ b/coinswap-js/__test__/amount-types.spec.ts
@@ -0,0 +1,17 @@
+import test from 'ava'
+import { readFileSync } from 'node:fs'
+import { dirname, join } from 'node:path'
+import { fileURLToPath } from 'node:url'
+
+const declarations = readFileSync(join(dirname(fileURLToPath(import.meta.url)), '..', 'index.d.ts'), 'utf8')
+
+test('sendToAddress amount is not declared as an unrestricted number', (t) => {
+  t.false(
+    /sendToAddress\([^)]*amount:\s*number/.test(declarations),
+    'sendToAddress moves wallet funds and must not accept the same unrestricted number type that permits negative satoshi amounts',
+  )
+})
+
+test('SwapParams.sendAmount is not declared as an unrestricted number', (t) => {
+  t.false(/sendAmount:\s*number/.test(declarations), 'coinswap sendAmount must reject negative satoshi amounts at the TS boundary')
+})

```

## Suggested Fix

```diff
No suggested fix emitted yet.
```

