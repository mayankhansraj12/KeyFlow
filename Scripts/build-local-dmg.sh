#!/bin/zsh

set -euo pipefail

ROOT="${0:A:h:h}"
INFO_PLIST="$ROOT/Resources/Info.plist"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$INFO_PLIST")"
BUILD="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$INFO_PLIST")"
OUTPUT="${1:-$ROOT/release/KeyFlow-$VERSION-$BUILD.dmg}"
VOLUME_NAME="KeyFlow Installer"
WORK_DIR="$(mktemp -d)"
STAGING="$WORK_DIR/staging"
MOUNT_POINT=""
READ_WRITE_DMG="$WORK_DIR/KeyFlow-rw.dmg"
UNIVERSAL_BINARY="$WORK_DIR/KeyFlowApp-universal"
BACKGROUND="$WORK_DIR/DMGBackground.png"
ATTACH_PLIST="$WORK_DIR/attach.plist"
DMG_PYTHON_PACKAGES="$ROOT/.build/dmg-python"
MOUNTED=0

function cleanup() {
    if (( MOUNTED )) && [[ -n "$MOUNT_POINT" ]]; then
        hdiutil detach "$MOUNT_POINT" -quiet || true
    fi
    rm -rf "$WORK_DIR"
}
trap cleanup EXIT INT TERM

cd "$ROOT"
mkdir -p "${OUTPUT:h}" "$STAGING"

"$ROOT/Scripts/build-universal.sh" release "$UNIVERSAL_BINARY"
KEYFLOW_EXECUTABLE="$UNIVERSAL_BINARY" "$ROOT/Scripts/build-app.sh" release
"$ROOT/Scripts/verify-app.sh" "$ROOT/dist/KeyFlow.app"

ditto "$ROOT/dist/KeyFlow.app" "$STAGING/KeyFlow.app"
swift "$ROOT/Scripts/render-dmg-background.swift" "$BACKGROUND"

if ! PYTHONPATH="$DMG_PYTHON_PACKAGES" python3 -c 'import ds_store, mac_alias' 2>/dev/null; then
    rm -rf "$DMG_PYTHON_PACKAGES"
    mkdir -p "$DMG_PYTHON_PACKAGES"
    python3 -m pip install \
        --disable-pip-version-check \
        --no-deps \
        --require-hashes \
        --target "$DMG_PYTHON_PACKAGES" \
        -r "$ROOT/Scripts/dmg-requirements.txt"
fi

hdiutil create \
    -volname "$VOLUME_NAME" \
    -srcfolder "$STAGING" \
    -fs HFS+ \
    -format UDRW \
    -ov \
    "$READ_WRITE_DMG" \
    -quiet

hdiutil attach \
    "$READ_WRITE_DMG" \
    -readwrite \
    -noverify \
    -noautoopen \
    -plist > "$ATTACH_PLIST"
MOUNT_POINT="$(
    plutil -convert json -o - "$ATTACH_PLIST" \
        | jq -r '."system-entities"[] | select(."mount-point" != null) | ."mount-point"' \
        | head -1
)"
[[ -d "$MOUNT_POINT" ]] || { print -u2 "Could not locate the mounted writable DMG."; exit 1; }
MOUNTED=1

mkdir -p "$MOUNT_POINT/.background"
cp "$BACKGROUND" "$MOUNT_POINT/.background/DMGBackground.png"
ln -s /Applications "$MOUNT_POINT/Applications"
cp "$ROOT/Resources/KeyFlow.icns" "$MOUNT_POINT/.VolumeIcon.icns"
SetFile -c icnC "$MOUNT_POINT/.VolumeIcon.icns" 2>/dev/null || true

PYTHONPATH="$DMG_PYTHON_PACKAGES" \
    python3 "$ROOT/Scripts/write-dmg-metadata.py" "$MOUNT_POINT"

[[ -f "$MOUNT_POINT/.DS_Store" ]] || {
    print -u2 "Could not create the DMG Finder layout."
    exit 1
}

SetFile -a V "$MOUNT_POINT/.background" 2>/dev/null || true
SetFile -a V "$MOUNT_POINT/.VolumeIcon.icns" 2>/dev/null || true
SetFile -a C "$MOUNT_POINT" 2>/dev/null || true
bless --folder "$MOUNT_POINT" || true
rm -rf "$MOUNT_POINT/.fseventsd"

sync
hdiutil detach "$MOUNT_POINT" -quiet
MOUNTED=0
MOUNT_POINT=""

rm -f "$OUTPUT"
hdiutil convert \
    "$READ_WRITE_DMG" \
    -format UDZO \
    -imagekey zlib-level=9 \
    -ov \
    -o "$OUTPUT" \
    -quiet

CHECK_MOUNT="$WORK_DIR/check"
mkdir -p "$CHECK_MOUNT"
hdiutil attach "$OUTPUT" -readonly -nobrowse -mountpoint "$CHECK_MOUNT" -quiet
MOUNT_POINT="$CHECK_MOUNT"
MOUNTED=1

[[ -d "$CHECK_MOUNT/KeyFlow.app" ]] || { print -u2 "DMG is missing KeyFlow.app"; exit 1; }
[[ -L "$CHECK_MOUNT/Applications" ]] || { print -u2 "DMG is missing Applications shortcut"; exit 1; }
[[ -f "$CHECK_MOUNT/.DS_Store" ]] || { print -u2 "DMG is missing its Finder layout"; exit 1; }
PYTHONPATH="$DMG_PYTHON_PACKAGES" \
    python3 "$ROOT/Scripts/write-dmg-metadata.py" --verify "$CHECK_MOUNT"

BACKGROUND_INFO="$(
    sips \
        -g dpiWidth \
        -g dpiHeight \
        -g pixelWidth \
        -g pixelHeight \
        -g hasAlpha \
        "$CHECK_MOUNT/.background/DMGBackground.png"
)"
[[ "$BACKGROUND_INFO" == *"dpiWidth: 144.000"* ]] || {
    print -u2 "DMG background is not 144 DPI."
    exit 1
}
[[ "$BACKGROUND_INFO" == *"pixelWidth: 1520"* && "$BACKGROUND_INFO" == *"pixelHeight: 876"* ]] || {
    print -u2 "DMG background has unexpected dimensions."
    exit 1
}
[[ "$BACKGROUND_INFO" == *"hasAlpha: no"* ]] || {
    print -u2 "DMG background must not contain an alpha channel."
    exit 1
}

"$ROOT/Scripts/verify-app.sh" "$CHECK_MOUNT/KeyFlow.app"
lipo "$CHECK_MOUNT/KeyFlow.app/Contents/MacOS/KeyFlowApp" -verify_arch arm64 x86_64

hdiutil detach "$CHECK_MOUNT" -quiet
MOUNTED=0

HASH="$(shasum -a 256 "$OUTPUT" | awk '{print $1}')"
print "Built polished local DMG: $OUTPUT"
print "SHA-256: $HASH"
print "This free local build is not Apple-notarized and may trigger Gatekeeper warnings on other Macs."
