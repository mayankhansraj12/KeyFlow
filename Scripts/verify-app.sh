#!/bin/zsh

set -euo pipefail

APP_DIR="${1:-${0:A:h:h}/dist/KeyFlow.app}"
CONTENTS="$APP_DIR/Contents"

[[ -x "$CONTENTS/MacOS/KeyFlowApp" ]] || { print -u2 "Missing app executable"; exit 1; }
[[ -f "$CONTENTS/Resources/KeyFlow.icns" ]] || { print -u2 "Missing app icon"; exit 1; }
[[ -f "$CONTENTS/Resources/PrivacyInfo.xcprivacy" ]] || { print -u2 "Missing privacy manifest"; exit 1; }

plutil -lint "$CONTENTS/Info.plist"
plutil -lint "$CONTENTS/Resources/PrivacyInfo.xcprivacy"
codesign --verify --deep --strict --verbose=2 "$APP_DIR"

EXPECTED_IDENTIFIER="app.keyflow.desktop"
ACTUAL_IDENTIFIER="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$CONTENTS/Info.plist")"
[[ "$ACTUAL_IDENTIFIER" == "$EXPECTED_IDENTIFIER" ]] || {
    print -u2 "Unexpected bundle identifier: $ACTUAL_IDENTIFIER"
    exit 1
}

print "Verified $APP_DIR"
