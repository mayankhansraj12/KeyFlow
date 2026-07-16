# Feature guide

KeyFlow `0.1.7` focuses on a polished set of keyboard, audio, screenshot, and
window-switching workflows. The project intentionally keeps unsupported
BetterTouchTool-scale features out of the editor until their runtime and safety
models are implemented.

## Keyboard shortcuts

Keyboard mappings record a global chord using Command, Option, Control, Shift,
and Fn modifiers. Each mapping opens one user-selected application and can
optionally suppress the original shortcut.

Current keyboard mappings do not support scripts, typed-text actions,
multi-step action graphs, key sequences, tap/hold behavior, or app-specific
contexts.

## Audio and media gestures

### Volume Adjustment

Use a four- or five-finger vertical gesture to change system output volume
continuously.

Configuration includes:

- response time from immediate through 500 ms;
- volume step of 1%, 2%, or 5%;
- movement speed;
- a separately configured Sound Bar with theme, surface, background, progress
  color, opacity, corner radius, border, and percentage alignment.

### Mute / Unmute

Assign an available three-, four-, or five-finger tap or physical click.

### Play / Pause

Assign an available three-, four-, or five-finger tap or physical click to
control the active media application.

## Screenshots

### Screenshot

Captures the complete screen through the native macOS screenshot behavior.

### Custom Screenshot

Opens the native macOS capture interface for selecting a region or window.

Both actions preserve the destination configured by macOS. KeyFlow can
optionally save an additional PNG copy to its default screenshots folder or a
custom folder.

## Interactive window switcher

A four-finger horizontal gesture opens a persistent overlay. While the gesture
remains active, movement can navigate left, right, up, down, or diagonally
through the adaptive grid. Releasing activates the selected window.

Configuration includes:

- compact, balanced, and large card sizes;
- movement speed from 0.25× to 2.5×;
- standard applications or the broader eligible-open-app catalog;
- preview presentation and application/window labels;
- selection color and overlay appearance.

Screen Recording is optional. When granted, previews are captured on demand
and kept in a bounded in-memory cache. Without it, the switcher remains usable
with icons and titles.

System surfaces such as Dock, Control Center, and temporary volume HUD windows
are excluded.

## Menu bar and runtime controls

The menu-bar item can:

- open the existing KeyFlow window;
- pause or resume all mappings;
- reflect a selected touch/pointer-themed icon;
- keep KeyFlow available when its Dock icon is hidden.

## Persistence and diagnostics

- Configuration uses migratable JSON with atomic writes.
- Up to ten rolling backups support corruption recovery.
- Activity is bounded and held in memory.
- Diagnostics exports omit typed text, mapping names, triggers, action values,
  screenshots, and window content.

## Experimental capability

Raw multi-finger recognition relies on an undocumented macOS framework behind
an isolated compatibility bridge. It can be unavailable after a macOS update
and must never prevent keyboard shortcuts or normal pointer input from working.

Read [Multitouch compatibility](MULTITOUCH_COMPATIBILITY.md) for the exact
support policy.
