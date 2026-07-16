# KeyFlow 0.1.7

## Highlights

- Global keyboard shortcuts that open a selected application.
- A rebuilt Shortcuts editor with stable selection, compact application rows, clear empty states, and safe recorder cleanup.
- Fixed 3/4/5-finger tap/click actions for mute, Play/Pause, and native screenshots.
- Continuous 4/5-finger volume adjustment with response, step, speed, and independent Sound Bar appearance controls.
- Four-finger interactive two-axis window switching with adaptive five-column layout and optional live thumbnails.
- Permission diagnostics, a focused family of touch/pointer menu-bar icons, menu-bar pause/open controls, Dock visibility, launch at login, activity history, and privacy-redacted diagnostic export.
- Atomic configuration persistence, schema migration, rolling recovery backups, bounded thumbnail retention, event-driven screenshot copying, and performance budgets.

## Installation and updates

KeyFlow 0.1.7 is an open-source, manually updated release for macOS 15 or
later. Automatic updates are not enabled. The downloadable DMG is ad-hoc
signed and is not Apple-notarized, so macOS may require Control-clicking
KeyFlow and choosing **Open**, or approval under **System Settings → Privacy &
Security**.

## Known limitations

- Raw multitouch uses an undocumented Apple framework and remains experimental pending the physical macOS/CPU/trackpad matrix.
- Window thumbnails require optional Screen Recording permission; the switcher falls back to app icons and titles.
- Some macOS permission changes require relaunching the exact packaged app bundle.
- Intel execution, sleep/wake, fast-user-switching, clean-account TCC, and cross-version upgrade qualification remain release-owner test gates.
- No automatic updater, Mac App Store build, scripts, import/export, mouse remapping, or app-specific action graphs are included.

See [Support](SUPPORT.md), [Privacy](PRIVACY.md),
[Security](../SECURITY.md), and the
[production audit report](PRODUCTION_AUDIT_REPORT.md) for more detail.
