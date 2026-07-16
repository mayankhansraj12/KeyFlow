import Foundation

public struct ModifierKeys: OptionSet, Codable, Hashable, Sendable {
    public let rawValue: Int

    public init(rawValue: Int) {
        self.rawValue = rawValue
    }

    public static let command = ModifierKeys(rawValue: 1 << 0)
    public static let option = ModifierKeys(rawValue: 1 << 1)
    public static let control = ModifierKeys(rawValue: 1 << 2)
    public static let shift = ModifierKeys(rawValue: 1 << 3)
    public static let function = ModifierKeys(rawValue: 1 << 4)

    public static let supportedMask: ModifierKeys = [.command, .option, .control, .shift, .function]

    public var displayName: String {
        var result = ""
        if contains(.control) { result += "⌃" }
        if contains(.option) { result += "⌥" }
        if contains(.shift) { result += "⇧" }
        if contains(.command) { result += "⌘" }
        if contains(.function) { result += "fn " }
        return result
    }
}

public enum TriggerKind: String, Codable, CaseIterable, Identifiable, Sendable {
    case keyboard
    case swipeLeft
    case swipeRight
    case swipeUp
    case swipeDown
    case pinchIn
    case pinchOut
    case rotateLeft
    case rotateRight
    case threeFingerSwipeUp
    case threeFingerSwipeDown
    case fourFingerSwipeUp
    case fourFingerSwipeDown
    case fiveFingerSwipeUp
    case fiveFingerSwipeDown
    case fourFingerHorizontalSwipe
    case threeFingerTap
    case fourFingerTap
    case fiveFingerTap
    case threeFingerClick
    case fourFingerClick
    case fiveFingerClick

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .keyboard: "Keyboard Shortcut"
        case .swipeLeft: "Trackpad Swipe Left"
        case .swipeRight: "Trackpad Swipe Right"
        case .swipeUp: "Trackpad Swipe Up"
        case .swipeDown: "Trackpad Swipe Down"
        case .pinchIn: "Trackpad Pinch In"
        case .pinchOut: "Trackpad Pinch Out"
        case .rotateLeft: "Trackpad Rotate Left"
        case .rotateRight: "Trackpad Rotate Right"
        case .threeFingerSwipeUp: "Three-Finger Swipe Up"
        case .threeFingerSwipeDown: "Three-Finger Swipe Down"
        case .fourFingerSwipeUp: "Four-Finger Swipe Up"
        case .fourFingerSwipeDown: "Four-Finger Swipe Down"
        case .fiveFingerSwipeUp: "Five-Finger Swipe Up"
        case .fiveFingerSwipeDown: "Five-Finger Swipe Down"
        case .fourFingerHorizontalSwipe: "Four-Finger Horizontal Swipe"
        case .threeFingerTap: "Three-Finger Tap"
        case .fourFingerTap: "Four-Finger Tap"
        case .fiveFingerTap: "Five-Finger Tap"
        case .threeFingerClick: "Three-Finger Click"
        case .fourFingerClick: "Four-Finger Click"
        case .fiveFingerClick: "Five-Finger Click"
        }
    }

    public var isLegacyTrackpadGesture: Bool {
        switch self {
        case .swipeLeft, .swipeRight, .swipeUp, .swipeDown, .pinchIn, .pinchOut, .rotateLeft, .rotateRight: true
        default: false
        }
    }

    public var fingerCount: Int? {
        switch self {
        case .threeFingerSwipeUp, .threeFingerSwipeDown, .threeFingerTap, .threeFingerClick: 3
        case .fourFingerSwipeUp, .fourFingerSwipeDown, .fourFingerHorizontalSwipe, .fourFingerTap,
            .fourFingerClick:
            4
        case .fiveFingerSwipeUp, .fiveFingerSwipeDown, .fiveFingerTap, .fiveFingerClick: 5
        default: nil
        }
    }

    public var isClickGesture: Bool {
        switch self {
        case .threeFingerClick, .fourFingerClick, .fiveFingerClick: true
        default: false
        }
    }
}

public struct TriggerDefinition: Codable, Hashable, Sendable {
    public var kind: TriggerKind
    public var keyCode: UInt16?
    public var modifiers: ModifierKeys

    public init(kind: TriggerKind, keyCode: UInt16? = nil, modifiers: ModifierKeys = []) {
        self.kind = kind
        self.keyCode = keyCode
        self.modifiers = modifiers
    }

    public static let defaultKeyboard = TriggerDefinition(
        kind: .keyboard,
        keyCode: 40,
        modifiers: [.command, .option]
    )

    public var displayName: String {
        guard kind == .keyboard else { return kind.displayName }
        guard let keyCode else { return "Record a shortcut" }
        return modifiers.displayName + KeyCodeNames.name(for: keyCode)
    }
}

