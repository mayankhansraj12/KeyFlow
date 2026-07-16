## Summary

Describe the user-visible outcome and the reason for the change.

## Screenshots or recordings

Include them for visible UI changes. Remove private window content and personal
information first. Write “Not applicable” when the change has no visual impact.

## Verification

List the checks you ran and any hardware or permissions involved.

- [ ] `./Scripts/validate.sh`
- [ ] Relevant tests were added or updated.
- [ ] Documentation was updated when user behavior changed.

## Safety and privacy

- [ ] Input interception/suppression behavior is unchanged or explicitly tested.
- [ ] No typed text, action values, mapping names, screenshots, secrets, or window content are logged.
- [ ] Platform effects are behind an injectable boundary.
- [ ] Persistence/schema changes include migration and recovery coverage.
- [ ] Private macOS API changes fail open and update compatibility documentation.
- [ ] Release, signing, permission, privacy, and third-party metadata are updated when applicable.

## Maintainer notes

State whether this changes the manual-beta contract, raw multitouch compatibility, required permissions, configuration schema, or release notes.
