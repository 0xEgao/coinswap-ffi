#!/bin/bash

set -e

COMPILATION_TARGET="x86_64-unknown-linux-gnu"
RESOURCE_DIR="linux-x86_64"
LIB_NAME="libopenswap_ffi.so"

echo "Building for target: $COMPILATION_TARGET"

# Move to ffi-commons directory
cd ../ffi-commons || exit
rustup target add $COMPILATION_TARGET

# Build the library
cargo build --target $COMPILATION_TARGET

# Copy the binary to the Python native directory
mkdir -p ../openswap-python/src/openswap/native/$RESOURCE_DIR/
cp ./target/$COMPILATION_TARGET/debug/$LIB_NAME ../openswap-python/src/openswap/native/$RESOURCE_DIR/
cp ./target/$COMPILATION_TARGET/debug/uniffi-bindgen ../openswap-python/src/openswap/native/$RESOURCE_DIR/

cargo run --bin uniffi-bindgen generate --library ./target/$COMPILATION_TARGET/debug/$LIB_NAME --language python --out-dir ../openswap-python/src/openswap/native/$RESOURCE_DIR/ --no-format
echo "  Bindings: openswap-python/src/openswap/openswap.py"
echo "✓ Build completed for $COMPILATION_TARGET"
echo "  Binary: openswap-python/src/openswap/native/$RESOURCE_DIR/$LIB_NAME"
