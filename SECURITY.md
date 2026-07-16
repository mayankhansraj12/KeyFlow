# Security policy

KeyFlow processes global input and therefore treats input capture, event synthesis, configuration parsing, and release signing as security-sensitive boundaries.

## Supported versions

Only the newest published KeyFlow release receives security fixes. Development builds and older releases are unsupported.

## Reporting a vulnerability

Do not include action values, configuration files, signing material, screenshots, or other private data in public reports. Use the repository's private security-advisory channel when it is available. Until that channel is configured, prepare a minimal reproduction and contact the repository owner privately before publishing a vulnerability. Do not open a public issue containing sensitive reproduction material.

## Security boundaries

Release credentials belong only in the macOS keychain or protected CI secrets. Files matching `.p8`, `.p12`, `.cer`, `.env`, and `.local-signing` are intentionally ignored, but ignore rules are not a substitute for secret scanning and review.

The raw multitouch provider uses an undocumented Apple framework. Compatibility failures and crashes in that boundary should be treated as security and reliability issues even when no data disclosure is evident.
