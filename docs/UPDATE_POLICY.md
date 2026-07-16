# Update and release-channel policy

## Current candidate

KeyFlow `0.1.7` is a **manually updated beta**. It contains no update client, makes no update-feed request, and does not claim silent or automatic security updates. The bundled `ReleasePolicy.plist` is the machine-readable source of this contract; packaging and audit scripts reject an artifact that contradicts it.

Users update this beta by obtaining a newer signed and notarized KeyFlow release from the release owner, quitting KeyFlow, and replacing the application bundle. A newer build must retain the `app.keyflow.desktop` bundle identifier and configuration schema migration path. Downgrades are unsupported because a prior build may not understand a newer configuration schema.

## Broad-release architecture

Before KeyFlow can be called a broadly distributed production release, use Sparkle 2 or an equivalently maintained macOS updater with all of the following controls:

- Pin and review an exact updater dependency; include its license and packaged runtime components.
- Embed only the public EdDSA verification key. Store the private update-signing key outside the repository in protected release infrastructure.
- Serve stable and beta appcasts through HTTPS, with every downloadable item signed independently of TLS.
- Permit stable clients to consume only stable releases; beta clients may consume beta or stable releases according to an explicit channel rule.
- Require monotonically increasing build numbers and reject downgrade, replay, invalid signature, malformed feed, and bundle-identity changes.
- Preserve configuration, TCC identity, login-item state, and the previous known-good artifact.
- Keep update checks outside input/audio/screenshot/switcher hot paths and disclose request metadata in the privacy policy.
- Add a visible manual “Check for Updates” command, an opt-in automatic-check setting, last-check state, and actionable failure text.

## Required qualification

The update signing key, HTTPS feed, and prior notarized artifact are release-owner inputs. Once available, the release gate must prove:

1. no-update and offline behavior;
2. a signed upgrade from the previous public build;
3. rejection of tampered, unsigned, expired, replayed, and lower-build items;
4. interrupted-download recovery and checksum/signature failure;
5. channel isolation and staged-rollout behavior;
6. configuration migration and backup recovery;
7. unchanged bundle identity, TCC registrations, and login item;
8. recovery using the retained previous artifact.

Until that evidence exists, `ReleasePolicy.plist` must remain `manual-beta` with automatic updates disabled.
