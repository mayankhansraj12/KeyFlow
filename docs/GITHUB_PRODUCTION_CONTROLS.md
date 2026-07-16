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
   conversations, include administrators, and forbid force-push/deletion on
   both branches. Keep linear history required on `dev`. Permit merge commits
   on `main` so each production promotion preserves the exact integrated
   `dev` history.
   While the repository has only one push-capable maintainer, the approval
   count remains zero so changes are not made impossible to merge. As soon as
   a second maintainer is added, require at least one approving CODEOWNER
   review.
2. Require `Validate promotion source` on `main`. The metadata-only workflow
   permits only a pull request from the `dev` branch in this repository; a
   similarly named branch in a fork is rejected. `dev` accepts pull requests
   from contributor branches and forks after the normal CI gate passes.
3. Use one-way promotion: short-lived branches to `dev`, then `dev` to `main`.
   Squash or rebase focused changes into `dev` and merge the release pull
   request into `main` with a merge commit. Do not create routine
   `main`-to-`dev` synchronization pull requests. A merge commit can make GitHub
   report `dev` as one commit behind `main`; that release metadata does not
   indicate missing source changes.
4. Keep automatic head-branch deletion enabled for short-lived feature
   branches. Protection on `dev` prevents deletion after a production
   promotion.
5. Create a protected `production` environment. Add a reviewer who is
   independent of the release initiator when the team permits it, restrict
   deployment to protected branches, and add only the secret names listed by
   the audit script.
6. Enable private vulnerability reporting, secret scanning, and push protection.
7. Keep Dependabot alerts and security updates enabled. Target dependency pull
   requests at `dev`, review them through normal CI, and do not auto-merge
   release/signing dependencies.
8. Require signed commits/tags for release policy. The release script independently verifies the signed version tag and exact pushed commit.
9. Do not allow the release workflow to publish until Developer ID/notarization, physical compatibility, privacy/support/legal, and clean-install gates are signed off.

The audit reads setting state and secret names only. It never reads secret values. Repository settings are not treated as complete until its output is attached to the candidate evidence.
