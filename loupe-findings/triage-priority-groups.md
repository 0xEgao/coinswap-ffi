# Loupe Findings Priority Triage

Assessment date: 2026-06-13

Validation rubric used:

- Attacker-controlled input reaches the reported boundary.
- The closest boundary lacks validation, canonicalization, or safe resolution.
- The sink can execute code, move wallet funds, write/read wallet files, delete files, or crash the host.
- The path is realistically reachable from an exported package/API or CI/live-test workflow.
- Downstream code either confirms the issue or does not clearly defeat it.

## Priority 1

### Issue A: Import-time arbitrary code execution in the JS native loader

Findings: 3, 4

Disposition: reportable, merge together

Affected locations:

- `coinswap-js/index.js:64`: `NAPI_RS_NATIVE_LIBRARY_PATH` is required directly.
- `coinswap-js/index.js:287`: fallback native binding packages are required by bare package name.

Evidence:

- Finding 3 was dynamically reproduced. A temp `payload.cjs` named by `NAPI_RS_NATIVE_LIBRARY_PATH` executed during `require("coinswap-js/index.js")`; marker file was created and the import exited successfully.
- Finding 4 was dynamically reproduced. A fake `coinswap-napi-linux-x64-gnu` package supplied through `NODE_PATH` executed during import; marker file was created and the import exited successfully.
- Both execute before any application-level policy or exported API call.

Priority rationale:

- This is the cleanest high-impact issue in the set: import-time code execution from environment/module-resolution influence.
- Finding 3 needs process environment control. Finding 4 can also be reached through dependency/module resolution mistakes or malicious ancestor search paths.

Recommended fix:

- Remove production support for arbitrary `NAPI_RS_NATIVE_LIBRARY_PATH`, or gate it behind an explicit development-only opt-in that refuses non-package-owned paths.
- Resolve optional native binding packages only through trusted package-owned dependency edges or bundled relative artifacts.
- Fail closed if the local binding is absent and the trusted optional dependency cannot be resolved.

### Issue B: Wallet filename traversal across production FFI wallet operations

Findings: 10, 11

Disposition: reportable, merge together with separate affected entrypoints

Affected locations:

- `ffi-commons/src/taker.rs:135`: `Taker::init` forwards `wallet_file_name` into `TakerInitConfig`.
- `ffi-commons/src/types.rs:751`: `restore_wallet_gui_app` forwards `wallet_file_name`.
- Dependency evidence: local Cargo checkout joins these values with `data_dir.join("wallets").join(wallet_file_name)` in `coinswap/src/taker/api.rs` and `coinswap/src/wallet/ffi.rs`.

Evidence:

- Static trace confirms the downstream assumption in the Loupe reports: the Git dependency constructs wallet paths by joining untrusted wallet names under `wallets` without basename validation.
- Absolute paths and `..` components can escape the intended wallet namespace before load/create/restore.
- Sibling coverage note: the N-API constructor and restore wrapper in `coinswap-js/src/taker.rs` appear to expose the same wallet-name issue and should be fixed with the same helper.

Priority rationale:

- Production exported FFI/API boundary.
- Potential arbitrary wallet file load/create/restore under app privileges, including restore writes.

Recommended fix:

- Add one shared wallet-name validator in `ffi-commons` and `coinswap-js` bindings.
- Accept only a non-empty basename with no path separators, absolute prefix, parent/current components, or platform separator variants.
- Apply it before constructing `TakerInitConfig` and before restore path construction.

## Priority 2

### Issue C: Signed-to-unsigned money amount conversion at exported spend/swap boundaries

Findings: 1, 2, 9

Disposition: reportable as one family, preserve separate entrypoints

Affected locations:

- `coinswap-js/src/taker.rs:46`: `SwapParams.send_amount: i64` is converted with `as u64`.
- `coinswap-js/src/taker.rs:516`: `send_to_address` converts `amount as u64`.
- `coinswap-js/index.d.ts:20` and `coinswap-js/index.d.ts:188`: TypeScript exposes unrestricted `number` for these values.
- `ffi-commons/src/taker.rs:507`: UniFFI `send_to_address` converts `amount as u64`.

Evidence:

- Static trace confirms negative JS/N-API amounts can cross the wrapper boundary and become huge satoshi values before wallet logic sees them.
- The coinswap dependency later performs balance checks and coin selection, so common low-balance cases likely fail. That lowers exploitability but does not fix the broken boundary invariant.
- Finding 1 is not just a declaration issue; it should be rooted in the N-API implementation cast and use the declaration as reachability/contract evidence.
- Finding 9 is the same bug class in the UniFFI spend API, not a duplicate of the JS binding.

Priority rationale:

- Fund-moving API invariant violation.
- Practical exploitability depends on wallet balance and downstream behavior, so this sits below the code-execution and path-traversal issues.

Recommended fix:

