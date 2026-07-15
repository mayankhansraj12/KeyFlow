#!/bin/zsh

set -euo pipefail

ROOT="${0:A:h:h}"
INFO_PLIST="$ROOT/Resources/Info.plist"
PRIVACY_MANIFEST="$ROOT/Resources/PrivacyInfo.xcprivacy"

function fail() {
    print -u2 "Production audit failed: $1"
    exit 1
}

for required in \
    "$INFO_PLIST" \
    "$PRIVACY_MANIFEST" \
    "$ROOT/Resources/KeyFlow.entitlements" \
    "$ROOT/Resources/ThirdPartyNotices.txt" \
    "$ROOT/LICENSE"; do
    [[ -s "$required" ]] || fail "missing or empty ${required#$ROOT/}"
done

plutil -lint "$INFO_PLIST" "$PRIVACY_MANIFEST" "$ROOT/Resources/KeyFlow.entitlements" >/dev/null

IDENTIFIER="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$INFO_PLIST")"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$INFO_PLIST")"
BUILD="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$INFO_PLIST")"
MINIMUM_OS="$(/usr/libexec/PlistBuddy -c 'Print :LSMinimumSystemVersion' "$INFO_PLIST")"
CATEGORY="$(/usr/libexec/PlistBuddy -c 'Print :LSApplicationCategoryType' "$INFO_PLIST")"
SCREEN_CAPTURE_DESCRIPTION="$(/usr/libexec/PlistBuddy -c 'Print :NSScreenCaptureUsageDescription' "$INFO_PLIST")"

[[ "$IDENTIFIER" == "app.keyflow.desktop" ]] || fail "unexpected bundle identifier: $IDENTIFIER"
[[ "$VERSION" =~ '^[0-9]+\.[0-9]+\.[0-9]+([-.][0-9A-Za-z.-]+)?$' ]] || fail "invalid semantic version: $VERSION"
[[ "$BUILD" =~ '^[1-9][0-9]*$' ]] || fail "build number must be a positive integer: $BUILD"
[[ "$MINIMUM_OS" == "15.0" ]] || fail "deployment target and Info.plist disagree: $MINIMUM_OS"
[[ "$CATEGORY" == "public.app-category.utilities" ]] || fail "unexpected application category: $CATEGORY"
[[ -n "$SCREEN_CAPTURE_DESCRIPTION" ]] || fail "NSScreenCaptureUsageDescription is empty"

TRACKING="$(/usr/libexec/PlistBuddy -c 'Print :NSPrivacyTracking' "$PRIVACY_MANIFEST")"
[[ "$TRACKING" == "false" ]] || fail "privacy manifest unexpectedly enables tracking"
/usr/libexec/PlistBuddy -c 'Print :NSPrivacyTrackingDomains' "$PRIVACY_MANIFEST" >/dev/null
/usr/libexec/PlistBuddy -c 'Print :NSPrivacyCollectedDataTypes' "$PRIVACY_MANIFEST" >/dev/null
/usr/libexec/PlistBuddy -c 'Print :NSPrivacyAccessedAPITypes' "$PRIVACY_MANIFEST" >/dev/null

if rg -n '^import (AppKit|SwiftUI|ApplicationServices|CoreGraphics|ScreenCaptureKit|ServiceManagement)$' \
    "$ROOT/Sources/KeyFlowCore"; then
    fail "KeyFlowCore imports a platform framework"
fi

SCHEMA="$(sed -nE 's/.*currentSchemaVersion = ([0-9]+).*/\1/p' "$ROOT/Sources/KeyFlowCore/Models.swift")"
[[ -n "$SCHEMA" ]] || fail "could not determine current configuration schema"
rg -q "Schema-${SCHEMA} JSON" "$ROOT/docs/IMPLEMENTATION_STATUS.md" \
    || fail "implementation status does not document schema $SCHEMA"

if git -C "$ROOT" ls-files | rg -q '(^|/)(\.DS_Store|\.env|\.local-signing)(/|$)|\.(cer|key|p8|p12)$'; then
    fail "sensitive or generated material is tracked"
fi

git -C "$ROOT" diff --check
print "Production metadata audit passed (KeyFlow $VERSION build $BUILD, schema $SCHEMA)"
