# Changelog

All notable user-facing and production changes are recorded here.

## Unreleased — 0.1.7 (build 8) candidate

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

- Prepared KeyFlow for open-source publication under the MIT License.
- The source and locally signed universal application are validated.
- Official binaries still require Developer ID signing, notarization,
  clean-install qualification, and the physical multitouch gates documented in
  `docs/RELEASE_CHECKLIST.md`.