public enum ActionKind: String, Codable, CaseIterable, Identifiable, Sendable {
    case openURL
    case launchApplication
    case typeText
    case volumeUp
    case volumeDown
    case toggleMute
    case playPause
    case captureScreenshot
    case captureSelectionScreenshot
    case windowSwitcher

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .openURL: "Open URL"
        case .launchApplication: "Launch Application"
        case .typeText: "Type Text"
        case .volumeUp: "Volume Up"
        case .volumeDown: "Volume Down"
        case .toggleMute: "Mute / Unmute"
        case .playPause: "Play / Pause"
        case .captureScreenshot: "Screenshot"
        case .captureSelectionScreenshot: "Custom Screenshot"
        case .windowSwitcher: "Interactive Window Switcher"
        }
    }

    public var valueLabel: String {
        switch self {
        case .openURL: "URL"
        case .launchApplication: "Bundle identifier or application path"
        case .typeText: "Text"
        case .volumeUp, .volumeDown, .toggleMute, .playPause, .captureScreenshot,
            .captureSelectionScreenshot, .windowSwitcher:
            "No configuration required"
        }
    }

    public var example: String {
        switch self {
        case .openURL: "https://example.com"
        case .launchApplication: "com.apple.Safari"
        case .typeText: "Text to type"
        case .volumeUp, .volumeDown, .toggleMute, .playPause, .captureScreenshot,
            .captureSelectionScreenshot, .windowSwitcher:
            ""
        }
    }

    public var requiresValue: Bool {
        switch self {
        case .openURL, .launchApplication, .typeText: true
        case .volumeUp, .volumeDown, .toggleMute, .playPause, .captureScreenshot,
            .captureSelectionScreenshot, .windowSwitcher:
            false
        }
    }
}

public struct ActionDefinition: Codable, Hashable, Sendable {
    public var kind: ActionKind
    public var value: String

    public init(kind: ActionKind, value: String) {
        self.kind = kind
        self.value = value
    }
}

public struct Mapping: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var name: String
    public var isEnabled: Bool
    public var trigger: TriggerDefinition
    public var action: ActionDefinition
    public var consumesKeyboardInput: Bool
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        name: String,
        isEnabled: Bool = false,
        trigger: TriggerDefinition = .defaultKeyboard,
        action: ActionDefinition = .init(kind: .launchApplication, value: ""),
        consumesKeyboardInput: Bool = true,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.isEnabled = isEnabled
        self.trigger = trigger
        self.action = action
        self.consumesKeyboardInput = consumesKeyboardInput
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    public static func newMapping() -> Mapping {
        Mapping(
            name: "Open Application",
            trigger: .init(kind: .keyboard),
            action: .init(kind: .launchApplication, value: "")
        )
    }
}

public enum WindowSwitcherCardSize: String, Codable, CaseIterable, Identifiable, Sendable {
    case compact
    case balanced
    case large

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .compact: "Compact"
        case .balanced: "Balanced"
        case .large: "Large"
        }
    }
}

public enum WindowSwitcherPreviewStyle: String, Codable, CaseIterable, Identifiable, Sendable {
    case fullWindow
    case edgeToEdge

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .fullWindow: "Full Window"
        case .edgeToEdge: "Fill Card"
        }
    }
}

public enum WindowSwitcherAccent: String, Codable, CaseIterable, Identifiable, Sendable {
    case system
    case blue
    case indigo
    case purple
    case green
    case orange
    case pink

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .system: "System"
        case .blue: "Blue"
        case .indigo: "Indigo"
        case .purple: "Purple"
        case .green: "Green"
        case .orange: "Orange"
        case .pink: "Pink"
        }
    }
}

public enum OverlayTheme: String, Codable, CaseIterable, Identifiable, Sendable {
    case system
    case light
    case dark

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .system: "System"
        case .light: "Light"
        case .dark: "Dark"
        }
    }
}

public enum OverlaySurfaceStyle: String, Codable, CaseIterable, Identifiable, Sendable {
    case frosted
    case solid

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .frosted: "Frosted"
        case .solid: "Solid"
        }
    }
}

public enum OverlayBackgroundColor: String, Codable, CaseIterable, Identifiable, Sendable {
    case system
    case graphite
    case midnight
    case light
    case accent

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .system: "System"
        case .graphite: "Graphite"
        case .midnight: "Midnight"
        case .light: "Light"
        case .accent: "Accent"
        }
    }
}

public struct PersistedRGBAColor: Codable, Equatable, Sendable {
    public var red: Double
    public var green: Double
    public var blue: Double
    public var alpha: Double

