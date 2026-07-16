# Contributing to KeyFlow

Thank you for helping improve KeyFlow. Contributions are welcome for bug fixes,
tests, documentation, accessibility, performance, design refinement, and
carefully scoped features.

By participating, you agree to follow the [Code of Conduct](CODE_OF_CONDUCT.md).
Contributions are provided under the repository's [MIT License](LICENSE).

## Before you start

- Search existing issues and pull requests before opening a duplicate.
- Open an issue before implementing a large feature or architectural change.
- Keep pull requests focused. Unrelated changes are harder to review safely.
- Never include private input data, window content, credentials, signing
  material, or personal configuration in an issue, test, or pull request.

## Development setup

KeyFlow requires macOS 15 or later and Xcode 26, or a compatible Swift 6.2+
toolchain.

```sh
git clone https://github.com/mayankhansraj12/KeyFlow.git
cd KeyFlow
./Scripts/validate.sh
```

Build and open the packaged app:

```sh
./Scripts/build-app.sh
open dist/KeyFlow.app
```

See [Building and releasing](docs/BUILDING.md) for universal and DMG builds.

## Pull request expectations

KeyFlow uses a controlled promotion workflow:

- Create short-lived `feature/*`, `fix/*`, `docs/*`, or `chore/*` branches
  from `dev` and open pull requests back into `dev`.
- Pull requests into `dev` may originate from any contributor branch or fork
  that passes the required checks.
- Do not open a pull request directly into `main`. Production changes reach
  `main` only through a pull request from this repository's `dev` branch.
- Maintainers squash or rebase focused contributor pull requests into `dev`.
  A production promotion from `dev` to `main` uses a merge commit so the
  integrated development history is preserved.
- Emergency fixes follow the same route: `hotfix/*` to `dev`, then `dev` to
  `main`.

- Add or update tests for behavioral changes.
- Keep platform effects behind injectable boundaries where practical.
- Update user documentation when behavior, permissions, privacy, or
  configuration changes.
- Preserve fail-open input behavior and synthetic-event tagging.
- Do not perform disk, UI, network, or action work inside input callbacks.
- Do not log typed text, mapping values, window content, or trackpad contacts.

Before submitting:

```sh
swift format format --in-place --recursive Sources Tests Package.swift
./Scripts/validate.sh
git diff --check
```

Packaging, input, screenshot, window-switcher, or raw-multitouch changes may
also require the checks documented in
[the release checklist](docs/RELEASE_CHECKLIST.md).

## Architecture

- `KeyFlowCore` owns domain rules, configuration, migration, and matching.
- `KeyFlowApp/Platform` and `KeyFlowApp/Services` own direct macOS integration.
- `KeyFlowMultitouchBridge` contains the undocumented raw-touch ABI boundary.
- `KeyFlowWindowServerBridge` contains the exact-window focus compatibility
  boundary.

Read [Architecture](docs/ARCHITECTURE.md) before changing these boundaries.

## Reporting security issues

Do not open a public issue for a vulnerability. Follow
[SECURITY.md](SECURITY.md) and use GitHub's private vulnerability reporting
flow.
