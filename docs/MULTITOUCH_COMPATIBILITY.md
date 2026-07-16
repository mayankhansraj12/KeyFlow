# Multitouch compatibility policy

## Distribution decision

Four-finger raw contact recognition uses symbols loaded at runtime from Apple's undocumented `MultitouchSupport` framework. This provider is experimental and intended for signed, notarized direct distribution. It must not be represented as Mac App Store compatible or guaranteed across macOS updates.

The app never asks users to disable SIP, install a kernel extension, run as root, or load third-party native plug-ins.

## Isolation and fallback

- All undocumented ABI declarations remain inside `KeyFlowMultitouchBridge`.
- Availability and required symbols are checked at runtime.
- Framework, symbol, device, start, and policy failures are distinguished in the Permissions UI and redacted diagnostics.
- `KEYFLOW_DISABLE_RAW_MULTITOUCH=1` disables the raw provider without disabling keyboard shortcuts.
- A source-controlled OS-build deny list provides an emergency gate in the next signed build.
- Failure to load or start the provider leaves keyboard mappings and public AppKit gestures operational.
- Raw frames are limited to 32 copied contacts and contain geometry only.
- The provider has no access to configuration storage, action execution, networking, or UI.
- Four-finger suppression is active only while four contacts are present and an applicable mapping exists. Input otherwise fails open.

## Release compatibility matrix

Each production candidate must record pass/fail results for:

| Environment | Required coverage |
|---|---|
| Apple silicon laptop | Oldest supported macOS and current macOS |
| Intel laptop | Oldest supported macOS and current macOS |
| Apple Magic Trackpad | USB and Bluetooth where available |
| System gestures | Mission Control/App Exposé configured for three and four fingers |
| Lifecycle | Login launch, sleep/wake, lock/unlock, fast user switching |
| Permissions | Fresh install, upgrade, permission revoke/regrant, moved app bundle |
| Input stress | Rapid gestures, palm/extra contact, gesture cancellation, pause/resume |

Required outcomes:

- Four-finger taps fire once.
- Vertical sweeps emit incremental events without runaway repeats.
- Horizontal sweeps open one persistent switcher, update its blue selection while contacts remain down, and activate exactly one window on release.
- Opposite/horizontal movement does not fire a vertical mapping.
- Mission Control or another system gesture is not triggered when KeyFlow successfully consumes its mapped four-finger gesture.
- If suppression is unavailable, KeyFlow reports degraded behavior instead of claiming full success.
- Provider failure never prevents normal keyboard or mouse use.

## Ship gate

Do not label raw gestures stable until the matrix passes on physical hardware. A macOS beta or update that changes the private ABI blocks the raw provider for that OS until revalidated. Keyboard shortcuts and public gestures may still ship with raw gestures marked unavailable.

The signed compatibility-manifest protocol is specified in `MULTITOUCH_COMPATIBILITY_MANIFEST.md`, but its network client and release service are intentionally not part of this manually updated beta. Until that system is implemented and qualified, raw gestures remain explicitly experimental.
