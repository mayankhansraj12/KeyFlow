# KeyFlow product roadmap

Updated: 2026-07-16
Current candidate: `0.1.7` (`8`)
Distribution target: signed and notarized direct download for macOS 15 or later

This roadmap describes KeyFlow's current direction. It replaces the original
pre-implementation concept plan, whose estimates, hypothetical team structure,
and first-build backlog no longer represented the repository.

## Product direction

KeyFlow is a local-first macOS shortcut and input-customization utility. Its
goal is to make frequent keyboard, trackpad, audio, screenshot, and
window-switching workflows faster without turning input handling into an
opaque or unsafe background service.

KeyFlow is not intended to reproduce another product's identity, interface, or
proprietary presets. It develops its own focused workflows and architecture.

## Product principles

1. **Input remains predictable.** A failure must not trap or indefinitely
   suppress normal keyboard or pointer input.
2. **The input path stays small.** Event callbacks perform bounded
   normalization and matching, then dispatch work elsewhere.
3. **Power is explicit.** Permissions and experimental compatibility features
   are disclosed where users enable them.
4. **Configuration remains local.** KeyFlow has no account, advertising,
   analytics, telemetry, or cloud requirement.
5. **Recovery is built in.** Configuration writes are atomic, backups are
   bounded, corrupt state is recoverable, and all mappings can be paused.
6. **Capabilities ship only when they are supportable.** Roadmap items do not
   appear in the editor until their runtime, migration, privacy, and failure
   behavior are implemented.

## Current beta

The `0.1.7` candidate currently provides:

- global keyboard chords that open a selected application;
- optional suppression of the original keyboard shortcut;
- conflict-safe three-, four-, and five-finger tap/click features;
- continuous four- and five-finger volume adjustment;
- independent Sound Bar appearance and behavior settings;
- native full-screen and interactive screenshots with optional additional
  file copies;
- a persistent four-finger, two-axis window switcher;
- optional Screen Recording-backed window previews;
- menu-bar controls, optional Dock visibility, and launch at login;
- local schema-versioned configuration with rolling backups;
- privacy-redacted diagnostics and bounded in-memory activity.

The exact supported behavior and limitations are maintained in
[Features](FEATURES.md) and
[Implementation status](IMPLEMENTATION_STATUS.md).

## Platform boundary

Keyboard capture, event synthesis, accessibility control, Core Audio, and
ScreenCaptureKit use documented macOS APIs.

Global raw finger-contact recognition is different: macOS does not expose a
stable public API for arbitrary system-wide trackpad contacts. KeyFlow isolates
that capability behind a runtime-loaded compatibility bridge and labels it
experimental. It must:

- never require root access, a kernel extension, or disabling SIP;
- fail open when the framework, symbols, device, or compatibility policy are
  unavailable;
- leave keyboard shortcuts and normal pointer behavior usable;
- remain direct-download only unless Apple provides an appropriate supported
  path;
- pass the physical matrix in
  [Multitouch compatibility](MULTITOUCH_COMPATIBILITY.md) before being called
  stable.

## Release roadmap

### Public beta readiness

Before publishing the first official binary:

- complete the public repository presentation and community documentation;
- protect `main` and configure the production release environment;
- complete physical Apple-silicon, Intel, built-in-trackpad, and Magic
  Trackpad checks;
- record active-gesture performance and frame-pacing traces;
- sign with Developer ID, notarize, staple, and pass Gatekeeper;
- verify a clean installation, permissions, sleep/wake, login launch, and
  configuration upgrade;
- publish immutable checksums and release notes with the DMG.

The current gate is tracked in
[Production readiness](PRODUCTION_READINESS_PLAN.md).

### `0.2` — mapping foundation

Planned priorities:

- app-specific contexts and deterministic conflict explanations;
- keyboard sequences, tap/hold/double-tap behavior, modifier-only triggers,
  and a configurable Hyper Key;
- mouse-button and scroll triggers;
- multiple ordered actions per mapping with cancellation and timeouts;
- configuration export plus a visible backup/recovery browser;
- stronger keyboard-layout and stuck-key recovery coverage.

### Later workflow expansion

Capabilities considered after the mapping foundation is stable:

- supported window move, resize, snapping, and reusable layouts;
- richer media, display, file, URL, Apple Shortcut, and notification actions;
- explicit conditions and named workflows;
- an isolated script runner with strict time, capability, and output limits;
- import review with risky capabilities disabled until approved;
- opt-in clipboard workflows with clear exclusions and retention controls;
- documented automation interfaces that do not expose unauthenticated local
  control.

These are roadmap items, not current product claims.

## Explicit non-goals

KeyFlow will not require or ship:

- a kernel extension, root daemon, or SIP bypass;
- hidden input recording or a keylogging history;
- automatically uploaded clipboard, screenshot, window, or input content;
- arbitrary downloaded native plug-ins;
- a promise to override Secure Input, FileVault, the login window, or other
  protected macOS surfaces;
- a pixel-for-pixel copy of another application's product design.

## Architecture direction

The current architecture remains the base for future work:

- `KeyFlowCore` owns configuration, validation, migration, matching, and
  deterministic policies.
- `KeyFlowApp` owns SwiftUI/AppKit presentation and macOS integrations.
- Native compatibility bridges remain small, runtime-checked, and isolated
  from configuration, networking, and UI.
- Input callbacks do no disk, network, UI, screenshot, audio, or action work.
- New effects sit behind injectable boundaries and return typed failures.
- Configuration schema changes include migration and recovery tests.

See [Architecture](ARCHITECTURE.md) for the enforced repository boundaries.

## Quality and privacy gates

A roadmap capability is ready only when it includes:

- user-facing behavior and failure-state documentation;
- deterministic domain and migration tests;
- appropriate macOS integration or physical-hardware qualification;
- accessibility labels and keyboard operation for its settings;
- privacy classification and redacted diagnostics;
- bounded memory, concurrency, and callback behavior;
- a disable, fallback, or recovery path;
- release notes when the change affects users or permissions.

The current performance expectations are documented in
[Performance qualification](PERFORMANCE.md).

## Planning and contributions

Focused bug fixes, tests, accessibility improvements, documentation, and
performance work are welcome. Open an issue before implementing a large
roadmap capability so its user workflow, platform support, and safety boundary
can be agreed before substantial code is written.

See [Contributing](../CONTRIBUTING.md) for the development workflow.