    public init(red: Double, green: Double, blue: Double, alpha: Double = 1) {
        self.red = min(max(red, 0), 1)
        self.green = min(max(green, 0), 1)
        self.blue = min(max(blue, 0), 1)
        self.alpha = min(max(alpha, 0), 1)
    }
}

public struct OverlayAppearancePreferences: Codable, Equatable, Sendable {
    public var theme: OverlayTheme
    public var surfaceStyle: OverlaySurfaceStyle
    public var backgroundColor: OverlayBackgroundColor
    public var accent: WindowSwitcherAccent
    public var customAccentColor: PersistedRGBAColor?
    public var backgroundOpacity: Double
    public var cornerRadius: Double
    public var showsBorder: Bool

    public init(
        theme: OverlayTheme = .system,
        surfaceStyle: OverlaySurfaceStyle = .frosted,
        backgroundColor: OverlayBackgroundColor = .system,
        accent: WindowSwitcherAccent = .system,
        customAccentColor: PersistedRGBAColor? = nil,
        backgroundOpacity: Double = 0.96,
        cornerRadius: Double = 20,
        showsBorder: Bool = true
    ) {
        self.theme = theme
        self.surfaceStyle = surfaceStyle
        self.backgroundColor = backgroundColor
        self.accent = accent
        self.customAccentColor = customAccentColor
        self.backgroundOpacity = min(max(backgroundOpacity, 0.45), 1)
        self.cornerRadius = min(max(cornerRadius, 10), 30)
        self.showsBorder = showsBorder
    }

    public static let `default` = OverlayAppearancePreferences()

    private enum CodingKeys: String, CodingKey {
        case theme
        case surfaceStyle
        case backgroundColor
        case accent
        case customAccentColor
        case backgroundOpacity
        case cornerRadius
        case showsBorder
    }

    public init(from decoder: any Decoder) throws {
        let defaults = Self.default
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            theme: try container.decodeIfPresent(OverlayTheme.self, forKey: .theme) ?? defaults.theme,
            surfaceStyle: try container.decodeIfPresent(OverlaySurfaceStyle.self, forKey: .surfaceStyle)
                ?? defaults.surfaceStyle,
            backgroundColor: try container.decodeIfPresent(OverlayBackgroundColor.self, forKey: .backgroundColor)
                ?? defaults.backgroundColor,
            accent: try container.decodeIfPresent(WindowSwitcherAccent.self, forKey: .accent) ?? defaults.accent,
            customAccentColor: try container.decodeIfPresent(PersistedRGBAColor.self, forKey: .customAccentColor),
            backgroundOpacity: try container.decodeIfPresent(Double.self, forKey: .backgroundOpacity)
                ?? defaults.backgroundOpacity,
            cornerRadius: try container.decodeIfPresent(Double.self, forKey: .cornerRadius)
                ?? defaults.cornerRadius,
            showsBorder: try container.decodeIfPresent(Bool.self, forKey: .showsBorder) ?? defaults.showsBorder
        )
    }
}

public enum WindowSwitcherWindowScope: String, Codable, CaseIterable, Identifiable, Sendable {
    case standardApplications
    case allActiveWindows

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .standardApplications: "Dock App Windows"
        case .allActiveWindows: "All Open Windows"
        }
    }
}

public struct WindowSwitcherPreferences: Codable, Equatable, Sendable {
    public var cardSize: WindowSwitcherCardSize
    public var navigationSpeed: Double
    public var windowScope: WindowSwitcherWindowScope
    public var previewStyle: WindowSwitcherPreviewStyle
    public var accent: WindowSwitcherAccent
    public var showWindowTitles: Bool
    public var showApplicationIcons: Bool
    public var usePreviewBackdrop: Bool
    public var appearance: OverlayAppearancePreferences

    public init(
        cardSize: WindowSwitcherCardSize = .balanced,
        navigationSpeed: Double = 1,
        windowScope: WindowSwitcherWindowScope = .allActiveWindows,
        previewStyle: WindowSwitcherPreviewStyle = .fullWindow,
        accent: WindowSwitcherAccent = .system,
        showWindowTitles: Bool = true,
        showApplicationIcons: Bool = true,
        usePreviewBackdrop: Bool = true,
        appearance: OverlayAppearancePreferences = .default
    ) {
        self.cardSize = cardSize
        self.navigationSpeed = min(max(navigationSpeed, 0.25), 2.5)
        self.windowScope = windowScope
        self.previewStyle = previewStyle
        self.accent = accent
        self.showWindowTitles = showWindowTitles
        self.showApplicationIcons = showApplicationIcons
        self.usePreviewBackdrop = usePreviewBackdrop
        self.appearance = appearance
    }

    public static let `default` = WindowSwitcherPreferences()

