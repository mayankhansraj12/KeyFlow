# Production readiness plan

Updated: 2026-07-16
Target: KeyFlow `0.1.7` (`8`)

This checklist separates source-controlled work from owner actions that require
GitHub administration, Apple Developer credentials, or physical hardware.
Checked items describe the current release. Unchecked items gate a future
Developer ID signed and Apple-notarized distribution.

## 1. Source and product surface

- [x] Reconcile user documentation with implemented behavior.
- [x] Prepare the repository for MIT open-source publication.
- [x] Add contribution, conduct, security, support, privacy, and issue-reporting
  guidance.
- [x] Separate user, contributor, and maintainer documentation.
- [x] Add a product-focused README and social-preview asset.
- [x] Exclude local signing material, credentials, generated builds,
  diagnostics, and machine-local automation state.
- [x] Commit and review the final public repository changes.
- [x] Configure the GitHub description and product topics.
- [ ] Upload the GitHub social preview.

Checkpoint: all public documentation must pass the link, structure, secret,
and source-claim audits before merge.

## 2. Correctness and recovery

- [x] Use schema-versioned, atomic configuration writes.
- [x] Reject stale asynchronous saves.
- [x] Retain a bounded rolling-backup set.
- [x] Recover from a corrupt primary configuration.
- [x] Apply private directory and file permissions.
- [x] Cover migrations through schema 20.
- [x] Keep legacy unsafe actions unavailable in the editor and fail them closed.

Checkpoint: the 107-test suite and warnings-as-errors release build pass.

## 3. Input safety and platform boundaries

- [x] Keep keyboard callback work bounded and dispatch actions elsewhere.
- [x] Tag generated keyboard events to prevent recursive matching.
- [x] Fail open if the keyboard event tap cannot run.
- [x] Isolate undocumented raw multitouch and exact-window behavior in small C
  compatibility bridges.
- [x] Expose raw-provider degradation without disabling keyboard shortcuts.
- [x] Preserve ordinary three-finger macOS swipe behavior.
- [ ] Complete the physical CPU, OS, built-in-trackpad, and Magic Trackpad
  matrix.

Checkpoint: raw multitouch remains explicitly experimental until the physical
matrix passes.

## 4. Performance and resource use

- [x] Filter ordinary one- and two-finger pointer frames before Swift work.
- [x] Reuse the Core Audio session during continuous volume adjustment.
- [x] Coalesce continuous gesture activity.
- [x] Use event-driven screenshot-directory observation rather than periodic
  polling.
- [x] Bound window thumbnails to 32 MB and evict them after 120 seconds without
  access.
- [x] Serialize thumbnail refresh and prioritize the selected preview.
- [x] Enforce deterministic hot-path regression budgets.
- [ ] Record active volume, mute/media, screenshot, and switcher traces using
  Instruments on release hardware.

Checkpoint: idle and synthetic budgets pass; physical interaction traces remain
a release-owner gate.

## 5. Packaging and distribution

- [x] Build arm64 and x86_64 release executables.
- [x] Produce and verify a universal application.
- [x] Package a polished drag-to-Applications DMG with free, hash-pinned build
  tooling.
- [x] Verify bundle metadata, privacy manifest, license, third-party notices,
  architecture, and mounted-DMG contents.
- [x] Smoke-launch the packaged app with an isolated home directory.
- [x] Declare the current channel as a manually updated release.
- [ ] Register or confirm the production bundle identifier.
- [ ] Sign with Developer ID, notarize, staple, and pass Gatekeeper.
- [ ] Test installation and permission onboarding on a clean standard-user
  account.
- [ ] Verify upgrade behavior from the previous published build when one exists.

Checkpoint: the current public DMG is ad-hoc signed. Developer ID signing and
notarization remain future distribution gates.

## 6. GitHub and release governance

- [x] Use least-privilege, checksum-pinned CI workflows.
- [x] Run tests, sanitizer checks, coverage, secret scans, universal packaging,
  and bundle qualification in CI.
- [x] Add CODEOWNERS, a pull-request template, issue forms, Dependabot, and
  release-note categories.
- [x] Enable Issues, private vulnerability reporting, secret scanning, push
  protection, Dependabot security updates, and automatic merged-branch
  deletion.
- [x] Document the required branch, environment, security, and release settings.
- [x] Protect `main` and `dev` with required pull requests, current CI,
  resolved-conversation, administrator, no-force-push, and no-deletion rules.
  Require linear history on integration branch `dev`; preserve release
  promotions with merge commits on `main`.
- [x] Require the metadata-only `Validate promotion source` check on `main` so
  only this repository's `dev` branch can be promoted.
- [x] Create the protected `production` environment and restrict it to
  protected branches.
- [ ] Add an independent reviewer and require one approving CODEOWNER review
  when a second push-capable maintainer exists.
- [ ] Configure the production release secret names and values.
- [x] Re-run the authenticated GitHub production audit after configuration.
- [ ] Run the protected release workflow after Apple credentials are available.

Checkpoint: repository administration must be verified on the exact commit
selected for release.

## 7. Operations and final decision

- [x] Document privacy, diagnostics, incident response, withdrawal, and manual
  update behavior.
- [x] Provide private vulnerability and conduct-reporting routes.
- [x] Document known release limitations.
- [ ] Complete clean-account, sleep/wake, fast-user-switching, permissions,
  exact-window activation, and physical-gesture checks.
- [x] Freeze the reviewed commit and create its version tag.
- [x] Produce and publish the `0.1.7` DMG once.
- [x] Record the release-owner decision by publishing KeyFlow `0.1.7`.

Checkpoint: KeyFlow `0.1.7` is the current manually updated release. Every
unchecked gate remains required before claiming Developer ID signing,
notarization, or hardware qualification.
