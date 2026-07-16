# Changelog

All notable user-facing and production changes are recorded here.

## 0.1.7 — 2026-07-16

### Added

- App-launch keyboard shortcuts with a native application chooser.
- Dedicated gesture feature menus and an independently configured interactive window switcher.
- Customizable Sound Bar with percentage alignment and custom hue selection.
- Optional Dock visibility with controlled relaunch behavior.
- Production metadata, license packaging, coverage floors, sanitizer CI, and universal CI packaging.

### Improved

- Multi-axis window-switcher navigation, live-window filtering, thumbnail caching, and overlay layout.
- Continuous volume response and lower-overhead gesture, media, screenshot, and switcher paths.
- Configuration migration durability, corrupt-primary repair, rolling backups, and owner-only storage permissions.
- Permission status refresh, singleton main-window presentation, documentation, and release automation.

### Distribution status

- Published KeyFlow as open source under the MIT License.
- Published the universal `KeyFlow-0.1.7.dmg` through GitHub Releases.
- The free DMG is not Apple-notarized; Developer ID signing, notarization, and
  the remaining physical multitouch gates are documented in
  `docs/RELEASE_CHECKLIST.md`.
