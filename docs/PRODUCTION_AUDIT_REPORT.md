# Production audit report

Updated: 2026-07-16
Candidate: KeyFlow `0.1.7` (`8`)
Baseline commit: `973e948f38edbd7068b449561aef41fc02cc3ad0`

## Executive status

The source-controlled candidate is locally qualified as a manually updated beta, but it is not yet a publicly releasable production build. All automated local gates pass. Remaining blockers require release-owner credentials, repository settings, clean-account/physical hardware evidence, legal identity, or an explicit later implementation (signed automatic updates and remote multitouch compatibility control).

## Evidence ledger

| Area | State | Evidence / next gate |
|---|---|---|
| Source validation | Pass | `./Scripts/validate.sh`; 102 tests and the warnings-as-errors release build pass on the final working state |
| Persistence | Pass | Atomic writes, migration persistence, rolling backup, corrupt-primary recovery, and file-mode tests |
| Privacy metadata | Pass | Manifest and purpose string pass; deadline-driven cache eviction now enforces the documented in-memory retention independently of later cache access |
| Universal packaging | Local pass | arm64 and x86_64 executable slices, strict local signature, isolated-home startup, and ZIP/mounted-DMG round trips verified; public signature is absent |
| Signing/notarization | Blocked externally | Local identity is development-only; Developer ID certificate and notarization credentials are required |
| Raw multitouch | Conditional | Exact degraded reasons, a tested local OS/build gate, an environment kill switch, and a signed-manifest design exist; physical hardware/OS matrix and remote-manifest implementation remain open |
| Automatic updates | Deliberately deferred | Machine-verifiable bundle policy and release checks scope `0.1.7` as manual-beta; signed updater architecture is documented, while key/feed/upgrade qualification remain owner gates |
| Platform integration tests | Pass locally / hardware gate remains | 102 tests plus AddressSanitizer and ThreadSanitizer cover injected permission, login item, audio, media, runtime, screenshot events, thumbnail cache, compatibility policy, and switcher behavior; real TCC, Core Audio devices, ScreenCaptureKit, and exact AX activation remain clean-install/hardware gates |
| Performance evidence | Partial / hardware gate remains | Event-driven screenshot waiting, opt-in signposts, regression budgets, and an idle sample are recorded; active physical gesture/Instruments traces remain required |
| Remote CI | Pass for source candidate | Draft PR [#1](https://github.com/mayankhansraj12/KeyFlow/pull/1) is open against `main`; hosted run [29461348699](https://github.com/mayankhansraj12/KeyFlow/actions/runs/29461348699) passed every CI gate on source commit `ca685aa0f9c651f419a9e26d68722147e3d9df67` |
| Repository controls | Partial / governance gate | CODEOWNERS, PR policy, weekly dependency updates, and an authenticated audit exist. GitHub vulnerability alerts, Dependabot security updates, private vulnerability reporting, secret scanning, and push protection are enabled. `main` is not protected, the `production` environment is absent, and no independent required reviewer is configured |
| Legal ownership | Needs confirmation | Proprietary license uses the placeholder “KeyFlow contributors”; the release owner must confirm the legal copyright holder |

## Release blockers

1. No Developer ID signed, notarized, stapled candidate exists.
2. No clean-install and upgrade qualification has been recorded.
3. Raw multitouch has no completed physical compatibility matrix.
4. The draft PR has not been independently reviewed or merged, `main` has no required CI/review protection, and no protected `production` environment exists.
5. Physical interaction performance traces and clean-account platform qualification are not complete; deterministic hot-path budgets and idle/package evidence pass locally.
6. Final legal ownership and broad-release update credentials/hosting are not finalized. Privacy/support URLs, private vulnerability reporting, and the manual-beta update scope are configured.

## Accepted candidate limitations

- Direct-download distribution only.
- Raw multitouch remains experimental until its matrix and compatibility control are complete.
- Automatic updates may be deferred only if `0.1.7` is explicitly released as a manually updated beta.
- BetterTouchTool-scale roadmap features are not part of the `0.1.7` production-readiness gate.

## Change log for this audit

- 2026-07-16: Established baseline; local validation passed with 79 tests. Recorded local/remote divergence and the initial release-blocker set.
- 2026-07-16: Added deadline-driven thumbnail eviction plus budget/catalog tests; suite now has 82 passing tests.
- 2026-07-16: Hardened release provenance, Team ID/notarization evidence, ephemeral secret handling, pinned workflow linting, and complete-history secret scanning. Local actionlint and Gitleaks checks pass.
- 2026-07-16: Replaced hard-coded audio/media/service/switcher globals with injected production adapters, fixed pause-time switcher cancellation, and expanded the suite to 97 tests. Coverage is 28.31% overall and 85.21% for `KeyFlowCore`; floors increased to 27%/84%.
- 2026-07-16: Replaced screenshot directory polling with cancellable filesystem events, added opt-in production signposts and hot-path budgets, and expanded the suite to 101 tests. Local budgets measured 35 ms for 50,000 input/navigation iterations and 3 ms for 10,000 cached audio adjustments; the existing packaged process sampled at 0.0% idle CPU and 129,072 KB RSS after one hour.
- 2026-07-16: Added exact raw-multitouch provider failure reporting, a tested source-controlled OS/build policy, an emergency environment kill switch, and a signed compatibility-manifest design. Raw gestures remain an experimental beta feature pending physical matrix sign-off and remote-manifest implementation.
- 2026-07-16: Formalized `0.1.7` as a manually updated beta using bundled release-policy metadata enforced by packaging/audit scripts, and specified the signed updater, channel, key-custody, rollback, privacy, and qualification architecture.
- 2026-07-16: Built a locally signed universal candidate, verified both slices and bundle policy, smoke-launched it with an isolated home, and added repeatable ZIP/mounted-DMG round-trip qualification. Developer ID notarization and clean-account hardware/TCC qualification remain external gates.
- 2026-07-16: Confirmed authenticated admin access to the public GitHub repository, added CODEOWNERS/PR/dependency policy and CI package qualification, and added an audit for branch protection, protected environment secret names, private reporting, secret scanning, and push protection. Remote mutation and candidate CI remain open until the reviewed commit is pushed.
- 2026-07-16: Added HTTPS privacy/support metadata and menu links, a beta support boundary, diagnostic retention/redaction policy, incident/rollback/release-ownership runbook, and `0.1.7` release notes. Private security reporting and final legal ownership remain owner gates.
- 2026-07-16: Final local gate passed with 102 tests, warnings-as-errors release build, AddressSanitizer, ThreadSanitizer, 28.75% overall/85.06% Core coverage, actionlint, native zsh syntax validation, filesystem/full-history secret scans, a universal build, strict bundle verification, isolated-home startup, and ZIP/mounted-DMG qualification.
- 2026-07-16: Draft PR #1 exposed an undeclared `rg` dependency on GitHub's macOS 26 runner after tests/build passed. Replaced release-script searches with system `grep` and advanced checkout/upload actions to their current Node-compatible pinned releases before rerunning CI.
- 2026-07-16: The next PR run exposed a fixed-delay assumption in the automatic thumbnail-eviction test on a busy hosted runner. Replaced it with a bounded eventual assertion that still never invokes cache cleanup; production deadline eviction is unchanged.
- 2026-07-16: Hosted pull-request run 29461348699 passed all tests, sanitizers, coverage, workflow/security checks, universal packaging, bundle verification, isolated startup, and ZIP/DMG qualification on `ca685aa`. The initial live settings audit confirmed secret scanning and push protection enabled and identified the remaining repository-control gaps addressed in the following checkpoint.
- 2026-07-16: Enabled and API-verified GitHub vulnerability alerts, Dependabot security updates, and private vulnerability reporting. Branch protection and a reviewer-protected `production` environment remain governance gates because no independent reviewer or Apple release credentials are configured.
