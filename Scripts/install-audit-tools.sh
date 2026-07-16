#!/bin/zsh

set -euo pipefail

DESTINATION="${1:-}"
[[ -n "$DESTINATION" ]] || {
    print -u2 "Usage: $0 <destination-directory>"
    exit 64
}

ACTIONLINT_VERSION="1.7.12"
GITLEAKS_VERSION="8.30.1"

case "$(uname -m)" in
arm64)
    ACTIONLINT_ARCH="arm64"
    ACTIONLINT_SHA256="aba9ced2dee8d27fecca3dc7feb1a7f9a52caefa1eb46f3271ea66b6e0e6953f"
    GITLEAKS_ARCH="arm64"
    GITLEAKS_SHA256="b40ab0ae55c505963e365f271a8d3846efbc170aa17f2607f13df610a9aeb6a5"
    ;;
x86_64)
    ACTIONLINT_ARCH="amd64"
    ACTIONLINT_SHA256="5b44c3bc2255115c9b69e30efc0fecdf498fdb63c5d58e17084fd5f16324c644"
    GITLEAKS_ARCH="x64"
    GITLEAKS_SHA256="dfe101a4db2255fc85120ac7f3d25e4342c3c20cf749f2c20a18081af1952709"
    ;;
*)
    print -u2 "Unsupported audit-tool architecture: $(uname -m)"
    exit 1
    ;;
esac

STAGING="$(mktemp -d)"
function cleanup() {
    rm -rf "$STAGING"
}
trap cleanup EXIT

function download() {
    local url="$1"
    local checksum="$2"
    local output="$3"
    curl --fail --location --silent --show-error "$url" --output "$output"
    print "$checksum  $output" | shasum -a 256 --check --status
}

mkdir -p "$DESTINATION"

ACTIONLINT_ARCHIVE="$STAGING/actionlint.tar.gz"
download \
    "https://github.com/rhysd/actionlint/releases/download/v$ACTIONLINT_VERSION/actionlint_${ACTIONLINT_VERSION}_darwin_${ACTIONLINT_ARCH}.tar.gz" \
    "$ACTIONLINT_SHA256" \
    "$ACTIONLINT_ARCHIVE"
tar -xzf "$ACTIONLINT_ARCHIVE" -C "$STAGING"
install -m 0755 "$STAGING/actionlint" "$DESTINATION/actionlint"

GITLEAKS_ARCHIVE="$STAGING/gitleaks.tar.gz"
download \
    "https://github.com/gitleaks/gitleaks/releases/download/v$GITLEAKS_VERSION/gitleaks_${GITLEAKS_VERSION}_darwin_${GITLEAKS_ARCH}.tar.gz" \
    "$GITLEAKS_SHA256" \
    "$GITLEAKS_ARCHIVE"
tar -xzf "$GITLEAKS_ARCHIVE" -C "$STAGING"
install -m 0755 "$STAGING/gitleaks" "$DESTINATION/gitleaks"

"$DESTINATION/actionlint" -version
"$DESTINATION/gitleaks" version
