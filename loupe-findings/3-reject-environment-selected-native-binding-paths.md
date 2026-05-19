# Reject environment-selected native binding paths

- **Finding ID:** 3
- **Severity:** medium
- **State:** validating
- **Scanner:** llm-code-review
- **File:** coinswap-js/index.js
- **Lines:** 64-66
- **CWE:** CWE-829
- **Verification Required:** true
- **Fingerprint:** 1d22b1ce5f521daff90205458495f128e52fd71b180590f58a0fc9838ccf4698

## Description

`requireNative()` trusts `process.env.NAPI_RS_NATIVE_LIBRARY_PATH` before any platform-specific packaged binding and passes it directly to `require()`. Any caller that can influence this environment variable for a service, CLI wrapper, desktop app, or test runner that imports `coinswap-napi` can execute an arbitrary local JavaScript/native module at import time, before application code gets a chance to validate configuration. The loaded module only needs to export an object, so the package continues initialisation after the attacker payload runs. I searched prior findings for `NAPI_RS_NATIVE_LIBRARY_PATH requireNative arbitrary require code execution` and found no matching report. A fix should remove this production override or restrict it to a trusted, package-owned absolute path with an explicit opt-in unavailable in normal deployments.

## Proof of Concept

```diff
--- a/coinswap-js/__test__/index.spec.ts	2026-05-19 00:34:04
+++ b/coinswap-js/__test__/index.spec.ts	2026-05-19 00:39:05
@@ -1,4 +1,8 @@
 import test from 'ava'
+import { spawnSync } from 'node:child_process'
+import { existsSync, mkdtempSync, writeFileSync } from 'node:fs'
+import { tmpdir } from 'node:os'
+import { join, resolve } from 'node:path'
 
 import { plus100 } from '../index'
 
@@ -6,3 +10,21 @@
   const fixture = 42
   t.is(plus100(fixture), fixture + 100)
 })
+
+test('does not load a native binding from an attacker-controlled environment path', (t) => {
+  const dir = mkdtempSync(join(tmpdir(), 'coinswap-napi-env-'))
+  const marker = join(dir, 'executed')
+  const payload = join(dir, 'payload.cjs')
+  writeFileSync(
+    payload,
+    `require('node:fs').writeFileSync(${JSON.stringify(marker)}, 'owned'); module.exports = {}`,
+  )
+
+  spawnSync(process.execPath, ['-e', `require(${JSON.stringify(resolve('index.js'))})`], {
+    cwd: resolve('.'),
+    env: { ...process.env, NAPI_RS_NATIVE_LIBRARY_PATH: payload },
+    encoding: 'utf8',
+  })
+
+  t.false(existsSync(marker), 'importing the package executed the module named by NAPI_RS_NATIVE_LIBRARY_PATH')
+})

```

## Suggested Fix

```diff
No suggested fix emitted yet.
```