    private enum CodingKeys: String, CodingKey {
        case cardSize
        case navigationSpeed
        case windowScope
        case previewStyle
        case accent
        case showWindowTitles
        case showApplicationIcons
        case usePreviewBackdrop
        case appearance
    }

    public init(from decoder: any Decoder) throws {
        let defaults = Self.default
        let container = try decoder.container(keyedBy: CodingKeys.self)
        cardSize = try container.decodeIfPresent(WindowSwitcherCardSize.self, forKey: .cardSize) ?? defaults.cardSize
        if let continuousSpeed = try? container.decode(Double.self, forKey: .navigationSpeed) {
            // Migration needs the original schema-10 zero-to-one value before
            // converting it to the schema-11 multiplier range.
            navigationSpeed = continuousSpeed
        } else if let legacySpeed = try? container.decode(LegacyNavigationSpeed.self, forKey: .navigationSpeed) {
            navigationSpeed = legacySpeed.continuousValue
        } else {
            navigationSpeed = defaults.navigationSpeed
        }
        windowScope =
            try container.decodeIfPresent(WindowSwitcherWindowScope.self, forKey: .windowScope)
            ?? defaults.windowScope
        previewStyle =
            try container.decodeIfPresent(WindowSwitcherPreviewStyle.self, forKey: .previewStyle)
            ?? defaults.previewStyle
        accent = try container.decodeIfPresent(WindowSwitcherAccent.self, forKey: .accent) ?? defaults.accent
        showWindowTitles =
            try container.decodeIfPresent(Bool.self, forKey: .showWindowTitles)
            ?? defaults.showWindowTitles
        showApplicationIcons =
            try container.decodeIfPresent(Bool.self, forKey: .showApplicationIcons)
            ?? defaults.showApplicationIcons
        usePreviewBackdrop =
            try container.decodeIfPresent(Bool.self, forKey: .usePreviewBackdrop)
            ?? defaults.usePreviewBackdrop
        appearance =
            try container.decodeIfPresent(OverlayAppearancePreferences.self, forKey: .appearance)
            ?? defaults.appearance
    }

    private enum LegacyNavigationSpeed: String, Decodable {
        case controlled
        case standard
        case fast

        var continuousValue: Double {
            switch self {
            case .controlled: 0
            case .standard: 0.5
            case .fast: 1
            }
        }
    }
}

public enum VerticalGestureTrigger: String, Codable, CaseIterable, Identifiable, Sendable {
    case threeFinger
    case fourFinger
    case fiveFinger

    public var id: String { rawValue }

    public static let volumeAdjustmentCases: [VerticalGestureTrigger] = [.fourFinger, .fiveFinger]

    public var isAvailableForVolumeAdjustment: Bool { self != .threeFinger }

    public var displayName: String {
        switch self {
        case .threeFinger: "Three-Finger Swipe Up / Down"
        case .fourFinger: "Four-Finger Swipe Up / Down"
        case .fiveFinger: "Five-Finger Swipe Up / Down"
        }
    }

    public var upTrigger: TriggerKind {
        switch self {
        case .threeFinger: .threeFingerSwipeUp
        case .fourFinger: .fourFingerSwipeUp
        case .fiveFinger: .fiveFingerSwipeUp
        }
    }

    public var downTrigger: TriggerKind {
        switch self {
        case .threeFinger: .threeFingerSwipeDown
        case .fourFinger: .fourFingerSwipeDown
        case .fiveFinger: .fiveFingerSwipeDown
        }
    }
}

public enum SoundBarPercentageAlignment: String, Codable, CaseIterable, Identifiable, Sendable {
    case left
    case center
    case right

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .left: "Left"
        case .center: "Center"
        case .right: "Right"
        }
    }
}

public struct VolumeAdjustmentPreferences: Codable, Equatable, Sendable {
    public static let allowedResponseMilliseconds = [0, 10, 20, 50, 100, 150, 200, 300, 400, 500]
    public static let allowedStepPercentages = [1, 2, 5]

    public var speedMultiplier: Double
    public var responseMilliseconds: Int
    public var stepPercentage: Int
    public var hudAppearance: OverlayAppearancePreferences
    public var percentageAlignment: SoundBarPercentageAlignment

    public init(
        speedMultiplier: Double = 1.25,
        responseMilliseconds: Int = 0,
        stepPercentage: Int = 2,
        hudAppearance: OverlayAppearancePreferences = .default,
        percentageAlignment: SoundBarPercentageAlignment = .left
    ) {
        self.speedMultiplier = min(max(speedMultiplier, 0.5), 2.5)
        self.responseMilliseconds = Self.closestAllowedResponse(to: responseMilliseconds)
        self.stepPercentage = Self.allowedStepPercentages.contains(stepPercentage) ? stepPercentage : 2
        self.hudAppearance = hudAppearance
        self.percentageAlignment = percentageAlignment
    }

