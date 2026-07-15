#!/bin/zsh

set -euo pipefail

ROOT="${0:A:h:h}"
RELEASE_DIR="$ROOT/release"
APP_DIR="$ROOT/dist/KeyFlow.app"
INFO_PLIST="$ROOT/Resources/Info.plist"
IDENTITY="${DEVELOPER_ID_APPLICATION:-}"
NOTARY_PROFILE="${NOTARY_PROFILE:-}"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$INFO_PLIST")"
BUILD="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$INFO_PLIST")"
ARCHIVE="$RELEASE_DIR/KeyFlow-$VERSION-$BUILD.zip"
DMG="$RELEASE_DIR/KeyFlow-$VERSION-$BUILD.dmg"
UNIVERSAL_BINARY="$RELEASE_DIR/KeyFlowApp-universal"
STAGING="$(mktemp -d)"

function cleanup() {
    rm -rf "$STAGING"
}
trap cleanup EXIT

[[ "$IDENTITY" == Developer\ ID\ Application:* ]] || {
    print -u2 "Set DEVELOPER_ID_APPLICATION to the full 'Developer ID Application: …' identity."
    exit 64
}
[[ -n "$NOTARY_PROFILE" ]] || {
    print -u2 "Set NOTARY_PROFILE to a notarytool keychain profile."
    exit 64
}
security find-identity -v -p codesigning | grep -Fq "$IDENTITY" || {
    print -u2 "Developer ID identity was not found in the active keychains: $IDENTITY"
    exit 1
}

rm -rf "$RELEASE_DIR"
mkdir -p "$RELEASE_DIR"

"$ROOT/Scripts/validate.sh"
"$ROOT/Scripts/build-universal.sh" release "$UNIVERSAL_BINARY"

KEYFLOW_EXECUTABLE="$UNIVERSAL_BINARY" \
CODE_SIGN_IDENTITY="$IDENTITY" \
CODE_SIGN_TIMESTAMP=1 \
    "$ROOT/Scripts/build-app.sh" release

"$ROOT/Scripts/verify-app.sh" "$APP_DIR"
codesign --verify --deep --strict --verbose=2 "$APP_DIR"
codesign -d --verbose=4 "$APP_DIR" 2>&1 | grep -q "Runtime Version"

ditto -c -k --keepParent "$APP_DIR" "$ARCHIVE"
xcrun notarytool submit "$ARCHIVE" --keychain-profile "$NOTARY_PROFILE" --wait
xcrun stapler staple "$APP_DIR"
xcrun stapler validate "$APP_DIR"
spctl --assess --type execute --verbose=2 "$APP_DIR"
rm -f "$ARCHIVE"
ditto -c -k --keepParent "$APP_DIR" "$ARCHIVE"

mkdir -p "$STAGING/KeyFlow"
ditto "$APP_DIR" "$STAGING/KeyFlow/KeyFlow.app"
ln -s /Applications "$STAGING/KeyFlow/Applications"
hdiutil create \
    -volname "KeyFlow" \
    -srcfolder "$STAGING/KeyFlow" \
    -format UDZO \
    -ov \
    "$DMG"
codesign --force --sign "$IDENTITY" --timestamp "$DMG"

xcrun notarytool submit "$DMG" --keychain-profile "$NOTARY_PROFILE" --wait
xcrun stapler staple "$DMG"
xcrun stapler validate "$DMG"
spctl --assess --type open --context context:primary-signature --verbose=2 "$DMG"

shasum -a 256 "$ARCHIVE" "$DMG" > "$RELEASE_DIR/SHA256SUMS"
print "Release complete: $DMG"
