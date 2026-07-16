# Implementation Status

Updated: 2026-07-16
Current version: `0.1.7` (`8`)

## Completed vertical slice

| Area | Current implementation |
|---|---|
| App shell | Native SwiftUI/AppKit macOS app, configurable template-style menu-bar icon, and menu-bar controller |
| Keyboard capture | Quartz session event tap for global key-down chords |
| Keyboard behavior | Command/Option/Control/Shift/Fn matching and optional suppression |
| Trackpad | Runtime-loaded raw-contact bridge; pre-Swift filtering of ordinary pointer frames; 3/4/5-finger taps and clicks; continuous 4/5-finger volume sweeps; and a persistent four-finger switcher gesture with baseline-relative two-axis navigation |
| Actions | Keyboard shortcuts launch a selected app. Fixed gesture features provide Core Audio volume changes with a KeyFlow Sound Bar, mute/unmute, media play/pause, full/interactive screenshots that preserve the macOS target with an optional default/custom-folder PNG copy, and interactive window switching. Native screenshot file-copy waiting is event-driven rather than polled. Legacy URL/text action values remain decodable for recovery but are not offered by the editor and fail closed as keyboard mappings. |
| Window switcher | Five-column adaptive grid, app icons, 32 MB demand-driven thumbnail cache with serialized ScreenCaptureKit refresh, selected-first batched preview updates, hysteretic two-axis selection with a 0.25×–2.5× speed multiplier, system-shell filtering, standard-window or all-open-app discovery, exact AX window raising, and application activation fallback |
| Editor | Stable two-state keyboard shortcut split view with application-derived titles, an application-only inspector, aligned gesture feature surfaces with exclusive trigger ownership, and a live-preview-first Window Switcher editor |
| Runtime | Immutable compiled snapshots and off-callback action dispatch |
| Safety | Fail-open capture, pause switch, recorder pause, synthetic-event marker |
| Data | Schema-20 JSON, legacy migration, atomic writes, stale-revision protection, ten rolling backups, corrupt-primary recovery |
| Permissions | Accessibility/Input Monitoring controls plus optional Screen Recording for window thumbnails |
| Diagnostics | Bounded in-memory activity, unified logging, privacy-redacted export |
| Packaging | Universal builds, stable local signing, Developer ID/notarization/stapling/DMG automation, privacy manifest, machine-readable manual-beta policy, and ZIP/mounted-DMG qualification |
| Quality | Strict formatter, warnings-as-errors, bundle verification, checksum-pinned workflow/secret auditing, GitHub CI, and a protected release workflow |
| Tests | 107 core, app-model, and SwiftUI render tests covering Codable, migration, automatic shortcut naming, menu-bar icon availability, production/minimum window layouts, recovery, trigger conflicts, 3/4/5-finger lifecycles, tap/click separation, window selection, persistence, platform-service orchestration, cache lifetime, event-driven screenshot waiting, compatibility policy, and hot-path budgets; AddressSanitizer and ThreadSanitizer pass the full suite |

## Known limitations

- Only simple key-down chords are recognized; sequences, hold/tap, repeat, modifier-only, and Hyper Key are not implemented yet.
- Fixed 3/4/5-finger tap/click features and 4/5-finger volume adjustment use an isolated raw-contact compatibility provider. Arbitrary gesture-to-action mappings, zones, TipTap, and Magic Mouse touch are not implemented.
- Mappings are global. Application/window/device-specific contexts are not implemented yet.
- Each mapping runs one action. Action sequences, conditions, variables, cancellation, and concurrency policies are not implemented yet.
- Mouse buttons, scroll remapping, window management, scripts, clipboard history, import/export, and a backup browser remain roadmap work. Automatic updates are deliberately excluded from this machine-verified manual-beta release policy.
- The raw contact provider loads an undocumented Apple framework and is therefore experimental, direct-download only, and subject to the compatibility release gate.
- The local package uses a self-signed development identity. Public distribution requires the owner's Apple Developer identity, registered bundle ID, notarization credentials, and update-feed keys.
- Platform integrations that depend on TCC, physical trackpads, Core Audio, ScreenCaptureKit, sleep/wake, and exact-window activation still require the release-candidate hardware matrix; unit tests do not replace that gate.

## Verification completed

- Debug and release Swift builds succeed with Swift 6.3.3.
- All core and application-model tests pass.
- The locally signed packaged app passes strict code-signature, privacy-manifest, property-list, license-resource, ScreenCaptureKit-purpose-string, and bundle validation. It is not a public distribution artifact.
- Both arm64 and x86_64 release executables build and combine into a verified universal binary.
- AddressSanitizer, ThreadSanitizer, 51.97% overall line coverage, and 90.36% `KeyFlowCore` line coverage pass.
- A packaged-app isolated-home smoke launch and ZIP/mounted-DMG round trip pass.

## Next release target (`0.2.0`)

1. App-specific contexts and deterministic conflict reporting.
2. Keyboard sequence/tap/hold/double-tap state machines and stuck-key recovery.
3. Mouse button and scroll triggers.
4. Multiple sequential actions per mapping.
5. Export and backup/recovery browser UI.