    public static let `default` = VolumeAdjustmentPreferences()

    public var movementPerStep: Double {
        0.003125 / speedMultiplier
    }

    private enum CodingKeys: String, CodingKey {
        case speedMultiplier
        case responseMilliseconds
        case stepPercentage
        case hudAppearance
        case percentageAlignment
    }

    public init(from decoder: any Decoder) throws {
        let defaults = Self.default
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            speedMultiplier: try container.decodeIfPresent(Double.self, forKey: .speedMultiplier)
                ?? defaults.speedMultiplier,
            responseMilliseconds: try container.decodeIfPresent(Int.self, forKey: .responseMilliseconds)
                ?? defaults.responseMilliseconds,
            stepPercentage: try container.decodeIfPresent(Int.self, forKey: .stepPercentage)
                ?? defaults.stepPercentage,
            hudAppearance: try container.decodeIfPresent(OverlayAppearancePreferences.self, forKey: .hudAppearance)
                ?? defaults.hudAppearance,
            percentageAlignment: try container.decodeIfPresent(
                SoundBarPercentageAlignment.self,
                forKey: .percentageAlignment
            ) ?? defaults.percentageAlignment
        )
    }

    private static func closestAllowedResponse(to value: Int) -> Int {
        allowedResponseMilliseconds.min(by: { abs($0 - value) < abs($1 - value) }) ?? 0
    }
}

public enum DiscreteGestureTrigger: String, Codable, CaseIterable, Identifiable, Sendable {
    case threeFingerTap
    case threeFingerClick
    case fourFingerTap
    case fourFingerClick
    case fiveFingerTap
    case fiveFingerClick

    public var id: String { rawValue }

    public var displayName: String { triggerKind.displayName }

    public var triggerKind: TriggerKind {
        switch self {
        case .threeFingerTap: .threeFingerTap
        case .threeFingerClick: .threeFingerClick
        case .fourFingerTap: .fourFingerTap
        case .fourFingerClick: .fourFingerClick
        case .fiveFingerTap: .fiveFingerTap
        case .fiveFingerClick: .fiveFingerClick
        }
    }
}

public struct GestureFeatureSetting<Trigger: Codable & Equatable & Sendable>: Codable, Equatable, Sendable {
    public var isEnabled: Bool
    public var trigger: Trigger

    public init(isEnabled: Bool = false, trigger: Trigger) {
        self.isEnabled = isEnabled
        self.trigger = trigger
    }
}

public enum ScreenshotStorageMode: String, Codable, CaseIterable, Identifiable, Sendable {
    case systemDefault
    case customFolder

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .systemDefault: "Default Folder"
        case .customFolder: "Custom Folder"
        }
    }
}

public struct ScreenshotStorageSettings: Codable, Equatable, Sendable {
    public var saveAdditionalCopy: Bool
    public var mode: ScreenshotStorageMode
    public var customFolderPath: String?

    public init(
        saveAdditionalCopy: Bool = false,
        mode: ScreenshotStorageMode = .systemDefault,
        customFolderPath: String? = nil
    ) {
        self.saveAdditionalCopy = saveAdditionalCopy
        self.mode = mode
        self.customFolderPath = customFolderPath
    }

    public static let `default` = ScreenshotStorageSettings()

    private enum CodingKeys: String, CodingKey {
        case saveAdditionalCopy
        case mode
        case customFolderPath
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        saveAdditionalCopy = try container.decodeIfPresent(Bool.self, forKey: .saveAdditionalCopy) ?? false
        mode = try container.decodeIfPresent(ScreenshotStorageMode.self, forKey: .mode) ?? .systemDefault
        customFolderPath = try container.decodeIfPresent(String.self, forKey: .customFolderPath)
    }
}

public enum GestureFeature: String, CaseIterable, Identifiable, Sendable {
    case mute
    case playPause
    case screenshot
    case customScreenshot

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .mute: "Mute / Unmute"
        case .playPause: "Play / Pause"
        case .screenshot: "Screenshot"
        case .customScreenshot: "Custom Screenshot"
        }
    }
}

public struct GestureSettings: Codable, Equatable, Sendable {
    public var volumeAdjustment: GestureFeatureSetting<VerticalGestureTrigger>
    public var volumePreferences: VolumeAdjustmentPreferences
    public var mute: GestureFeatureSetting<DiscreteGestureTrigger>
    public var playPause: GestureFeatureSetting<DiscreteGestureTrigger>
    public var screenshot: GestureFeatureSetting<DiscreteGestureTrigger>
    public var customScreenshot: GestureFeatureSetting<DiscreteGestureTrigger>
    public var screenshotStorage: ScreenshotStorageSettings
    public var interactiveWindowSwitcherEnabled: Bool

