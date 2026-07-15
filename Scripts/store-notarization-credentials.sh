#!/bin/zsh

set -euo pipefail

if (( $# != 3 )); then
    print -u2 "Usage: $0 <keychain-profile> <Apple-ID-email> <Team-ID>"
    exit 64
fi

PROFILE="$1"
APPLE_ID="$2"
TEAM_ID="$3"

print "notarytool will securely prompt for the app-specific password."
xcrun notarytool store-credentials "$PROFILE" \
    --apple-id "$APPLE_ID" \
    --team-id "$TEAM_ID"

print "Stored notarization credentials in the login keychain as profile '$PROFILE'."
