# Signed multitouch compatibility manifest

Status: design gate for broad distribution; not enabled in the manually updated `0.1.7` beta.

## Purpose

The raw trackpad provider relies on an undocumented macOS framework. A signed compatibility manifest lets KeyFlow disable only that provider after an incompatible macOS update while keyboard shortcuts, the menu-bar UI, and configuration remain usable.

## Trust and transport

- Fetch only through HTTPS from a release-owner-controlled host.
- Verify the response with an Ed25519 public key embedded in the signed app bundle. TLS is not the trust root.
- Sign canonical UTF-8 JSON with sorted keys and no insignificant whitespace.
- Store the private signing key outside the repository in release-owner-controlled secret storage.
- Reject unknown schema versions, invalid signatures, expired manifests, future-issued manifests beyond a small clock tolerance, and version rollback.
- Retain the last valid unexpired manifest atomically. Never replace it with an invalid response.

## Version 1 payload

```json
{
  "schema": 1,
  "sequence": 1,
  "issuedAt": "2026-07-16T00:00:00Z",
  "expiresAt": "2026-07-23T00:00:00Z",
  "minimumAppVersion": "0.1.7",
  "blockedOSBuildPrefixes": ["example-only"],
  "disableAllRawMultitouch": false,
  "reason": "Compatibility validation in progress"
}
```

The detached signature and key identifier are transported alongside the payload. The app applies the union of its bundled deny list and a valid manifest; a remote manifest can only make raw multitouch more restrictive, never enable a build blocked locally.

## Runtime behavior

- Read the cached, already-verified decision during startup; never block input startup on the network.
- Refresh outside the gesture, audio, screenshot, and switcher hot paths with exponential backoff and jitter.
- On disable, stop the raw provider, cancel its active gesture, report the signed reason, and leave keyboard input running.
- If no valid cached manifest exists, use the bundled policy and continue to label raw multitouch experimental.
- Do not send hardware identifiers, gestures, configuration, window metadata, or permission state in the request.

## Qualification gate

Before enabling the client, tests must cover valid signatures, tampering, expiration, rollback, offline startup, cache corruption, key rotation, an active-gesture disable, and server unavailability. The privacy policy must be updated with the host and request metadata, and the physical compatibility matrix must pass.
