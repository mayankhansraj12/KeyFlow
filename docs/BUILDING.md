# Building and releasing KeyFlow

## Requirements

- macOS 15 or later
- Xcode 26 or a compatible Swift 6.2+ toolchain
- Command Line Tools selected through `xcode-select`

## Validate the repository

```sh
./Scripts/validate.sh
```

This runs formatting checks, tests, and warnings-as-errors builds.

## Build the application

```sh
./Scripts/build-app.sh
open dist/KeyFlow.app
```

When `CODE_SIGN_IDENTITY` is not supplied, the script creates an isolated,
stable, self-signed local identity under the ignored `.local-signing`
directory. A stable identity prevents unnecessary Accessibility and Input
Monitoring resets between local rebuilds.

Use another installed identity when required:

```sh
CODE_SIGN_IDENTITY="Apple Development: Example (TEAMID)" \
  ./Scripts/build-app.sh
```

## Build the universal DMG

```sh
./Scripts/build-local-dmg.sh
open release/KeyFlow-0.1.7-8.dmg
```

The pipeline:

1. builds arm64 and x86_64 release executables;
2. combines them into a universal binary;
3. assembles and locally signs `KeyFlow.app`;
4. renders a non-alpha, 144-DPI Retina installer background;
5. writes deterministic Finder metadata for the background and icon positions;
6. creates a compressed drag-to-Applications DMG;
7. remounts and verifies the app, architecture, layout, and artwork metadata.

On its first run, the DMG script installs the hash-pinned packages listed in
`Scripts/dmg-requirements.txt` into `.build/dmg-python`. These packages are
build-time tools and are not shipped inside KeyFlow.

An optional first argument selects another output path:

```sh
./Scripts/build-local-dmg.sh release/KeyFlow-preview.dmg
```

## Credentialed release pipeline

Official public binaries should use a Developer ID Application certificate,
Hardened Runtime, notarization, and stapling:

```sh
./Scripts/store-notarization-credentials.sh \
  "KeyFlow Notarization" "APPLE_ID_EMAIL" "TEAM_ID"

DEVELOPER_ID_APPLICATION="Developer ID Application: Example Developer (TEAM_ID)" \
DEVELOPER_TEAM_ID="TEAM_ID" \
NOTARY_PROFILE="KeyFlow Notarization" \
  ./Scripts/release.sh
```

Credentials belong in the macOS keychain or protected CI secrets. Never commit
certificates, private keys, app-specific passwords, API keys, notarization
responses containing sensitive context, or generated signing keychains.

Before publishing, complete the [release checklist](RELEASE_CHECKLIST.md).