    public init(
        volumeAdjustment: GestureFeatureSetting<VerticalGestureTrigger> = .init(trigger: .fourFinger),
        volumePreferences: VolumeAdjustmentPreferences = .default,
        mute: GestureFeatureSetting<DiscreteGestureTrigger> = .init(trigger: .fiveFingerTap),
        playPause: GestureFeatureSetting<DiscreteGestureTrigger> = .init(trigger: .fourFingerTap),
        screenshot: GestureFeatureSetting<DiscreteGestureTrigger> = .init(trigger: .threeFingerClick),
        customScreenshot: GestureFeatureSetting<DiscreteGestureTrigger> = .init(trigger: .fiveFingerClick),
        screenshotStorage: ScreenshotStorageSettings = .default,
        interactiveWindowSwitcherEnabled: Bool = false
    ) {
        self.volumeAdjustment = volumeAdjustment
        self.volumePreferences = volumePreferences
        self.mute = mute
        self.playPause = playPause
        self.screenshot = screenshot
        self.customScreenshot = customScreenshot
        self.screenshotStorage = screenshotStorage
        self.interactiveWindowSwitcherEnabled = interactiveWindowSwitcherEnabled
    }

    public static let `default` = GestureSettings()

    public func owner(of trigger: DiscreteGestureTrigger, excluding excludedFeature: GestureFeature? = nil)
        -> GestureFeature?
    {
        let assignments: [(GestureFeature, GestureFeatureSetting<DiscreteGestureTrigger>)] = [
            (.mute, mute),
            (.playPause, playPause),
            (.screenshot, screenshot),
            (.customScreenshot, customScreenshot),
        ]
        return assignments.first {
            $0.0 != excludedFeature && $0.1.isEnabled && $0.1.trigger == trigger
        }?.0
    }

    public var conflictingFeatures: Set<GestureFeature> {
        let assignments: [(GestureFeature, GestureFeatureSetting<DiscreteGestureTrigger>)] = [
            (.mute, mute),
            (.playPause, playPause),
            (.screenshot, screenshot),
            (.customScreenshot, customScreenshot),
        ]
        let enabled = assignments.filter(\.1.isEnabled)
        let groups = Dictionary(grouping: enabled, by: { $0.1.trigger })
        return Set(groups.values.filter { $0.count > 1 }.flatMap { $0.map(\.0) })
    }

    private enum CodingKeys: String, CodingKey {
        case volumeAdjustment
        case volumePreferences
        case mute
        case playPause
        case screenshot
        case customScreenshot
        case screenshotStorage
        case interactiveWindowSwitcherEnabled
    }

    public init(from decoder: any Decoder) throws {
        let defaults = GestureSettings.default
        let container = try decoder.container(keyedBy: CodingKeys.self)
        volumeAdjustment =
            try container.decodeIfPresent(
                GestureFeatureSetting<VerticalGestureTrigger>.self,
                forKey: .volumeAdjustment
            ) ?? defaults.volumeAdjustment
        volumePreferences =
            try container.decodeIfPresent(VolumeAdjustmentPreferences.self, forKey: .volumePreferences)
            ?? defaults.volumePreferences
        mute =
            try container.decodeIfPresent(
                GestureFeatureSetting<DiscreteGestureTrigger>.self,
                forKey: .mute
            ) ?? defaults.mute
        playPause =
            try container.decodeIfPresent(
                GestureFeatureSetting<DiscreteGestureTrigger>.self,
                forKey: .playPause
            ) ?? defaults.playPause
        screenshot =
            try container.decodeIfPresent(
                GestureFeatureSetting<DiscreteGestureTrigger>.self,
                forKey: .screenshot
            ) ?? defaults.screenshot
        customScreenshot =
            try container.decodeIfPresent(
                GestureFeatureSetting<DiscreteGestureTrigger>.self,
                forKey: .customScreenshot
            ) ?? defaults.customScreenshot
        screenshotStorage =
            try container.decodeIfPresent(ScreenshotStorageSettings.self, forKey: .screenshotStorage)
            ?? defaults.screenshotStorage
        interactiveWindowSwitcherEnabled =
            try container.decodeIfPresent(Bool.self, forKey: .interactiveWindowSwitcherEnabled)
            ?? defaults.interactiveWindowSwitcherEnabled
    }
}

public struct KeyFlowConfiguration: Codable, Equatable, Sendable {
    public static let currentSchemaVersion = 19

    public var schemaVersion: Int
    public var revision: Int
    public var mappings: [Mapping]
    public var windowSwitcherPreferences: WindowSwitcherPreferences
    public var gestureSettings: GestureSettings
    public var applicationPreferences: ApplicationPreferences
    public var overlayAppearance: OverlayAppearancePreferences

