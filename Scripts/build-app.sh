#!/bin/zsh

set -euo pipefail

ROOT="${0:A:h:h}"
CONFIGURATION="${1:-release}"
APP_DIR="$ROOT/dist/KeyFlow.app"
CONTENTS="$APP_DIR/Contents"
IDENTITY="${CODE_SIGN_IDENTITY:-KeyFlow Local Development}"
KEYCHAIN_ARGS=()
CODESIGN_TIMESTAMP_ARGS=()

cd "$ROOT"
if [[ -n "${KEYFLOW_EXECUTABLE:-}" ]]; then
    EXECUTABLE="$KEYFLOW_EXECUTABLE"
    [[ -x "$EXECUTABLE" ]] || { print -u2 "KEYFLOW_EXECUTABLE is not executable: $EXECUTABLE"; exit 1; }
else
    swift build -c "$CONFIGURATION"
    BIN_DIR="$(swift build -c "$CONFIGURATION" --show-bin-path)"
    EXECUTABLE="$BIN_DIR/KeyFlowApp"
fi

rm -rf "$APP_DIR"
install -d "$CONTENTS/MacOS" "$CONTENTS/Resources"
install -m 755 "$EXECUTABLE" "$CONTENTS/MacOS/KeyFlowApp"
install -m 644 "$ROOT/Resources/Info.plist" "$CONTENTS/Info.plist"
install -m 644 "$ROOT/Resources/KeyFlow.icns" "$CONTENTS/Resources/KeyFlow.icns"
install -m 644 "$ROOT/Resources/PrivacyInfo.xcprivacy" "$CONTENTS/Resources/PrivacyInfo.xcprivacy"
install -m 644 "$ROOT/Resources/ReleasePolicy.plist" "$CONTENTS/Resources/ReleasePolicy.plist"
install -m 644 "$ROOT/Resources/ThirdPartyNotices.txt" "$CONTENTS/Resources/ThirdPartyNotices.txt"
install -m 644 "$ROOT/LICENSE" "$CONTENTS/Resources/License.txt"

if [[ -z "${CODE_SIGN_IDENTITY:-}" ]]; then
    LOCAL_KEYCHAIN="$($ROOT/Scripts/setup-local-signing.sh)"
    KEYCHAIN_ARGS=(--keychain "$LOCAL_KEYCHAIN")
fi

if [[ "${CODE_SIGN_TIMESTAMP:-0}" == "1" ]]; then
    CODESIGN_TIMESTAMP_ARGS=(--timestamp)
fi

codesign \
    --force \
    --sign "$IDENTITY" \
    "${KEYCHAIN_ARGS[@]}" \
    "${CODESIGN_TIMESTAMP_ARGS[@]}" \
    --options runtime \
    --entitlements "$ROOT/Resources/KeyFlow.entitlements" \
    "$APP_DIR"

codesign --verify --deep --strict --verbose=2 "$APP_DIR"
plutil -lint "$CONTENTS/Info.plist"
plutil -lint "$CONTENTS/Resources/PrivacyInfo.xcprivacy"
plutil -lint "$CONTENTS/Resources/ReleasePolicy.plist"

print "Built $APP_DIR"
