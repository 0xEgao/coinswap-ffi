#!/bin/bash

set -euo pipefail

HEADER_BASENAME="OpenswapFFI"
TARGETDIR="../ffi-commons/target"
NAME="openswap_ffi"
PROFILE_DIR="debug"
SWIFT_OUT_DIR="../openswap-swift/Sources/Openswap"
MACOS_DEPLOYMENT_TARGET="10.15"

MAC_TARGET="x86_64-apple-darwin"
# MAC_TARGET="aarch64-apple-darwin"

cd ../ffi-commons/ || exit

rustup component add rust-src
rustup target add "$MAC_TARGET"

MACOSX_DEPLOYMENT_TARGET="${MACOS_DEPLOYMENT_TARGET}" cargo build --package openswap-ffi --target "$MAC_TARGET"

# # Copy dylib to Sources/OpenswapFFI
# mkdir -p ../openswap-swift/Sources/OpenswapFFI
# cp ./target/$MAC_TARGET/$PROFILE_DIR/lib${NAME}.dylib ../openswap-swift/Sources/OpenswapFFI/

UNIFFI_LIBRARY_PATH="./target/$MAC_TARGET/$PROFILE_DIR/lib${NAME}.dylib"
cargo run --bin uniffi-bindgen generate \
    --library "${UNIFFI_LIBRARY_PATH}" \
    --language swift \
    --out-dir "${SWIFT_OUT_DIR}" \
    --no-format

mkdir -p "$SWIFT_OUT_DIR/${HEADER_BASENAME}"
mv "$SWIFT_OUT_DIR/${HEADER_BASENAME}.h" "$SWIFT_OUT_DIR/${HEADER_BASENAME}/${HEADER_BASENAME}.h"
mv "$SWIFT_OUT_DIR/${HEADER_BASENAME}.modulemap" "$SWIFT_OUT_DIR/${HEADER_BASENAME}/module.modulemap"

cd ../openswap-swift/ || exit

rm -rf "./openswap_ffi.xcframework"

xcodebuild -create-xcframework \
    -library "${TARGETDIR}/${MAC_TARGET}/${PROFILE_DIR}/libopenswap_ffi.a" \
    -headers "${SWIFT_OUT_DIR}/${HEADER_BASENAME}" \
    -output "./openswap_ffi.xcframework"

# Keep Swift sources clean: only .swift files should stay in the package Sources dir
rm -rf "${SWIFT_OUT_DIR}/${HEADER_BASENAME}"
