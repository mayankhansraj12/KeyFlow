# Security policy

KeyFlow processes global input and therefore treats input capture, event synthesis, configuration parsing, and release signing as security-sensitive boundaries.

Do not include typed text, action values, configuration files, signing material, or other private data in public reports. Until a hosted private-reporting channel is configured, prepare a minimal reproduction and contact the repository owner privately before publishing a vulnerability.

Release credentials belong only in the macOS keychain or protected CI secrets. Files matching `.p8`, `.p12`, `.cer`, `.env`, and `.local-signing` are intentionally ignored, but ignore rules are not a substitute for secret scanning and review.

The raw multitouch provider uses an undocumented Apple framework. Compatibility failures and crashes in that boundary should be treated as security and reliability issues even when no data disclosure is evident.
