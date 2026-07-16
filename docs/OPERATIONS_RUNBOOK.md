# KeyFlow operations runbook

## Roles and release ownership

- **Release owner:** approves scope, legal identity, version/build, signed tag, Developer ID credentials, notarization evidence, release notes, and final go/no-go.
- **Reviewer:** reviews source and evidence independently where team size permits; required for release/security/input-boundary changes.
- **Security owner:** receives private reports, coordinates disclosure, rotates exposed credentials, and decides emergency withdrawal.
- **Compatibility owner:** signs off the physical macOS/CPU/trackpad matrix and raw-provider deny list.

One person may temporarily hold multiple release roles, but broad production
distribution should separate author, reviewer, and release approver.

## Diagnostics and privacy

Diagnostics are generated only after the user chooses Export Diagnostics and selects a destination. KeyFlow itself does not upload them. The report contains app/OS/architecture/schema versions, aggregate mapping counts, provider state, and permission state. It excludes mapping names, triggers, action values, typed text, contact geometry, screenshots, and window metadata.

Support must request the minimum report needed, use access-controlled storage, restrict access to assigned support/security staff, and delete it when the issue closes or within 30 days, whichever comes first, unless the user requests earlier deletion or legal requirements apply. Never copy user reports into public issues or test fixtures.

## Incident response

1. Triage severity and stop publishing.
2. For stuck/suppressed input, direct the user to Pause All Mappings or quit KeyFlow; raw-provider failures must remain fail-open.
3. For a private-framework regression, add the OS build to the bundled deny
   list, test keyboard fallback, and issue a signed replacement release. After
   remote compatibility manifests are qualified, publish a signed disable
   decision as well.
4. For credential exposure, revoke/rotate the certificate, API key, token, or update key; remove the secret from history only through an owner-reviewed incident procedure; rescan full history.
5. For privacy/security impact, preserve minimal evidence, notify the security owner, assess affected versions, coordinate disclosure, and document corrective tests.
6. Record timeline, affected builds, decision owner, user guidance, and follow-up actions without including private input data.

## Rollback and withdrawal

- Retain the previous signed/notarized artifact, notarization evidence, checksums, source commit, and signed tag.
- Prefer a forward-fixed build with a higher build number. Do not instruct users to install a build that cannot read their current schema.
- If no safe forward fix exists, withdraw the release, mark it unavailable, publish a concise advisory, and keep keyboard-only recovery instructions accessible.
- Never reuse or move a published tag. Every replacement artifact has a new build number and immutable checksums.
- Automatic rollback remains unsupported while the release channel is manual.

## Evidence retention

For each candidate retain the CI URL, commit/tag verification, test/coverage/sanitizer results, hardware matrix, accepted notarization JSON, stapler/Gatekeeper output, artifact checksums, dependency/secret scan output, release notes, and the signed go/no-go record. Never retain release secrets in the evidence bundle.