    public init(
        schemaVersion: Int = currentSchemaVersion,
        revision: Int = 0,
        mappings: [Mapping] = [],
        windowSwitcherPreferences: WindowSwitcherPreferences = .default,
        gestureSettings: GestureSettings = .default,
        applicationPreferences: ApplicationPreferences = .default,
        overlayAppearance: OverlayAppearancePreferences = .default
    ) {
        self.schemaVersion = schemaVersion
        self.revision = revision
        self.mappings = mappings
        self.windowSwitcherPreferences = windowSwitcherPreferences
        self.gestureSettings = gestureSettings
        self.applicationPreferences = applicationPreferences
        self.overlayAppearance = overlayAppearance
    }

    private enum CodingKeys: String, CodingKey {
        case schemaVersion
        case revision
        case mappings
        case windowSwitcherPreferences
        case gestureSettings
        case applicationPreferences
        case overlayAppearance
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try container.decode(Int.self, forKey: .schemaVersion)
        revision = try container.decode(Int.self, forKey: .revision)
        mappings = try container.decode([Mapping].self, forKey: .mappings)
        windowSwitcherPreferences =
            try container.decodeIfPresent(WindowSwitcherPreferences.self, forKey: .windowSwitcherPreferences)
            ?? .default
        gestureSettings = try container.decodeIfPresent(GestureSettings.self, forKey: .gestureSettings) ?? .default
        applicationPreferences =
            try container.decodeIfPresent(ApplicationPreferences.self, forKey: .applicationPreferences)
            ?? .default
        overlayAppearance =
            try container.decodeIfPresent(OverlayAppearancePreferences.self, forKey: .overlayAppearance)
            ?? .default
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(schemaVersion, forKey: .schemaVersion)
        try container.encode(revision, forKey: .revision)
        try container.encode(mappings, forKey: .mappings)
        try container.encode(windowSwitcherPreferences, forKey: .windowSwitcherPreferences)
        try container.encode(gestureSettings, forKey: .gestureSettings)
        try container.encode(applicationPreferences, forKey: .applicationPreferences)
        if schemaVersion <= 13 {
            try container.encode(overlayAppearance, forKey: .overlayAppearance)
        }
    }
}

public enum MenuBarIconStyle: String, Codable, CaseIterable, Identifiable, Sendable {
    case touch
    case command
    case keyboard
    case controls
    case pointer

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .touch: "Touch"
        case .command: "Command"
        case .keyboard: "Keyboard"
        case .controls: "Controls"
        case .pointer: "Pointer"
        }
    }

    public var systemSymbolName: String {
        switch self {
        case .touch: "hand.tap.fill"
        case .command: "command.circle.fill"
        case .keyboard: "keyboard"
        case .controls: "slider.horizontal.3"
        case .pointer: "hand.point.up.left.fill"
        }
    }
}

public struct ApplicationPreferences: Codable, Equatable, Sendable {
    public var hideFromDock: Bool
    public var menuBarIconStyle: MenuBarIconStyle

    public init(
        hideFromDock: Bool = false,
        menuBarIconStyle: MenuBarIconStyle = .touch
    ) {
        self.hideFromDock = hideFromDock
        self.menuBarIconStyle = menuBarIconStyle
    }

    public static let `default` = ApplicationPreferences()

    private enum CodingKeys: String, CodingKey {
        case hideFromDock
        case menuBarIconStyle
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        hideFromDock = try container.decodeIfPresent(Bool.self, forKey: .hideFromDock) ?? false
        menuBarIconStyle =
            try container.decodeIfPresent(MenuBarIconStyle.self, forKey: .menuBarIconStyle)
            ?? .touch
    }
}

public enum MappingValidationError: LocalizedError, Equatable, Sendable {
    case missingName
    case missingKeyCode
    case missingActionValue
    case missingApplication
    case invalidURL
    case keyboardShortcutRequiresApplication
    case windowSwitcherRequiresHorizontalSwipe
    case horizontalSwipeRequiresWindowSwitcher
    case unsupportedTrackpadGesture
    case continuousSwipeRequiresVolumeAction

    public var errorDescription: String? {
        switch self {
        case .missingName: "Give this mapping a name."
        case .missingKeyCode: "Record a keyboard shortcut."
        case .missingActionValue: "Enter a value for the selected action."
        case .missingApplication: "Choose an application to open."
        case .invalidURL: "Enter a complete http or https URL."
        case .keyboardShortcutRequiresApplication:
            "Keyboard shortcuts can only open applications. Choose an application to continue."
        case .windowSwitcherRequiresHorizontalSwipe:
            "Interactive Window Switcher requires the Four-Finger Horizontal Swipe trigger."
        case .horizontalSwipeRequiresWindowSwitcher:
            "Four-Finger Horizontal Swipe requires the Interactive Window Switcher action."
        case .unsupportedTrackpadGesture:
            "This legacy trackpad gesture is no longer supported. Convert or delete it."
        case .continuousSwipeRequiresVolumeAction:
            "Continuous four-finger swipes support Volume Up or Volume Down actions only."
        }
    }
}

