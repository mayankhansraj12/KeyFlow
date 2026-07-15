# Contributing

## Local validation

Use macOS 15 or later with Xcode 26 / Swift 6.2 or later:

```sh
./Scripts/validate.sh
CODE_SIGN_IDENTITY=- ./Scripts/build-app.sh
./Scripts/verify-app.sh
```

Add or update tests for every behavioral change. Platform effects should be placed behind an injectable boundary so application behavior can be tested without modifying the developer's permissions, volume, login items, or active applications.

## Architectural rules

- Keep domain and persistence logic in `KeyFlowCore`.
- Keep direct macOS APIs in `KeyFlowApp/Platform` or `KeyFlowApp/Services`.
- Keep undocumented touch ABI code confined to `KeyFlowMultitouchBridge`.
- Do not add disk, UI, network, or action execution to the input callback.
- Preserve fail-open behavior and synthetic-event tagging.
- Never log typed text, action values, or mapping names.

Run `swift format format --in-place --recursive Sources Tests Package.swift` before submitting changes.
