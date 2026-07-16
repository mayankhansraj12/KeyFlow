## Summary

Describe the user-visible outcome and the reason for the change.

## Risk review

- [ ] Input interception/suppression behavior is unchanged or explicitly tested.
- [ ] No typed text, action values, mapping names, screenshots, secrets, or window content are logged.
- [ ] Platform effects are behind an injectable boundary.
- [ ] Persistence/schema changes include migration and recovery coverage.
- [ ] Private macOS API changes fail open and update compatibility documentation.
- [ ] Release, signing, permission, privacy, and third-party metadata are updated when applicable.

## Verification

- [ ] `./Scripts/validate.sh`
- [ ] `./Scripts/coverage.sh`
- [ ] AddressSanitizer and ThreadSanitizer (CI or local)
- [ ] Universal/package qualification when packaging is affected
- [ ] Relevant physical-device or clean-account checks are recorded

## Release impact

State whether this changes the manual-beta contract, raw multitouch compatibility, required permissions, configuration schema, or release notes.
