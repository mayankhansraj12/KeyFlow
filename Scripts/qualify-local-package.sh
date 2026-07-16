#!/bin/zsh

set -euo pipefail

ROOT="${0:A:h:h}"
APP_DIR="${1:-$ROOT/dist/KeyFlow.app}"
WORK_DIR="$(mktemp -d)"
ARCHIVE="$WORK_DIR/KeyFlow.zip"
DMG="$WORK_DIR/KeyFlow.dmg"
MOUNT_POINT="$WORK_DIR/mount"
MOUNTED=0

function cleanup() {
    if (( MOUNTED )); then
        hdiutil detach "$MOUNT_POINT" -quiet || true
    fi
    rm -rf "$WORK_DIR"
}
trap cleanup EXIT INT TERM

"$ROOT/Scripts/verify-app.sh" "$APP_DIR"
lipo "$APP_DIR/Contents/MacOS/KeyFlowApp" -verify_arch arm64 x86_64

mkdir -p "$WORK_DIR/archive" "$WORK_DIR/staging" "$MOUNT_POINT"
ditto -c -k --keepParent "$APP_DIR" "$ARCHIVE"
ditto -x -k "$ARCHIVE" "$WORK_DIR/archive"
"$ROOT/Scripts/verify-app.sh" "$WORK_DIR/archive/KeyFlow.app"

ditto "$APP_DIR" "$WORK_DIR/staging/KeyFlow.app"
ln -s /Applications "$WORK_DIR/staging/Applications"
hdiutil create -volname "KeyFlow Local Qualification" -srcfolder "$WORK_DIR/staging" -format UDZO -ov "$DMG" -quiet
hdiutil attach "$DMG" -readonly -nobrowse -mountpoint "$MOUNT_POINT" -quiet
MOUNTED=1
"$ROOT/Scripts/verify-app.sh" "$MOUNT_POINT/KeyFlow.app"

ARCHIVE_HASH="$(shasum -a 256 "$ARCHIVE" | awk '{print $1}')"
DMG_HASH="$(shasum -a 256 "$DMG" | awk '{print $1}')"
print "Local ZIP/DMG round trip passed"
print "Temporary ZIP SHA-256: $ARCHIVE_HASH"
print "Temporary DMG SHA-256: $DMG_HASH"
