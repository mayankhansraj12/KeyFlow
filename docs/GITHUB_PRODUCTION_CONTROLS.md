# GitHub production controls

Repository: `mayankhansraj12/KeyFlow`

Source-controlled controls include least-privilege workflows, immutable action SHAs, full-history secret scanning, sanitizer/coverage/package gates, CODEOWNERS, a production-risk PR template, and weekly GitHub Actions/Swift dependency checks.

## Required repository settings

Configure these through an authenticated repository-owner session, then run `./Scripts/audit-github-production.sh`:

1. Protect `main`, require the `Build, test, and package` check to be current, require at least one approving CODEOWNER review, require resolved conversations, include administrators, require linear history, and forbid force-push/deletion.
2. Create a protected `production` environment. Add a reviewer who is independent of the release initiator when the team permits it, restrict deployment to protected branches, and add only the secret names listed by the audit script.
3. Enable private vulnerability reporting, secret scanning, and push protection.
4. Keep Dependabot alerts and security updates enabled. Review dependency PRs through normal CI; do not auto-merge release/signing dependencies.
5. Require signed commits/tags for release policy. The release script independently verifies the signed version tag and exact pushed commit.
6. Do not allow the release workflow to publish until Developer ID/notarization, physical compatibility, privacy/support/legal, and clean-install gates are signed off.

The audit reads setting state and secret names only. It never reads secret values. Repository settings are not treated as complete until its output is attached to the candidate evidence.