public enum MappingValidator {
    public static func validate(_ mapping: Mapping) -> [MappingValidationError] {
        var errors: [MappingValidationError] = []
        if mapping.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errors.append(.missingName)
        }
        if mapping.trigger.kind == .keyboard, mapping.trigger.keyCode == nil {
            errors.append(.missingKeyCode)
        }
        let value = mapping.action.value.trimmingCharacters(in: .whitespacesAndNewlines)
        if mapping.trigger.kind == .keyboard, mapping.action.kind != .launchApplication {
            errors.append(.keyboardShortcutRequiresApplication)
        }
        if mapping.action.kind == .launchApplication, value.isEmpty {
            errors.append(.missingApplication)
        } else if mapping.action.kind.requiresValue && value.isEmpty {
            errors.append(.missingActionValue)
        }
        if mapping.action.kind == .openURL {
            let url = URL(string: value)
            if url?.scheme != "http" && url?.scheme != "https" {
                errors.append(.invalidURL)
            }
        }
        if mapping.action.kind == .windowSwitcher, mapping.trigger.kind != .fourFingerHorizontalSwipe {
            errors.append(.windowSwitcherRequiresHorizontalSwipe)
        }
        if mapping.trigger.kind == .fourFingerHorizontalSwipe, mapping.action.kind != .windowSwitcher {
            errors.append(.horizontalSwipeRequiresWindowSwitcher)
        }
        if mapping.trigger.kind.isLegacyTrackpadGesture {
            errors.append(.unsupportedTrackpadGesture)
        }
        if [
            .threeFingerSwipeUp, .threeFingerSwipeDown, .fourFingerSwipeUp, .fourFingerSwipeDown,
            .fiveFingerSwipeUp, .fiveFingerSwipeDown,
        ].contains(mapping.trigger.kind),
            ![.volumeUp, .volumeDown].contains(mapping.action.kind)
        {
            errors.append(.continuousSwipeRequiresVolumeAction)
        }
        return errors
    }
}

public enum MappingCollectionValidator {
    public static func conflictingMappingIDs(in mappings: [Mapping]) -> Set<UUID> {
        let candidates = mappings.filter {
            $0.isEnabled && MappingValidator.validate($0).isEmpty
        }
        var firstMappingByTrigger: [TriggerDefinition: UUID] = [:]
        var conflicts: Set<UUID> = []

        for mapping in candidates {
            let trigger = normalized(mapping.trigger)
            if let firstID = firstMappingByTrigger[trigger] {
                conflicts.insert(firstID)
                conflicts.insert(mapping.id)
            } else {
                firstMappingByTrigger[trigger] = mapping.id
            }
        }
        return conflicts
    }

    private static func normalized(_ trigger: TriggerDefinition) -> TriggerDefinition {
        guard trigger.kind == .keyboard else {
            return TriggerDefinition(kind: trigger.kind)
        }
        return TriggerDefinition(
            kind: .keyboard,
            keyCode: trigger.keyCode,
            modifiers: trigger.modifiers.intersection(.supportedMask)
        )
    }
}

public enum KeyCodeNames {
    private static let names: [UInt16: String] = [
        0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X",
        8: "C", 9: "V", 11: "B", 12: "Q", 13: "W", 14: "E", 15: "R",
        16: "Y", 17: "T", 18: "1", 19: "2", 20: "3", 21: "4", 22: "6",
        23: "5", 24: "=", 25: "9", 26: "7", 27: "-", 28: "8", 29: "0",
        30: "]", 31: "O", 32: "U", 33: "[", 34: "I", 35: "P", 36: "↩",
        37: "L", 38: "J", 39: "'", 40: "K", 41: ";", 42: "\\", 43: ",",
        44: "/", 45: "N", 46: "M", 47: ".", 48: "⇥", 49: "Space", 50: "`",
        51: "⌫", 53: "Esc", 96: "F5", 97: "F6", 98: "F7", 99: "F3",
        100: "F8", 101: "F9", 103: "F11", 109: "F10", 111: "F12", 118: "F4",
        120: "F2", 122: "F1", 123: "←", 124: "→", 125: "↓", 126: "↑",
    ]

    public static func name(for keyCode: UInt16) -> String {
        names[keyCode] ?? "Key \(keyCode)"
    }
}
