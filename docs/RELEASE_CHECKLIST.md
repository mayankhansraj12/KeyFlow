# Release checklist

## One-time setup

- Register `app.keyflow.desktop` in the Apple Developer account or replace it consistently before the first public release.
- Install a valid Developer ID Application certificate.
- Store notarization credentials with `Scripts/store-notarization-credentials.sh`, or configure the protected `production` GitHub environment and documented release secrets.
- Enable required reviewers for the GitHub `production` environment.
- Complete the physical-device matrix in `MULTITOUCH_COMPATIBILITY.md`.

## Source gate

- Working tree reviewed; no `.local-signing`, `.env`, `.p8`, `.p12`, or credentials tracked.
- Version/build numbers updated and unique.
- When publishing through GitHub, create and push the reviewed `v<CFBundleShortVersionString>` tag first; the release workflow refuses to publish an unverified tag.
- `Scripts/validate.sh` passes.
- CI passes on the exact release commit.
- Privacy documentation and manifest match current behavior.
- `NSScreenCaptureUsageDescription`, product license, and third-party notices are present in the packaged app.
- Schema migration and backup recovery tests pass.
- AddressSanitizer and ThreadSanitizer test runs pass on the release commit.

## Build and distribution gate

```sh
DEVELOPER_ID_APPLICATION="Developer ID Application: Your Name (TEAMID)" \
NOTARY_PROFILE="KeyFlow Notarization" \
./Scripts/release.sh
```

The script must complete all of these automatically:

- Build arm64 and x86_64 executables and verify the universal result.
- Sign the app with Hardened Runtime and a secure timestamp.
- Verify the app signature and bundle resources.
- Notarize the app archive, staple the app, and pass Gatekeeper assessment.
- Create and sign the DMG.
- Notarize and staple the DMG and pass Gatekeeper assessment.
- Produce SHA-256 checksums.

## Manual release-candidate checks

- Install from the DMG on a clean standard user account.
- Verify first-run permissions, permission refresh, and launch at login.
- Create, edit, disable, delete, and test mappings.
- Verify 3/4/5-finger taps and physical clicks, plus incremental 4/5-finger volume sweeps, on matrix hardware.
- Verify Play/Pause, full-screen screenshot, and custom selection screenshot triggers without tap/click double firing.
- Verify screenshot storage reports and preserves the current macOS target; when enabled, the additional-copy toggle saves timestamped full/selection PNG files to the default or custom folder.
- Verify the horizontal switcher in both directions, selection wraparound, cancellation, exact-window activation, and icon-only behavior without Screen Recording.
- Verify continuous volume response and the KeyFlow Sound Bar at 0%, one-digit, two-digit, and 100% values for every percentage-alignment option.
- Corrupt a copy of the configuration and confirm backup recovery.
- Export diagnostics and verify that no mapping names, typed text, or action values appear.
- Upgrade from the prior public build without losing TCC permissions or configuration.
- Run for at least one sleep/wake cycle and inspect crashes and unified logs.

## External gates not satisfied by source code

- Apple Developer membership, registered bundle identifier, certificate, and notarization service availability.
- Physical Intel/Apple-silicon and trackpad hardware coverage.
- Hosting, privacy-policy URL, support channel, and release notes.
- An automatic-update signing key and feed; updates are not implemented yet.
