# Getting started with KeyFlow

## Requirements

- macOS 15 or later
- A built-in trackpad or Magic Trackpad for gesture features

Keyboard shortcuts do not require a trackpad. Window previews require the
optional Screen Recording permission.

## Install from a DMG

Official DMGs will appear on
[GitHub Releases](https://github.com/mayankhansraj12/KeyFlow/releases). Until
the first release is published, follow the
[source-build instructions](../README.md#build-from-source) to produce
`KeyFlow.app` or the drag-to-Applications DMG.

When a DMG is available:

1. Download it from GitHub Releases.
2. Open the DMG.
3. Drag **KeyFlow** into **Applications**.
4. Eject the KeyFlow installer.
5. Open KeyFlow from Applications.

The current community build may not be Apple-notarized. If macOS blocks the
first launch, Control-click KeyFlow, choose **Open**, and confirm. You can also
use **System Settings → Privacy & Security → Open Anyway**.

## Grant permissions

Open KeyFlow's **Permissions** tab.

### Accessibility

Accessibility lets KeyFlow suppress configured shortcuts, post synthetic
keyboard events, and raise a window selected through the switcher.

Choose **Request Access**, enable KeyFlow in System Settings, then return to
KeyFlow and refresh the permission status.

### Input Monitoring

Input Monitoring lets KeyFlow observe enabled global keyboard shortcuts and
trackpad gestures.

Choose **Request Access**, enable the exact KeyFlow application installed in
Applications, and relaunch if macOS asks you to.

### Screen Recording

Screen Recording is optional. It adds live window thumbnails to the interactive
switcher. Without it, KeyFlow continues to show application icons and window
titles.

## Create an app shortcut

1. Open **Shortcuts**.
2. Choose the add button.
3. Record a keyboard chord.
4. Select the application to open.
5. Enable the shortcut and test it outside KeyFlow.

Shortcut names are derived from the selected application so the list remains
consistent.

## Configure gestures

Open **Gestures** and enable only the features you want. Each discrete trigger
can belong to one feature at a time; unavailable triggers identify the feature
already using them.

- Volume Adjustment uses a continuous four- or five-finger vertical gesture.
- Mute / Unmute and Play / Pause use a multi-finger tap or physical click.
- Screenshot and Custom Screenshot use a multi-finger tap or physical click.

The interactive four-finger window switcher is enabled and customized
separately in **Switcher**.

## Safety and recovery

- Use the menu-bar item to pause all mappings.
- If a shortcut behaves unexpectedly, pause KeyFlow before editing it.
- If a permission appears enabled in System Settings but disabled in KeyFlow,
  remove the stale KeyFlow entry, add the copy in Applications again, relaunch,
  and refresh.
- Configuration backups are stored beside the active configuration under
  `~/Library/Application Support/KeyFlow`.

For unresolved problems, read [Support](SUPPORT.md) before opening an issue.
