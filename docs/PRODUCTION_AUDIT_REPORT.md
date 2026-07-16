# Production audit report

Updated: 2026-07-16
Candidate: KeyFlow `0.1.7` (`8`)
Configuration schema: `20`

> [!NOTE]
> This is public maintainer evidence for the current beta candidate. User
> documentation starts at the [documentation index](README.md).

## Executive status

The source candidate is locally qualified for review as a manually updated,
open-source beta. It is not an officially signed, notarized, or
hardware-qualified public binary.

All automated local gates pass. Remaining release gates require GitHub
repository administration, Apple Developer credentials, clean-account
testing, physical trackpad/CPU coverage, or release-owner approval.

## Current evidence

| Area | State | Evidence or remaining gate |
|---|---|---|
| Source validation | Pass | `./Scripts/validate.sh`; 107 tests and warnings-as-errors release build |
| Coverage | Pass | 51.97% source line coverage and 90.36% `KeyFlowCore`; enforced floors are 27% and 84% |
| Sanitizers | Pass | AddressSanitizer and ThreadSanitizer pass the complete suite |
| Persistence | Pass | Schema migration, stale-save rejection, atomic writes, rolling backups, corrupt-primary recovery, and private filesystem permissions |
| Privacy | Pass locally | Privacy manifest, permission-purpose text, redacted diagnostics, bounded activity, and bounded thumbnail retention match implementation |
| Universal packaging | Pass locally | arm64 and x86_64 executable slices, strict local signature, isolated-home startup, ZIP round trip, and mounted-DMG verification |
| Local installer | Pass | Polished drag-to-Applications DMG builds and verifies without paid third-party tooling |
| Secret scanning | Pass | Source and complete Git history pass Gitleaks; local signing, credentials, diagnostics, generated apps, and DMGs are ignored |
| Remote CI baseline | Pass | Public `main` baseline `29f059f` passed [workflow run 29491147475](https://github.com/mayankhansraj12/KeyFlow/actions/runs/29491147475) |
| Raw multitouch | Conditional | Provider isolation, compatibility policy, and fail-open fallback are tested; physical matrix remains incomplete |
| Performance | Partial | Automated hot-path budgets pass; active physical gesture, screenshot, and switcher Instruments traces remain required |
| Public repository metadata | Pass | Description, product topics, Issues, private vulnerability reporting, secret scanning, push protection, Dependabot security updates, and automatic merged-branch deletion are enabled |
| Repository protection | Pass for one maintainer | `main` requires pull requests, current CI, resolved conversations, linear history, and administrator compliance; force-push and deletion are blocked |
| Release governance | Blocked externally | The protected `production` environment exists, but release secrets, an independent reviewer, and the social-preview upload remain unavailable |
| Signing and notarization | Blocked externally | Developer ID identity, registered bundle ID, notarization credentials, and release-owner approval are required |
| Automatic updates | Deliberately deferred | Bundled release policy identifies this candidate as `manual-beta`; no update client or feed is claimed |
| Open-source licensing | Pass locally | Project source is prepared under MIT; yabai-derived code and build-tool notices are recorded |

## Publication blockers

1. Commit and review the final documentation, license, installer tooling, and
   repository community files.
2. Upload the social preview, add the protected release secrets, and add an
   independent approval gate when a second maintainer becomes available, as
   described in [GitHub production controls](GITHUB_PRODUCTION_CONTROLS.md).
3. Complete the physical compatibility matrix and active-interaction
   performance traces.
4. Build a Developer ID signed, notarized, stapled candidate and verify it on a
   clean standard-user account.
5. Freeze the reviewed commit, create its signed version tag, publish immutable
   checksums, and record the release decision.

## Accepted beta limitations

- Raw multi-finger gestures remain experimental.
- Distribution is direct download rather than the Mac App Store.
- Updates are manual.
- Screen Recording is optional and used only for switcher previews.
- App-specific contexts, mouse/scroll remapping, multi-action workflows,
  scripts, and automatic updates are roadmap work.

## Reproduction commands

```sh
./Scripts/validate.sh
./Scripts/coverage.sh
./Scripts/build-local-dmg.sh
./Scripts/qualify-local-package.sh
```

Credentialed release and physical-device checks remain governed by
[Release checklist](RELEASE_CHECKLIST.md).
