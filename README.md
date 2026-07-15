# KeyFlow

KeyFlow is a native macOS keyboard-shortcut and trackpad-gesture manager. The current `0.1.7` build is a production-oriented foundation for the first working vertical slice from the [product and engineering plan](docs/PRODUCT_PLAN.md). See [implementation status](docs/IMPLEMENTATION_STATUS.md) for the exact completion matrix and limitations.

## What works now

- Global keyboard chords with Command, Option, Control, Shift, and Fn modifiers.
- Optional suppression of the original keyboard shortcut.
- Fixed, toggleable trackpad features for 4/5-finger volume sweeps plus 3/4/5-finger mute, media play/pause, full-screen screenshots, and interactive selection screenshots. Tap and physical-click triggers are distinct and exclusive.
- An independently enabled four-finger window switcher with a five-column adaptive grid. A horizontal swipe launches it; baseline-relative two-axis movement then navigates rows, columns, and diagonals before release raises the selected window. A continuous 0.25×–2.5× speed multiplier controls travel sensitivity and animation response. Standard Apps shows normal Dock-app windows; All Open Apps also includes KeyFlow, running Dock apps without a resolvable window, and third-party accessory/menu-bar/background apps only while they expose a visible window. macOS shell surfaces such as Dock, Control Center, and volume HUD are excluded. Optional Screen Recording permission adds a bounded, demand-driven thumbnail cache. Capture runs only while the switcher is in use, publishes the selected preview first, and is serialized to prevent background CPU spikes.
- Keyboard shortcuts open a user-selected application. Fixed gesture features provide continuous volume adjustment, mute/unmute, media play/pause, native full-screen and selection screenshots, and interactive window switching. Screenshots preserve the live macOS destination, with an optional additional PNG copy in the default or KeyFlow-selected custom folder. Continuous volume changes use Core Audio and KeyFlow's reusable, customizable Sound Bar.
- A native keyboard mapping editor plus fixed gesture feature menus with conflict-safe trigger selection.
- Migratable JSON persistence in `~/Library/Application Support/KeyFlow/configuration.json`, with rolling backups and automatic corruption recovery.
- Menu-bar pause/resume control.
- Accessibility and Input Monitoring permission status/actions.
- In-memory live activity, unified error logging, and privacy-redacted diagnostics export.
- Event tagging to prevent synthesized text from recursively triggering mappings.
- Atomic configuration writes, immutable runtime snapshots, and stale-save protection.
- Low-overhead input gating discards ordinary one/two-finger pointer frames before they cross into Swift.
- Stable, locally signed `.app` packaging for development.

This is not yet the complete BetterTouchTool-scale product described in the plan. Arbitrary user-defined gesture actions, mouse remapping, action graphs, app-specific contexts, window management, scripts, imports, and automatic updates are later phases. Trackpad recognition uses an explicitly isolated compatibility provider and remains subject to hardware testing.

## Requirements

- macOS 15 or later.
- Xcode 26 or a compatible Swift 6.2+ toolchain.

## Build and test

```sh
./Scripts/validate.sh
```

For a development `.app` bundle with a stable bundle identifier:

```sh
./Scripts/build-app.sh
open dist/KeyFlow.app
```

The first time it runs, open the Permissions tab and grant Accessibility and Input Monitoring. Screen Recording is optional and is used only for window-switcher thumbnails. If macOS does not show its one-time prompt, KeyFlow opens the relevant Privacy & Security pane. Enable KeyFlow there; if it is not listed, use **Reveal KeyFlow.app in Finder**, then add that app with the `+` button in System Settings. Return to KeyFlow, select **Refresh Permission Status**, and relaunch the app if macOS still shows the old state.

If System Settings shows a permission enabled while KeyFlow reports it disabled, the row is usually tied to an older build identity. Use **Reset Stale Accessibility Entry…** and/or **Reset Stale Input Monitoring Entry…**, then add and enable the current `dist/KeyFlow.app`. These resets are scoped to KeyFlow and do not change other applications' permissions.

The package can also be opened directly in Xcode:

```sh
open Package.swift
```

## Signing

The development build script creates an isolated, self-signed local identity and keychain when `CODE_SIGN_IDENTITY` is not supplied. This keeps the development app's signing requirement stable across rebuilds so Accessibility and Input Monitoring permissions are not needlessly reset. The generated keychain is ignored by Git and must never be used for distribution.

Use an Apple Development or Developer ID identity when one is available:

```sh
CODE_SIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" ./Scripts/build-app.sh
```

The release pipeline builds a universal binary, signs with Developer ID, submits the app and DMG for notarization, staples both, runs Gatekeeper assessment, and generates checksums. It requires an Apple Developer identity and a `notarytool` keychain profile:

```sh
./Scripts/store-notarization-credentials.sh "KeyFlow Notarization" "you@example.com" "TEAMID"
DEVELOPER_ID_APPLICATION="Developer ID Application: Your Name (TEAMID)" \
NOTARY_PROFILE="KeyFlow Notarization" \
./Scripts/release.sh
```

Release credentials must be supplied through the keychain or protected CI secrets and must never be committed. Automatic updates remain a separate product milestone.

## License

KeyFlow is currently proprietary software. See [LICENSE](LICENSE). Third-party notices are recorded in [Resources/ThirdPartyNotices.txt](Resources/ThirdPartyNotices.txt).

## Architecture

```text
KeyFlowApp
├── Application     app state and runtime orchestration
├── Features        mapping, activity, and permission UI
├── Platform        keyboard, trackpad, actions, and audio adapters
└── Services        permissions, login items, and diagnostics

KeyFlowCore         domain, validation, migration, persistence, matching
KeyFlowMultitouchBridge
                    isolated C compatibility boundary
KeyFlowWindowServerBridge
                    isolated exact-window focus compatibility boundary
```

- `KeyFlowCore` contains the portable domain, validation, persistence, matching, and gesture classification.
- `KeyFlowApp` contains macOS integrations, the event tap, action executor, menu bar, permissions, and UI.
- The event-tap callback does no disk, network, or UI work. Matching uses the current immutable snapshot and dispatches execution off the callback.
- Invalid and disabled mappings are excluded when the runtime snapshot is compiled.

## Safety

- KeyFlow fails open when its keyboard event tap cannot be installed.
- Use **Pause All Mappings** from the menu-bar item before editing a risky shortcut.
- Imported configuration and arbitrary script execution are deliberately absent from this build.
- Typed-text events carry a per-launch marker and bypass KeyFlow matching.

## Next engineering milestones

1. App-specific contexts and deterministic conflict diagnostics.
2. Keyboard sequences, tap/hold/double-tap, Hyper Key, and stuck-key recovery.
3. Mouse buttons, scrolling, and drawing gestures.
4. Complete the raw-touch hardware/OS compatibility matrix and failure-isolation gates.
5. Typed action graphs and the XPC script runner.

See the [architecture](docs/ARCHITECTURE.md), [release checklist](docs/RELEASE_CHECKLIST.md), [multitouch policy](docs/MULTITOUCH_COMPATIBILITY.md), and [product plan](docs/PRODUCT_PLAN.md) for the remaining gates.
