import Foundation

public enum ConfigurationMigrationError: LocalizedError, Equatable, Sendable {
    case invalidSchema(Int)
    case unsupportedSchema(Int)

    public var errorDescription: String? {
        switch self {
        case let .invalidSchema(version):
            "Configuration schema \(version) is invalid."
        case let .unsupportedSchema(version):
            "Configuration schema \(version) is newer than this version of KeyFlow supports."
        }
    }
}

public enum ConfigurationMigrator {
    private struct SchemaEnvelope: Decodable {
        let schemaVersion: Int
    }

    public static func decode(_ data: Data, using decoder: JSONDecoder) throws -> KeyFlowConfiguration {
        let envelope = try decoder.decode(SchemaEnvelope.self, from: data)
        guard envelope.schemaVersion > 0 else {
            throw ConfigurationMigrationError.invalidSchema(envelope.schemaVersion)
        }
        guard envelope.schemaVersion <= KeyFlowConfiguration.currentSchemaVersion else {
            throw ConfigurationMigrationError.unsupportedSchema(envelope.schemaVersion)
        }

        var configuration = try decoder.decode(KeyFlowConfiguration.self, from: data)
        while configuration.schemaVersion < KeyFlowConfiguration.currentSchemaVersion {
            configuration = migrateOneVersion(configuration)
        }
        configuration.windowSwitcherPreferences.navigationSpeed = min(
            max(configuration.windowSwitcherPreferences.navigationSpeed, 0.25),
            2.5
        )
        return configuration
    }

    private static func migrateOneVersion(_ configuration: KeyFlowConfiguration) -> KeyFlowConfiguration {
        var migrated = configuration
        switch configuration.schemaVersion {
        case 1:
            // Schema 2 establishes the migration and recovery pipeline. Its
            // stored mapping representation remains backward compatible.
            migrated.schemaVersion = 2
        case 2:
            // Schema 3 persists window-switcher appearance preferences. The
            // decoder supplies production defaults when the field is absent.
            migrated.schemaVersion = 3
        case 3:
            // Schema 4 replaces free-form gesture mappings with fixed feature
            // settings. Preserve legacy mappings for recovery, but migrate the
            // compatible enabled features into the new runtime configuration.
            var settings = GestureSettings.default
            let enabledMappings = migrated.mappings.filter(\.isEnabled)
            if enabledMappings.contains(where: {
                $0.trigger.kind == .fourFingerSwipeUp && $0.action.kind == .volumeUp
            })
                || enabledMappings.contains(where: {
                    $0.trigger.kind == .fourFingerSwipeDown && $0.action.kind == .volumeDown
                })
            {
                settings.volumeAdjustment.isEnabled = true
                settings.volumeAdjustment.trigger = .fourFinger
            }
            if enabledMappings.contains(where: {
                $0.trigger.kind == .fourFingerHorizontalSwipe && $0.action.kind == .windowSwitcher
            }) {
                settings.interactiveWindowSwitcherEnabled = true
            }
            migrated.gestureSettings = settings
            migrated.schemaVersion = 4
        case 4:
            // Schema 5 removes three-finger vertical volume control and adds
            // the fixed Mute / Unmute gesture feature. The decoder supplies
            // the new feature's disabled default for existing configurations.
            if migrated.gestureSettings.volumeAdjustment.trigger == .threeFinger {
                migrated.gestureSettings.volumeAdjustment.trigger = .fourFinger
            }
            migrated.schemaVersion = 5
        case 5:
            // Schema 6 adds shared screenshot storage preferences. The
            // backward-compatible decoder supplies macOS Default.
            migrated.schemaVersion = 6
        case 6:
            // Schema 7 makes file saving additive: screenshots always preserve
            // the macOS target and also save to the default or custom folder.
            migrated.schemaVersion = 7
        case 7:
            // Schema 8 makes the additional PNG copy optional. Preserve the
            // always-on behavior of existing Schema 7 configurations.
            migrated.gestureSettings.screenshotStorage.saveAdditionalCopy = true
            migrated.schemaVersion = 8
        case 8:
            // Schema 9 adds switcher navigation-speed and window-source
            // preferences. The backward-compatible decoder supplies Standard
            // speed and All Active Windows when either field is absent.
            migrated.windowSwitcherPreferences.navigationSpeed = 0.5
            migrated.schemaVersion = 9
        case 9:
            // Schema 10 replaces the three discrete switcher speeds with a
            // continuous zero-to-one scale. The decoder maps the legacy
            // Controlled, Standard, and Fast values to 0, 0.5, and 1.
            migrated.schemaVersion = 10
        case 10:
            // Schema 11 expresses switcher response as a 0.25x-to-2.5x
            // multiplier. Preserve the old scale's controlled, midpoint, and
            // fast anchors as 0.25x, 1x, and 2.5x.
            let legacySpeed = min(max(migrated.windowSwitcherPreferences.navigationSpeed, 0), 1)
            if legacySpeed <= 0.5 {
                migrated.windowSwitcherPreferences.navigationSpeed = 0.25 + legacySpeed * 1.5
            } else {
                migrated.windowSwitcherPreferences.navigationSpeed = 1 + (legacySpeed - 0.5) * 3
            }
            migrated.schemaVersion = 11
        case 11:
            // Schema 12 persists volume gesture speed, response threshold, and
            // percentage-per-step preferences. Backward-compatible decoding supplies
            // the tuned production defaults for existing configurations.
            migrated.schemaVersion = 12
        case 12:
            // Schema 13 adds one shared appearance profile for KeyFlow-owned
            // runtime overlays. Preserve the existing switcher accent while
            // decoding supplies defaults for the newly introduced controls.
            migrated.overlayAppearance.accent = migrated.windowSwitcherPreferences.accent
            migrated.schemaVersion = 13
        case 13:
            // Schema 14 gives each runtime interface its own appearance. Carry
            // the short-lived shared profile into both destinations once.
            migrated.windowSwitcherPreferences.appearance = migrated.overlayAppearance
            migrated.gestureSettings.volumePreferences.hudAppearance = migrated.overlayAppearance
            migrated.overlayAppearance = .default
            migrated.schemaVersion = 14
        case 14:
            // Schema 15 adds an optional custom progress hue. Existing preset
            // accents remain unchanged when no custom color is stored.
            migrated.schemaVersion = 15
        case 15:
            // Schema 16 persists whether KeyFlow runs as a Dock application or
            // as a menu-bar utility. Existing installations remain visible.
            migrated.schemaVersion = 16
        case 16:
            // Schema 17 narrows keyboard shortcuts to application launching.
            // Legacy actions remain recoverable but fail closed until the user
            // chooses an application in the new shortcut editor.
            migrated.schemaVersion = 17
        case 17:
            // Schema 18 persists Sound Bar percentage alignment. Existing
            // installations retain the established left-aligned presentation.
            migrated.gestureSettings.volumePreferences.percentageAlignment = .left
            migrated.schemaVersion = 18
        case 18:
            // Schema 19 persists the menu-bar template icon. Existing
            // installations adopt the KeyFlow touch mark by default.
            migrated.applicationPreferences.menuBarIconStyle = .touch
            migrated.schemaVersion = 19
        default:
            break
        }
        return migrated
    }
}
