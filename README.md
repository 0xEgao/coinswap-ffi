<div align="center">

# Openswap FFI

Language bindings for the Openswap protocol

</div>

## Overview

Openswap FFI packages the Openswap taker API for JavaScript, Kotlin, Swift, Python, Ruby, React Native, and C#/.NET. All bindings are backed by the same Rust implementation, so each language follows the same operational model: initialize a taker, sync wallet state and the offer book, inspect balances and UTXOs, execute swaps, and recover or back up state.

## Repository Layout

| Package | Purpose | Supported platforms | Build entry point |
| --- | --- | --- | --- |
| [openswap-js](./openswap-js) | Node.js and TypeScript binding via N-API | Linux x64/arm64, macOS x64/arm64, Windows x64/arm64, FreeBSD x64, Android arm64 | `yarn build` |
| [openswap-kotlin](./openswap-kotlin) | Kotlin binding for Android and JVM consumers | Android `arm64-v8a`, `armeabi-v7a`, `x86_64`; JVM/Desktop | `build-scripts/` |
| [openswap-swift](./openswap-swift) | Swift Package and XCFramework for Apple platforms | iOS arm64, iOS simulator arm64/x86_64, macOS arm64/x86_64 | `build-xcframework*.sh` |
| [openswap-python](./openswap-python) | Python package generated with UniFFI | Linux x86_64/aarch64, macOS x86_64/arm64, Windows amd64 | `build-scripts/` plus `python -m build` |
| [openswap-ruby](./openswap-ruby) | Ruby FFI binding generated with UniFFI | Linux x86_64/aarch64, macOS x86_64/arm64 | `build-scripts/` |
| [openswap-react-native](./openswap-react-native) | React Native TurboModule wrapper over UniFFI-generated native bindings | Android `arm64-v8a`, `x86_64`; iOS arm64, iOS simulator arm64/x86_64 | `build-scripts/` |
| [openswap-csharp](./openswap-csharp) | C#/.NET library generated with UniFFI and exposed through a stable managed wrapper | Linux x64/arm64, macOS x64/arm64, Windows x64/arm64 | `build-scripts/` plus `dotnet build` |
| [ffi-commons](./ffi-commons) | Shared Rust crate and UniFFI generation core | Rust build targets used by the bindings above | Consumed by package-local scripts |

## Build Workflow

Build each package from its own directory. The package-local scripts are now the supported entry points for generating bindings and assembling distributable artifacts.

### JavaScript

```bash
cd openswap-js
yarn install
yarn build
```

### Kotlin

Use the host-specific scripts in `openswap-kotlin/build-scripts/`, then package with Gradle.

### Swift

```bash
cd openswap-swift
bash ./build-xcframework.sh
swift build
```

### Python

Run the appropriate script under `openswap-python/build-scripts/`, then build the wheel or sdist with `python -m build`.

### Ruby

Run the appropriate script under `openswap-ruby/build-scripts/` to regenerate `openswap.rb` and the native library for the target platform.

### React Native

Run the appropriate script under `openswap-react-native/build-scripts/` to regenerate native bindings and stage Android/iOS artifacts.

### C#/.NET

Run the host-specific native build script, generate the managed bindings, and then build the .NET project. The generated bindings are not committed, so the generation step is required on a clean checkout.

See the [C# package README](./openswap-csharp/README.md) for the platform-specific commands and complete build sequence.

See the language-specific READMEs for the exact host and target combinations:

- [openswap-js](./openswap-js/README.md)
- [openswap-kotlin](./openswap-kotlin/README.md)
- [openswap-swift](./openswap-swift/README.md)
- [openswap-python](./openswap-python/README.md)
- [openswap-ruby](./openswap-ruby/README.md)
- [openswap-react-native](./openswap-react-native/README.md)
- [openswap-csharp](./openswap-csharp/README.md)
- [ffi-commons](./ffi-commons/README.md)

## Use Cases

- Desktop wallets built with Node.js, Electron, Tauri, Python, Ruby, or .NET.
- Native mobile integrations for Android and Apple platforms.
- Internal tooling and automation around wallet state, balances, and swap execution.

## Reference Implementation

The [taker-app](https://github.com/citadel-foss/taker-app) is the primary desktop reference implementation for the Node.js binding and is a useful integration reference for the unified taker workflow.

## Requirements

### Common

- Rust 1.75.0 or newer.
- Bitcoin Core with RPC access, fully synced, non-pruned, and `-txindex` enabled.
- Tor daemon for maker discovery and privacy-preserving network access.

### Package-specific

- Node.js 18+ for `openswap-js`.
- Android SDK / NDK and JDK for `openswap-kotlin`.
- Xcode 14+ and Swift 5.7+ for `openswap-swift`.
- Python 3.8+ for `openswap-python`.
- Ruby 2.7+ for `openswap-ruby`.
- React Native 0.76+ and Xcode/Android SDK toolchains for `openswap-react-native`.
- .NET SDK 8.0+ and Rust 1.88+ for `openswap-csharp`.

## Documentation

- [Openswap Protocol Specification](https://github.com/citadel-foss/OpenSwap-Protocol-Specification)
- [Core Openswap Library](https://github.com/citadel-foss/openswap)
- [UniFFI Documentation](https://mozilla.github.io/uniffi-rs/)

## Development Status

Beta software. These bindings remain under active development and should be treated as experimental. Mainnet deployment is not recommended.

## Contributing

Contributions are welcome. See the [main Openswap repository](https://github.com/citadel-foss/openswap) for contribution guidelines and protocol-level discussions.

## Acknowledgments

- [Chris Belcher's CoinSwap Design](https://gist.github.com/chris-belcher/9144bd57a91c194e332fb5ca371d0964)
- [NAPI-RS](https://napi.rs)
- [UniFFI](https://mozilla.github.io/uniffi-rs/)
