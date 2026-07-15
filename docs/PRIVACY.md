# Privacy

KeyFlow operates locally on the Mac. It does not contain analytics, advertising, telemetry, or network-based account services.

## Data stored locally

- Mappings are stored in `~/Library/Application Support/KeyFlow/configuration.json`.
- Up to ten prior configuration revisions are stored under the adjacent `Backups` directory for recovery.
- The Activity view keeps at most 100 execution results in memory and does not persist them.
- macOS Unified Logging receives lifecycle and error diagnostics. Action values, typed text, mapping names, and shortcut contents are not intentionally logged.

## Permissions

- Accessibility is used to suppress configured shortcuts and post synthetic keyboard events.
- Input Monitoring is used to observe configured global keyboard and gesture input.
- Screen Recording is optional and is used only to render window thumbnails in the interactive switcher. Without it, the switcher uses window titles and application icons.

KeyFlow's diagnostics export includes versions, aggregate mapping counts, runtime state, and permission state. It deliberately excludes mapping names, triggers, action values, and typed text.

The raw multi-finger compatibility provider reads trackpad contact geometry locally. It does not record contacts to disk or transmit them. Window thumbnails are never written to disk or transmitted. They are held in a bounded 32 MB in-memory cache, removed when their source window leaves the current catalog, and expire after at most 120 seconds without access.

The app bundle declares why Screen Recording is requested through `NSScreenCaptureUsageDescription`. The bundled privacy manifest declares no tracking, tracking domains, or collected-data categories because KeyFlow has no analytics or network telemetry.
