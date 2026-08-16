<div align="center">

# Openswap FFI Commons

Shared Rust and UniFFI core for the Openswap language bindings

[![License](https://img.shields.io/badge/license-MIT-blue.svg)](./LICENSE)
[![Rust 1.75+](https://img.shields.io/badge/rustc-1.75%2B-lightgrey.svg)](https://blog.rust-lang.org/2023/12/28/Rust-1.75.0.html)

</div>

## Overview

`ffi-commons` contains the Rust crate, UniFFI configuration, and helper tooling shared by the Kotlin, Swift, Python, Ruby, and React Native bindings. It is the source of truth for the exported taker API, data types, and generated foreign-language surfaces.

In normal use, you should build from the language package you are shipping. Each package owns the supported build scripts for staging native artifacts and regenerating bindings.

## Downstream Bindings

| Binding | Output directory | Runtime targets |
| --- | --- | --- |
| [openswap-kotlin](../openswap-kotlin) | `../openswap-kotlin/lib/src/main/` | Android `arm64-v8a`, `armeabi-v7a`, `x86_64`, JVM/Desktop |
| [openswap-swift](../openswap-swift) | `../openswap-swift/Sources/` and `../openswap-swift/openswap_ffi.xcframework` | iOS arm64, iOS simulator arm64/x86_64, macOS arm64/x86_64 |
| [openswap-python](../openswap-python) | `../openswap-python/src/openswap/` | Linux x86_64/aarch64, macOS x86_64/arm64, Windows amd64 |
| [openswap-ruby](../openswap-ruby) | `../openswap-ruby/` | Linux x86_64/aarch64, macOS x86_64/arm64 |
| [openswap-react-native](../openswap-react-native) | `../openswap-react-native/android/src/main/` and `../openswap-react-native/ios/` | Android `arm64-v8a`, `x86_64`; iOS arm64, iOS simulator arm64/x86_64 |

## Supported Build Model

The supported workflow is package-local:

- Kotlin builds are driven from `openswap-kotlin/build-scripts/` and then packaged with Gradle.
- Swift builds are driven from `openswap-swift/build-xcframework-dev.sh`, `build-xcframework-ci.sh`, or `build-xcframework.sh`.
- Python builds are driven from `openswap-python/build-scripts/` and then packaged with `python -m build`.
- Ruby builds are driven from `openswap-ruby/build-scripts/`.
- React Native TurboModule builds are driven from `openswap-react-native/build-scripts/`.

This keeps target selection, output layout, and packaging concerns next to the language consumer instead of centralizing them in a single monolithic script.

## Direct Core Development

Work directly in `ffi-commons` when you are changing the exported Rust API, UniFFI schema, or shared build logic.

### Prerequisites

- Rust 1.75.0 or newer.
- `cargo run --bin uniffi-bindgen` available from this workspace.
- Platform toolchains for the targets you intend to build.

### Example: Build a Shared Library Directly

```bash
cd ffi-commons
rustup target add x86_64-unknown-linux-gnu
cargo build --package openswap-ffi --profile release-smaller --target x86_64-unknown-linux-gnu
```

### Example: Generate Bindings Manually

```bash
cd ffi-commons
cargo run --bin uniffi-bindgen generate \
   --library ./target/x86_64-unknown-linux-gnu/release-smaller/libopenswap_ffi.so \
   --language python \
   --out-dir ../openswap-python/src/openswap/native/linux-x86_64 \
   --no-format
```

The package-local scripts wrap these steps and place outputs in the paths expected by each binding.

## Target Notes

### Android

- Minimum SDK: 24.
- Primary ABIs: `arm64-v8a`, `armeabi-v7a`, `x86_64`.
- Requires Android NDK for native builds.

### Apple Platforms

- Swift packaging targets iOS 13+ and macOS 10.15+.
- XCFramework builds combine device and simulator slices for the Apple consumers.

### Python

- Packaged native resources are staged under `src/openswap/native/<platform>/`.
- The Python package metadata declares Linux, macOS, and Windows native resources.

### Ruby

- Generated Ruby bindings live at the package root as `openswap.rb`.
- Native libraries are staged next to the binding for direct FFI loading.

### React Native (TurboModule)

- JavaScript surface and TurboModule spec live under `openswap-react-native/src/`.
- Android native bridge and JNI libraries are staged under `openswap-react-native/android/src/main/`.
- iOS native bridge and `openswap_ffi.xcframework` are staged under `openswap-react-native/ios/`.
- Live Legacy and Taproot swap tests are provided in `openswap-react-native/__tests__/` and use the shared docker regtest stack.

## Docker Test Environment

`ffi-docker-setup` provisions the local regtest environment used by the live integration flows:

```bash
cd ffi-commons
./ffi-docker-setup setup
./ffi-docker-setup start 4
./ffi-docker-setup stop
```

`start 4` brings up Bitcoin Core, Tor, and four maker services for end-to-end taker testing.

## Resources

- [UniFFI Documentation](https://mozilla.github.io/uniffi-rs/)
- [CoinSwap Protocol](https://gist.github.com/chris-belcher/9144bd57a91c194e332fb5ca371d0964)
- [Openswap Implementation](https://github.com/citadel-foss/openswap)

## Support

- Issues: [GitHub Issues](https://github.com/citadel-foss/openswap-ffi/issues)
- Discussions: [GitHub Discussions](https://github.com/citadel-foss/openswap/discussions)