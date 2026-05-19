# Use absolute ldd path for musl detection

- **Finding ID:** 5
- **Severity:** low
- **State:** validating
- **Scanner:** llm-code-review
- **File:** coinswap-js/index.js
- **Lines:** 54-56
- **CWE:** CWE-426
- **Verification Required:** true
- **Fingerprint:** 77d0ef41d63af85a2625a7ecc5a59e17a55acb6633100bfaa9e68f7898a3743d

## Description

`isMuslFromChildProcess()` runs `execSync('ldd --version')` during package import when filesystem/report musl detection is unavailable. Because the command name is not absolute, the shell resolves `ldd` through `PATH`. In deployments where an attacker can influence the service environment or place a writable directory before the real system paths, importing `coinswap-napi` executes the attacker's `ldd` before any application code runs. This is distinct from the native binding package-loading issues: the sink is the child-process command used only for musl probing. I searched prior findings for `execSync ldd version PATH hijack isMuslFromChildProcess` and found no matching report. A fix should avoid spawning a shell, use an absolute trusted path, or remove this fallback and fail closed when musl status cannot be determined.

## Proof of Concept

```diff
--- a/coinswap-js/__test__/index.spec.ts	2026-05-19 00:34:04
+++ b/coinswap-js/__test__/index.spec.ts	2026-05-19 00:40:33
@@ -1,4 +1,8 @@
 import test from 'ava'
+import { spawnSync } from 'node:child_process'
+import { chmodSync, existsSync, mkdtempSync, writeFileSync } from 'node:fs'
+import { tmpdir } from 'node:os'
+import { delimiter, join, resolve } from 'node:path'
 
 import { plus100 } from '../index'
 
@@ -6,3 +10,26 @@
   const fixture = 42
   t.is(plus100(fixture), fixture + 100)
 })
+
+test('does not execute ldd from an attacker-controlled PATH during import', (t) => {
+  const dir = mkdtempSync(join(tmpdir(), 'coinswap-napi-path-'))
+  const marker = join(dir, 'executed')
+  const fakeLdd = join(dir, 'ldd')
+  writeFileSync(fakeLdd, `#!/bin/sh\necho owned > ${JSON.stringify(marker)}\necho musl\n`)
+  chmodSync(fakeLdd, 0o755)
+
+  spawnSync(
+    process.execPath,
+    [
+      '-e',
+      `Object.defineProperty(process, 'platform', { value: 'linux' }); Object.defineProperty(process, 'arch', { value: 'x64' }); Object.defineProperty(process, 'report', { value: undefined }); require(${JSON.stringify(resolve('index.js'))})`,
+    ],
+    {
+      cwd: resolve('.'),
+      env: { ...process.env, PATH: `${dir}${delimiter}${process.env.PATH ?? ''}` },
+      encoding: 'utf8',
+    },
+  )
+
+  t.false(existsSync(marker), 'importing the package executed ldd from PATH')
+})

```

## Suggested Fix

```diff
No suggested fix emitted yet.
```

