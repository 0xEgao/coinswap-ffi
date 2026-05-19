# Reject negative amounts in SwapParams declarations

- **Finding ID:** 2
- **Severity:** medium
- **State:** validating
- **Scanner:** llm-code-review
- **File:** coinswap-js/index.d.ts
- **Lines:** 188-188
- **CWE:** CWE-681
- **Verification Required:** true
- **Fingerprint:** d7ef4ba77fd9213f9d29d3c2c2ec3e7554ba0515c031d0128393db7ffc1f0822

## Description

`SwapParams.sendAmount` controls the amount prepared for a coinswap, but the declaration exposes it as a plain `number` with no non-negative/integer contract. The local binding converts the declared object into native swap parameters in `src/taker.rs` and constructs `csAmount::from_sat(params.send_amount as u64)`, so a negative JavaScript value is converted to a huge unsigned satoshi amount before any local validation in this wrapper. If a TypeScript application accepts user-supplied swap amounts and relies on these declarations for its boundary contract, an attacker can supply a negative amount that crosses into native code as an unintended large spend request. I cannot inspect downstream crate internals outside this worktree, so the finding is limited to this wrapper boundary and flags the downstream wallet behavior as an assumption; the exploitable condition is that the signed-to-unsigned conversion is reachable from the public JS API without a non-negative amount contract. I searched prior findings for `SwapParams sendAmount negative number u64 prepareCoinswap` and `negative amount`; no duplicate was returned.

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

