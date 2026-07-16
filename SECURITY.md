# Security policy

KeyFlow processes global input and interacts with macOS Accessibility,
ScreenCaptureKit, and event-synthesis APIs. Input capture, configuration
parsing, native compatibility bridges, diagnostics, and release signing are
treated as security-sensitive boundaries.

## Supported versions

| Version | Security updates |
|---|---|
| Current `main` branch and latest published beta | Supported on a best-effort basis |
| Older commits, unofficial binaries, and forks | Not supported |

No official KeyFlow binary has been published yet. Until the first GitHub
Release is available, security fixes target the current `main` branch.

## Report a vulnerability

Please use
[GitHub private vulnerability reporting](https://github.com/mayankhansraj12/KeyFlow/security/advisories/new).

Do not include sensitive reproduction material in a public issue. In
particular, do not publish configuration files, typed text, action values,
window screenshots, diagnostic exports containing private context, or signing
material.

Include only what is needed to reproduce the issue:

- affected KeyFlow and macOS versions;
- impact and prerequisites;
- minimal reproduction steps;
- whether the problem affects input suppression, event synthesis, permissions,
  configuration, diagnostics, or a native bridge.

The maintainers will acknowledge the report, assess affected versions, and
coordinate remediation and disclosure through the private advisory.

## Security boundaries

- KeyFlow does not intentionally log typed text, action values, mapping names,
  trackpad contact geometry, screenshots, or window content.
- Release credentials belong only in the macOS keychain or protected CI
  secrets.
- Raw multitouch uses an isolated compatibility bridge around an undocumented
  Apple framework and must fail open when unavailable.
- Generated signing identities, credentials, build products, diagnostics, and
  local automation state are excluded from version control.

Ignore rules reduce accidental exposure, but contributors must still review
their staged changes and use secret scanning.
