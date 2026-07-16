# Production readiness execution plan

Updated: 2026-07-16
Target: KeyFlow `0.1.7` (`8`)

This document is the release-control checklist for the current production candidate. A phase is complete only when its implementation, automated verification, and documentation checkpoint are all complete. Items that require an Apple Developer account, repository administration, or physical hardware are explicit release gates; they are not silently treated as source-code failures.

## Phase 1 — Baseline and decisions

- [x] Reconcile the implementation status with the repository.
- [x] Run the complete local validation gate before production changes.
- [x] Record the exact release commit and remote divergence.
- [x] Identify legal, distribution, update, compatibility, and operations decisions.
- [ ] Confirm the legal copyright owner before public distribution. **Owner action required.**
- [x] Keep the current distribution promise conservative: direct-download, experimental raw multitouch, no Mac App Store claim.

Checkpoint: `./Scripts/validate.sh` passes with 79 tests on commit `973e948` before the work in this plan.

## Phase 2 — Local correctness and release hardening

- [x] Enforce real thumbnail-cache expiry without requiring another cache access.
- [x] Test cache identity, byte-budget, catalog-removal, and timed-expiry behavior.
- [x] Make release scripts prove version, tag, commit, signature identity, Team ID, notarization, and pushed-commit state.
- [x] Harden release workflow credential files, checkout credentials, cleanup, and artifact validation.
- [x] Add checksum-pinned secret scanning and shell/workflow validation to CI.
- [x] Reconcile privacy, security, release, and implementation documentation with actual behavior.

Checkpoint: 82 tests pass after the cache changes. actionlint 1.7.12 and Gitleaks 8.30.1 are checksum-pinned; workflow validation, native zsh syntax validation, and a complete-history secret scan pass locally. The final all-gates validation is repeated in Phase 10.

## Phase 3 — Test architecture and coverage

- [x] Add deterministic seams for permissions, login items, Core Audio, media keys, thumbnail delivery, window discovery, and switcher activation. Screenshot file delivery remains isolated through storage/state tests and the clean-install matrix because native capture is an OS-owned interaction.
- [x] Cover grant state, denial/fallback, reset failure, cancellation, session expiry, clamping, unmute, empty-window, and media-post failure without mutating the developer Mac.
- [x] Cover permission refresh, gesture conflicts, Sound Bar settings, switcher settings, and menu-owned application presentation state through model/policy tests.
- [x] Add end-to-end runtime tests from discrete/continuous/interactive gesture input to exactly-once dispatch and cancellation.
- [x] Raise the source line-coverage floor from 20% to 27% and the `KeyFlowCore` floor from 80% to 84%.

Checkpoint: 97 tests pass normally. Measured line coverage is 28.31% overall and 85.21% for `KeyFlowCore`; runtime and switcher-controller line coverage are 73.82% and 71.43%. Sanitizer runs are repeated after all source changes in Phase 10.

## Phase 4 — Performance and responsiveness

- [x] Add opt-in signposts around audio writes, screenshot capture, window enumeration/activation, switcher lifecycle, and thumbnail capture. High-frequency touch routing remains unsignposted to avoid diagnostic overhead in the path being measured.
- [x] Add repeatable performance tests for high-frequency gesture frames, volume accumulation, two-axis selection, and cached audio adjustment.
- [x] Preserve immediate cached/icon-first UI publication, serialize thumbnails, reuse the Core Audio session/HUD, and replace screenshot directory polling with kernel-backed filesystem notification.
- [ ] Verify active gesture CPU, memory ceiling, screenshot latency, and overlay frame pacing with Instruments. **Physical interaction checkpoint required.** Idle packaged-process sampling is recorded below.

Checkpoint: 50,000 combined input/navigation policy iterations complete in 35 ms and 10,000 cached audio adjustments in 3 ms on the local Apple-silicon development Mac. The already-running packaged app sampled at 0.0% idle CPU and 129,072 KB RSS after one hour. Release-hardware interaction traces remain required.

## Phase 5 — Raw multitouch compatibility

