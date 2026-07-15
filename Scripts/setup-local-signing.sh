#!/bin/zsh

set -euo pipefail

ROOT="${0:A:h:h}"
SIGNING_DIR="$ROOT/.local-signing"
KEYCHAIN="$SIGNING_DIR/KeyFlowDevelopment.keychain-db"
PASSWORD_FILE="$SIGNING_DIR/keychain-password"
IDENTITY_NAME="KeyFlow Local Development"
CERTIFICATE="$SIGNING_DIR/certificate.pem"
PRIVATE_KEY="$SIGNING_DIR/private-key.pem"
LEGACY_PASSWORD="keyflow-local-development"

install -d -m 700 "$SIGNING_DIR"
umask 077

if [[ -f "$PASSWORD_FILE" ]]; then
    PASSWORD="$(<"$PASSWORD_FILE")"
elif [[ -f "$KEYCHAIN" ]] && security unlock-keychain -p "$LEGACY_PASSWORD" "$KEYCHAIN" 2>/dev/null; then
    PASSWORD="$(openssl rand -hex 32)"
    security set-keychain-password -o "$LEGACY_PASSWORD" -p "$PASSWORD" "$KEYCHAIN"
    print -rn -- "$PASSWORD" > "$PASSWORD_FILE"
else
    PASSWORD="$(openssl rand -hex 32)"
    print -rn -- "$PASSWORD" > "$PASSWORD_FILE"
fi

function ensure_keychain_is_searchable() {
    typeset -a keychains
    keychains=("${(@f)$(security list-keychains -d user | sed -E 's/^[[:space:]]*"//; s/"$//')}")
    if (( ${keychains[(Ie)$KEYCHAIN]} == 0 )); then
        security list-keychains -d user -s "${keychains[@]}" "$KEYCHAIN"
    fi
}

if [[ -f "$KEYCHAIN" ]] && security find-identity -v -p codesigning "$KEYCHAIN" 2>/dev/null | grep -q "$IDENTITY_NAME"; then
    security unlock-keychain -p "$PASSWORD" "$KEYCHAIN"
    ensure_keychain_is_searchable
    print "$KEYCHAIN"
    exit 0
fi

rm -f "$KEYCHAIN" "$CERTIFICATE" "$PRIVATE_KEY"

openssl req \
    -new \
    -newkey rsa:2048 \
    -nodes \
    -x509 \
    -days 3650 \
    -config "$ROOT/Config/LocalCodeSigning.cnf" \
    -keyout "$PRIVATE_KEY" \
    -out "$CERTIFICATE"

openssl rsa \
    -in "$PRIVATE_KEY" \
    -out "$PRIVATE_KEY.rsa"
mv "$PRIVATE_KEY.rsa" "$PRIVATE_KEY"

security create-keychain -p "$PASSWORD" "$KEYCHAIN"
security set-keychain-settings -lut 21600 "$KEYCHAIN"
security unlock-keychain -p "$PASSWORD" "$KEYCHAIN"
security import "$PRIVATE_KEY" \
    -k "$KEYCHAIN" \
    -f openssl \
    -T /usr/bin/codesign \
    -T /usr/bin/security >/dev/null
security import "$CERTIFICATE" \
    -k "$KEYCHAIN" \
    -t cert \
    -f pemseq >/dev/null
security add-trusted-cert \
    -r trustRoot \
    -p codeSign \
    -k "$KEYCHAIN" \
    "$CERTIFICATE"
security set-key-partition-list \
    -S apple-tool:,apple: \
    -s \
    -k "$PASSWORD" \
    "$KEYCHAIN" >/dev/null

rm -f "$PRIVATE_KEY"
chmod 600 "$KEYCHAIN" "$CERTIFICATE" "$PASSWORD_FILE"
ensure_keychain_is_searchable

print "$KEYCHAIN"
