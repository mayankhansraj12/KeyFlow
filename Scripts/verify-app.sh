#!/bin/zsh

set -euo pipefail

APP_DIR="${1:-${0:A:h:h}/dist/KeyFlow.app}"
CONTENTS="$APP_DIR/Contents"

[[ -x "$CONTENTS/MacOS/KeyFlowApp" ]] || { print -u2 "Missing app executable"; exit 1; }
[[ -f "$CONTENTS/Resources/KeyFlow.icns" ]] || { print -u2 "Missing app icon"; exit 1; }
[[ -f "$CONTENTS/Resources/PrivacyInfo.xcprivacy" ]] || { print -u2 "Missing privacy manifest"; exit 1; }
[[ -f "$CONTENTS/Resources/ReleasePolicy.plist" ]] || { print -u2 "Missing release policy"; exit 1; }
[[ -f "$CONTENTS/Resources/License.txt" ]] || { print -u2 "Missing product license"; exit 1; }

plutil -lint "$CONTENTS/Info.plist"
plutil -lint "$CONTENTS/Resources/PrivacyInfo.xcprivacy"
plutil -lint "$CONTENTS/Resources/ReleasePolicy.plist"
codesign --verify --deep --strict --verbose=2 "$APP_DIR"

EXPECTED_IDENTIFIER="app.keyflow.desktop"
ACTUAL_IDENTIFIER="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$CONTENTS/Info.plist")"
[[ "$ACTUAL_IDENTIFIER" == "$EXPECTED_IDENTIFIER" ]] || {
    print -u2 "Unexpected bundle identifier: $ACTUAL_IDENTIFIER"
    exit 1
}

SCREEN_CAPTURE_DESCRIPTION="$(/usr/libexec/PlistBuddy -c 'Print :NSScreenCaptureUsageDescription' "$CONTENTS/Info.plist")"
[[ -n "$SCREEN_CAPTURE_DESCRIPTION" ]] || {
    print -u2 "NSScreenCaptureUsageDescription must not be empty"
    exit 1
}

PRIVACY_POLICY_URL="$(/usr/libexec/PlistBuddy -c 'Print :KeyFlowPrivacyPolicyURL' "$CONTENTS/Info.plist")"
SUPPORT_URL="$(/usr/libexec/PlistBuddy -c 'Print :KeyFlowSupportURL' "$CONTENTS/Info.plist")"
[[ "$PRIVACY_POLICY_URL" == https://* && "$SUPPORT_URL" == https://* ]] || {
    print -u2 "Privacy and support links must use HTTPS"
    exit 1
}

RELEASE_CHANNEL="$(/usr/libexec/PlistBuddy -c 'Print :ReleaseChannel' "$CONTENTS/Resources/ReleasePolicy.plist")"
AUTOMATIC_UPDATES="$(/usr/libexec/PlistBuddy -c 'Print :AutomaticUpdatesEnabled' "$CONTENTS/Resources/ReleasePolicy.plist")"
[[ "$RELEASE_CHANNEL" == "manual-beta" && "$AUTOMATIC_UPDATES" == "false" ]] || {
    print -u2 "Unsupported release/update policy: $RELEASE_CHANNEL automatic=$AUTOMATIC_UPDATES"
    exit 1
}

print "Verified $APP_DIR"