- [x] Expose provider availability and degraded-mode reasons in diagnostics and UI.
- [x] Add a local compatibility policy capable of disabling raw gestures by OS/build.
- [x] Define the signed remote compatibility-manifest design and keep raw gestures explicitly experimental until that design is implemented and qualified.
- [ ] Complete the physical-device matrix in `MULTITOUCH_COMPATIBILITY.md`. **Hardware action required.**

Checkpoint: automated policy tests pass, provider failure always fails open, and keyboard shortcuts remain usable. Physical matrix sign-off remains a release-owner hardware gate.

## Phase 6 — Updates and release architecture

- [x] Explicitly scope `0.1.7` as a manually updated beta in machine-verifiable bundle metadata and defer automatic updates from this candidate.
- [x] Document the signed updater architecture, channel rules, key custody, rollback, privacy, and qualification requirements.
- [ ] Generate and protect the update signing key. **Owner credentials required.**
- [ ] Configure a HTTPS update feed and test upgrade, rollback refusal, signature failure, and no-update states. **Hosting action required.**
- [ ] Ensure updates preserve bundle identity, TCC registration, configuration, and login-item state.

Checkpoint: packaging proves the candidate is a manually updated beta. A notarized prior-build upgrade remains required before changing that release policy.

## Phase 7 — Packaging and clean-install qualification

- [ ] Produce a Developer ID signed, notarized, stapled ZIP and DMG. **Apple credentials required.**
- [ ] Verify Gatekeeper offline after stapling.
- [x] Build and strictly verify a locally signed universal app, then round-trip it through ZIP and mounted DMG packaging.
- [x] Smoke-launch the packaged app with an isolated home directory and raw multitouch disabled.
- [ ] Test fresh install, upgrade, moved bundle, permission revoke/regrant, login item, sleep/wake, and configuration recovery on a standard account.
- [ ] Verify arm64 and x86_64 slices on matching hardware or virtualized test hosts. **Hardware action required.**

Checkpoint: the release checklist has evidence for every manual gate and SHA-256 checksums match the published artifacts.

## Phase 8 — GitHub production controls

- [ ] Push the reviewed source through a pull request.
- [ ] Require the CI check and review on `main`; block force-push and branch deletion.
- [ ] Configure the protected `production` environment, required reviewer, and release secrets.
- [x] Add CODEOWNERS, a production-risk PR template, and weekly GitHub Actions/Swift Dependabot configuration.
- [x] Add an authenticated audit for branch protection, environment secret names, private vulnerability reporting, secret scanning, and push protection.
- [ ] Enable and verify remote secret scanning/push protection, private vulnerability reporting, and signed-release policy.
- [ ] Run CI and the non-publishing release workflow on the exact candidate commit.

Checkpoint: the remote branch, environment, workflow run, and release artifact all reference the same immutable commit.

## Phase 9 — Operations, privacy, and support

- [x] Define HTTPS privacy/support URLs and expose them from the menu-bar UI; they resolve through the public repository after the candidate is pushed.
- [ ] Configure a private security-reporting channel. **Repository owner action required.**
- [x] Document diagnostic collection, retention, redaction, incident response, rollback, and release ownership.
- [x] Finalize candidate release notes, known limitations, compatibility status, and support boundary.

Checkpoint: operational contacts and URLs are present in the release metadata and verified from a clean browser session.

## Phase 10 — Final release decision

- [x] Re-run local validation, both sanitizers, coverage, universal build, bundle audit, isolated-home smoke launch, ZIP/DMG round trip, workflow lint, zsh syntax validation, and source/history secret scans.
- [x] Resolve every source-controlled critical/high finding and explicitly retain external release blockers.
- [ ] Complete clean-account/hardware checks and remote CI on the reviewed candidate.
- [ ] Freeze the commit, create the matching signed tag, and produce artifacts once.
- [ ] Approve or reject the release using the evidence in `PRODUCTION_AUDIT_REPORT.md`.

Checkpoint: the source is locally qualified for review as a manual beta. It is not approved for public distribution until every external blocker is evidenced and the release owner signs the exact commit and checksums.
