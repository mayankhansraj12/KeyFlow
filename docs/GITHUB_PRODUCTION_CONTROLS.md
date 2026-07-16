# GitHub production controls

Repository: `mayankhansraj12/KeyFlow`

Source-controlled controls include least-privilege workflows, immutable action SHAs, full-history secret scanning, sanitizer/coverage/package gates, CODEOWNERS, a production-risk PR template, and weekly GitHub Actions/Swift dependency checks.

## Public repository presentation

Treat the repository landing page as part of the product. Configure these values
through **Settings → General**:

- **Description:** `Open-source macOS shortcuts, trackpad gestures, and fluid window switching.`
- **Topics:** `macos`, `swift`, `swiftui`, `keyboard-shortcuts`,
  `trackpad-gestures`, `window-switcher`, `productivity`, `automation`,
  `open-source`, and `accessibility`.
- **Social preview:** upload
  [`assets/github-social-preview.png`](assets/github-social-preview.png).
- **Website:** leave this empty until an official KeyFlow site is deployed. Do
  not point it at an unrelated or temporary host.

Keep the README, release notes, screenshots, supported macOS versions, and
download links accurate for the latest public build. Publish binary downloads
through GitHub Releases with checksums; do not commit release artifacts to the
repository.

Recommended community features:

- Use Issues for reproducible bugs and scoped feature requests.
- Enable Discussions when there is enough maintainer capacity for usage and
  design questions.
- Keep private vulnerability reporting enabled for security issues.
- Add a repository banner or product website only when it has a stable owner
  and maintenance plan.

## Required repository settings

Configure these through an authenticated repository-owner session, then run `./Scripts/audit-github-production.sh`:

1. Protect both long-lived branches, `main` and `dev`. Require pull requests
   and a current `Build, test, and package` check, require resolved
   conversations, include administrators, require linear history, and forbid
   force-push/deletion on both branches.
   While the repository has only one push-capable maintainer, the approval
   count remains zero so changes are not made impossible to merge. As soon as
   a second maintainer is added, require at least one approving CODEOWNER
   review.
2. Keep automatic head-branch deletion enabled for short-lived feature
   branches. The protection rule on `dev` prevents GitHub from deleting it
   when a `dev`-to-`main` pull request is merged. Create feature branches from
   `dev`, merge them back through pull requests, and keep `dev` synchronized
   with every production release.
3. Create a protected `production` environment. Add a reviewer who is
   independent of the release initiator when the team permits it, restrict
   deployment to protected branches, and add only the secret names listed by
   the audit script.
4. Enable private vulnerability reporting, secret scanning, and push protection.
5. Keep Dependabot alerts and security updates enabled. Review dependency PRs through normal CI; do not auto-merge release/signing dependencies.
6. Require signed commits/tags for release policy. The release script independently verifies the signed version tag and exact pushed commit.
7. Do not allow the release workflow to publish until Developer ID/notarization, physical compatibility, privacy/support/legal, and clean-install gates are signed off.

The audit reads setting state and secret names only. It never reads secret values. Repository settings are not treated as complete until its output is attached to the candidate evidence.
