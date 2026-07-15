# Architecture

## Repository boundaries

```text
Sources/
├── KeyFlowApp/
│   ├── Application/       lifecycle, observable state, runtime coordination
│   ├── Features/          SwiftUI feature surfaces
│   ├── Platform/          direct macOS integration
│   │   ├── Actions/
│   │   ├── Audio/
│   │   ├── Input/
│   │   ├── Screenshots/
│   │   └── Windows/
│   └── Services/          application presentation, permissions, login items, diagnostics
├── KeyFlowCore/           portable domain, validation, migration, repository
├── KeyFlowMultitouchBridge/
│                          isolated undocumented touch ABI boundary
└── KeyFlowWindowServerBridge/
                           isolated exact-window focus compatibility boundary

Tests/
├── KeyFlowCoreTests/
└── KeyFlowAppTests/
```

`KeyFlowCore` must not import SwiftUI, AppKit, ApplicationServices, CoreGraphics, ServiceManagement, or either platform bridge. `KeyFlowApp` may depend on Core and the bridges. The bridges must not know about mappings, actions, persistence, networking, or UI.

## Runtime flow

1. The repository loads and migrates the configuration, recovering a valid backup when the primary JSON is corrupt.
2. The app compiles enabled, valid mappings into an immutable `RuntimeSnapshot`.
3. Keyboard and trackpad adapters normalize input and match against the current snapshot.
4. The keyboard event-tap callback performs bounded matching only. Action execution is dispatched away from the callback.
5. `AppRuntimeController` joins the input adapters and publishes matches/status to `AppModel`.
6. `ActionExecutor` performs macOS effects and reports a bounded, redacted result to the UI.

## Dependency rules

- UI code talks to `AppModel`, not directly to TCC, event taps, Core Audio, or persistence.
- Platform effects sit behind injectable protocols wherever application behavior needs tests.
- Configuration revisions are monotonic. Stale asynchronous saves cannot replace newer state.
- Synthesized keyboard events carry a per-launch marker and bypass matching.
- Input interception fails open if the event tap cannot run.
- Diagnostics never include typed text, action values, or mapping names.

## Concurrency

- UI and application orchestration run on the main actor.
- Configuration persistence is serialized by an actor.
- The Quartz event tap owns a dedicated run-loop thread.
- Its callback does no file, network, UI, or action work.
- Raw touch frames are copied into bounded value types before crossing into Swift concurrency.

## Release boundaries

Development builds use an ignored local keychain and stable self-signed identity. Production builds must use the universal-build and Developer ID release pipeline. Private keys and notarization credentials are accepted only through the macOS keychain or protected CI secrets.
