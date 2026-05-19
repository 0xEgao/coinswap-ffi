import test from 'ava'
import { readFileSync } from 'node:fs'
import { dirname, join } from 'node:path'
import { fileURLToPath } from 'node:url'

const testDir = dirname(fileURLToPath(import.meta.url))
const packageRoot = join(testDir, '..')

function readPackageFile(path: string): string {
  return readFileSync(join(packageRoot, path), 'utf8')
}

test('public declarations do not expose money-moving amounts as unrestricted numbers', (t) => {
  const declarations = readPackageFile('index.d.ts')

  t.true(
    declarations.includes('export type PositiveSats'),
    'declarations should expose a positive-satoshi type for money-moving APIs',
  )
  t.false(
    /sendToAddress\([^)]*amount:\s*number/.test(declarations),
    'sendToAddress must not declare amount as an unrestricted number',
  )
  t.false(/sendAmount:\s*number/.test(declarations), 'SwapParams.sendAmount must not be unrestricted number')
})

test('napi taker boundary validates negative amounts before unsigned conversion', (t) => {
  const source = readPackageFile('src/taker.rs')

  t.true(source.includes('fn amount_to_sats(amount: i64) -> Result<u64>'))
  t.true(source.includes('u64::try_from(amount)'))
  t.false(source.includes('params.send_amount as u64'), 'SwapParams must use checked conversion')
  t.false(source.includes('amount as u64'), 'sendToAddress must use checked conversion')
})

test('wallet file names are validated as basenames before init or restore', (t) => {
  const source = readPackageFile('src/taker.rs')

  t.true(source.includes('fn validate_wallet_file_name(wallet_file_name: &str) -> Result<()>'))
  t.true(source.includes('wallet_file_name must be a non-empty basename'))
  t.true(source.includes('wallet_file_name.as_deref()'))
  t.true(source.includes('components.next().is_some()'))
})

test('native logging initialization is idempotent', (t) => {
  const source = readPackageFile('src/taker.rs')

  t.true(source.includes('console_error_panic_hook::set_once()'))
  t.true(source.includes('let _ = console_log::init_with_level'))
  t.false(source.includes('init_with_level(log::Level::Trace).expect'))
})

test('native loader does not honor environment-selected libraries by default', (t) => {
  const loader = readPackageFile('index.js')

  t.true(loader.includes('NAPI_RS_ALLOW_NATIVE_LIBRARY_PATH'))
  t.regex(loader, /NAPI_RS_NATIVE_LIBRARY_PATH.*NAPI_RS_ALLOW_NATIVE_LIBRARY_PATH === '1'/s)
})

test('musl detection uses an absolute ldd path', (t) => {
  const loader = readPackageFile('index.js')

  t.true(loader.includes("execSync('/usr/bin/ldd --version'"))
  t.false(loader.includes("execSync('ldd --version'"))
})