- Reject negative and non-integer amounts at the language boundary.
- In Rust, replace `amount as u64` with `u64::try_from(amount)` plus clear API errors.
- In TypeScript, document or brand satoshi amounts as non-negative integers; runtime checks should still live in Rust.

### Issue D: Shell interpolation in Swift live-test process helper

Finding: 7

Disposition: reportable, test/CI scoped

Affected location:

- `coinswap-swift/Tests/CoinswapTests/LiveTestSupport.swift:69`: builds a command string and runs `/bin/bash -c`.

Evidence:

- Static trace confirms every argument is joined with spaces and interpreted by a shell.
- Current callsites mainly pass constants plus a wallet-derived address, but the helper itself is reusable and live tests can run in developer/CI environments.

Priority rationale:

- Command injection is high impact in the CI/developer account, but this is not a production runtime path.

Recommended fix:

- Set `Process.executableURL` to the target binary directly.
- Pass arguments through `process.arguments` without shell wrapping.
- If shell behavior is ever needed, use a separate explicitly named helper for trusted commands only.

### Issue E: PATH hijack in Linux musl detection

Finding: 5

Disposition: reportable, lower-priority sibling of loader hardening

Affected location:

- `coinswap-js/index.js:54`: `execSync("ldd --version")` resolves `ldd` through `PATH` and uses a shell.

Evidence:

- Dynamically reproduced by prepending a temp directory containing fake `ldd`; importing the package executed the fake command and created a marker file.
- The import failed afterward because the fake command forced the musl path without a native binding, but execution had already occurred.

Priority rationale:

- Import-time command execution, but requires PATH influence and Linux fallback conditions. Fix alongside Issue A.

Recommended fix:

- Avoid spawning `ldd`.
- Prefer filesystem/report detection only, or execute a trusted absolute path without a shell and with controlled environment.

## Priority 3

### Issue F: Swift live-test wallet cleanup path traversal

Finding: 8

Disposition: reportable, test-only destructive-file risk

Affected location:

- `coinswap-swift/Tests/CoinswapTests/LiveTestSupport.swift:115`: appends arbitrary `walletName` before `removeItem`.

Evidence:

- Static trace confirms `walletName` is appended without basename validation or containment checks.
- Current tests use constants, but `LiveTestConfig` accepts a wallet-name override.

Priority rationale:

- Can delete paths outside `~/.coinswap/taker/wallets`, but the path is test support only.

Recommended fix:

- Reuse the same basename validator as production wallet names.
- Resolve the target and verify it remains under the wallets directory before deletion.

### Issue G: Non-idempotent native logging initialization can panic

Finding: 6

Disposition: reportable as low-priority robustness/DoS

Affected location:

- `coinswap-js/src/taker.rs:143`: `console_log::init_with_level(...).expect(...)`.

Evidence:

- Static trace confirms exported `Taker.initNativeLogging()` panics if logging has already been initialized.
- Impact is local process denial of service from JS/Electron code that can call the method.

Priority rationale:

- No data exposure or fund movement.
- Easy to trigger accidentally or intentionally, but low security impact.

Recommended fix:

- Replace `expect` with idempotent initialization, e.g. ignore the already-initialized case or use a `Once`.
- Return a JS error only for unexpected initialization failures.

## Suggested Fix Order

1. Fix Issue A and Issue E together in `coinswap-js/index.js`.
2. Add shared wallet basename validation and apply it to Issue B plus the JS sibling constructors/restore wrappers.
3. Replace all signed amount casts with checked conversions and runtime validation for Issue C.
4. Replace Swift test shell execution with direct `Process` invocation for Issue D.
5. Add containment checks to Swift cleanup for Issue F.
6. Make native logging initialization idempotent for Issue G.

## Closure Table

| Finding | Group | Disposition | Confidence | Notes |
| --- | --- | --- | --- | --- |
| 1 | Issue C | reportable | medium | Merge into signed amount validation; root in N-API cast, declaration is supporting evidence. |
| 2 | Issue C | reportable | medium | Same JS/N-API signed amount family for `prepareCoinswap`. |
| 3 | Issue A | reportable | high | Dynamically reproduced import-time execution via env-selected path. |
| 4 | Issue A | reportable | high | Dynamically reproduced import-time execution via bare fallback package resolution. |
| 5 | Issue E | reportable | high | Dynamically reproduced PATH-selected `ldd` execution. |
| 6 | Issue G | reportable | medium | Static proof of exported panic/DoS path. |
| 7 | Issue D | reportable | medium | Static proof; scoped to live tests/CI. |
| 8 | Issue F | reportable | medium | Static proof; scoped to live-test cleanup. |
| 9 | Issue C | reportable | medium | UniFFI spend API signed amount conversion. |
| 10 | Issue B | reportable | high | Dependency source confirms unsafe wallet path join. |
| 11 | Issue B | reportable | high | Dependency source confirms unsafe restore path join. |
