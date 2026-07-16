# Production audit report

Updated: 2026-07-16
Release: KeyFlow `0.1.7` (`8`)
Configuration schema: `20`

> [!NOTE]
> This is public maintainer evidence for the current release. User
> documentation starts at the [documentation index](README.md).

## Executive status

KeyFlow `0.1.7` is published as a manually updated, open-source release. Its
free DMG is ad-hoc signed rather than Developer ID signed or Apple-notarized.

All automated local gates pass. The remaining production-distribution gates
require Apple Developer credentials, clean-account testing, physical
trackpad/CPU coverage, or release-owner approval.

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
| Repository protection | Pass for one maintainer | `main` and `dev` require pull requests, current CI, resolved conversations, linear history, and administrator compliance; force-push and deletion are blocked |
| Release governance | Partial | The stable GitHub release is public; the protected `production` environment still lacks Apple release secrets and an independent reviewer |
| Signing and notarization | Blocked externally | Developer ID identity, registered bundle ID, notarization credentials, and release-owner approval are required |
| Automatic updates | Deliberately deferred | Bundled release policy identifies this release as `manual`; no update client or feed is claimed |
| Open-source licensing | Pass locally | Project source is prepared under MIT; yabai-derived code and build-tool notices are recorded |

## Remaining production-distribution gates

1. Upload the social preview, add the protected release secrets, and add an
   independent approval gate when a second maintainer becomes available, as
   described in [GitHub production controls](GITHUB_PRODUCTION_CONTROLS.md).
2. Complete the physical compatibility matrix and active-interaction
   performance traces.
3. Build a Developer ID signed, notarized, stapled artifact and verify it on a
   clean standard-user account.
4. Publish a future notarized release from the protected production workflow.

## Accepted release limitations

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
