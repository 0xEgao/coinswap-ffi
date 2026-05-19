# Constrain fallback native binding package resolution

- **Finding ID:** 4
- **Severity:** medium
- **State:** validating
- **Scanner:** llm-code-review
- **File:** coinswap-js/index.js
- **Lines:** 287-289
- **CWE:** CWE-829
- **Verification Required:** true
- **Fingerprint:** 7e9df12954d83bb74e469d6c71d735d1f0c7067623edefd616cc3c2cae7f7054

## Description

After a platform-local `.node` file fails to load, the generated loader falls back to bare package-name imports such as `require('coinswap-napi-linux-x64-gnu')` and then imports that package's `package.json`. Because these are normal Node module specifiers, they can resolve through caller-controlled search locations such as `NODE_PATH` or an ancestor `node_modules`, rather than a dependency that is pinned inside this package. A malicious package with the expected name and version can therefore execute as soon as an application imports `coinswap-napi`, even before any exported API is used. The same pattern exists for the other platform fallback package names. I searched prior findings for `coinswap-napi-linux-x64-gnu fallback package require dependency confusion` and found no matching report. The loader should only resolve packaged optional dependencies from a trusted dependency edge or package-owned location, and fail closed when the local artifact is absent.

## Proof of Concept

```diff
--- a/coinswap-js/__test__/index.spec.ts	2026-05-19 00:34:04
+++ b/coinswap-js/__test__/index.spec.ts	2026-05-19 00:39:43
@@ -1,4 +1,8 @@
 import test from 'ava'
+import { spawnSync } from 'node:child_process'
+import { existsSync, mkdtempSync, mkdirSync, writeFileSync } from 'node:fs'
+import { tmpdir } from 'node:os'
+import { join, resolve } from 'node:path'
 
 import { plus100 } from '../index'
 
@@ -6,3 +10,27 @@
   const fixture = 42
   t.is(plus100(fixture), fixture + 100)
 })
+
+test('does not load fallback native bindings from NODE_PATH-controlled packages', (t) => {
+  const dir = mkdtempSync(join(tmpdir(), 'coinswap-napi-nodepath-'))
+  const marker = join(dir, 'executed')
+  const packageDir = join(dir, 'coinswap-napi-linux-x64-gnu')
+  mkdirSync(packageDir)
+  writeFileSync(join(packageDir, 'package.json'), JSON.stringify({ name: 'coinswap-napi-linux-x64-gnu', version: '1.0.0', main: 'index.cjs' }))
+  writeFileSync(join(packageDir, 'index.cjs'), `require('node:fs').writeFileSync(${JSON.stringify(marker)}, 'owned'); module.exports = {}`)
+
+  spawnSync(
+    process.execPath,
+    [
+      '-e',
+      `Object.defineProperty(process, 'platform', { value: 'linux' }); Object.defineProperty(process, 'arch', { value: 'x64' }); require(${JSON.stringify(resolve('index.js'))})`,
+    ],
+    {
+      cwd: resolve('.'),
+      env: { ...process.env, NODE_PATH: dir, NAPI_RS_ENFORCE_VERSION_CHECK: '1' },
+      encoding: 'utf8',
+    },
+  )
+
+  t.false(existsSync(marker), 'importing the package executed a fallback binding resolved through NODE_PATH')
+})

```

## Suggested Fix

```diff
No suggested fix emitted yet.
```

