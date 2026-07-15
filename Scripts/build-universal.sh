#!/bin/zsh

set -euo pipefail

ROOT="${0:A:h:h}"
CONFIGURATION="${1:-release}"
OUTPUT="${2:-$ROOT/release/KeyFlowApp-universal}"
BUILD_ROOT="$ROOT/.build/universal"
TRIPLES=(arm64-apple-macosx15.0 x86_64-apple-macosx15.0)
BINARIES=()

cd "$ROOT"
mkdir -p "${OUTPUT:h}"

for triple in "${TRIPLES[@]}"; do
    architecture="${triple%%-*}"
    scratch="$BUILD_ROOT/$architecture"
    swift build --scratch-path "$scratch" --triple "$triple" -c "$CONFIGURATION"
    binary_dir="$(swift build --scratch-path "$scratch" --triple "$triple" -c "$CONFIGURATION" --show-bin-path)"
    BINARIES+=("$binary_dir/KeyFlowApp")
done

lipo -create "${BINARIES[@]}" -output "$OUTPUT"
chmod 755 "$OUTPUT"
lipo "$OUTPUT" -verify_arch arm64 x86_64
print "Built universal executable $OUTPUT ($(lipo -archs "$OUTPUT"))"
