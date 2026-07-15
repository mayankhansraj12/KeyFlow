import AppKit
import ApplicationServices
import CoreGraphics
import Foundation
import KeyFlowCore

struct SwitchableWindow: Identifiable {
    enum ID: Hashable {
        case window(CGWindowID)
        case application(pid_t)
    }

    let id: ID
    let windowID: CGWindowID?
    let processID: pid_t
    let title: String
    let applicationName: String
    let bounds: CGRect
    let applicationIcon: NSImage
    let applicationElement: AXUIElement
    let windowElement: AXUIElement?
    var thumbnail: NSImage?
}

@MainActor
final class WindowSwitcherModel: ObservableObject {
    @Published private(set) var windows: [SwitchableWindow] = []
    @Published private(set) var selectedIndex = 0
    @Published private(set) var preferences: WindowSwitcherPreferences = .default
    @Published private(set) var appearance: OverlayAppearancePreferences = .default
    private var initialIndex = 0
    private var navigationSession = WindowSwitcherNavigationSession()

    var selectedWindow: SwitchableWindow? {
        windows.indices.contains(selectedIndex) ? windows[selectedIndex] : nil
    }

    func configure(
        windows: [SwitchableWindow],
        initialIndex: Int,
        translationX: Double,
        translationY: Double
    ) {
        self.windows = windows
        self.initialIndex = min(max(initialIndex, 0), max(windows.count - 1, 0))
        navigationSession.begin(translationX: translationX, translationY: translationY)
        selectedIndex = self.initialIndex
    }

    func updateSelection(translationX: Double, translationY: Double) {
        let updatedIndex = navigationSession.index(
            translationX: translationX,
            translationY: translationY,
            itemCount: windows.count,
            initialIndex: initialIndex,
            speed: preferences.navigationSpeed
        )
        guard updatedIndex != selectedIndex else { return }
        selectedIndex = updatedIndex
    }

    func updateThumbnails(_ thumbnails: [CGWindowID: NSImage]) {
        guard !thumbnails.isEmpty else { return }
        var updatedWindows = windows
        var didUpdate = false
        for index in updatedWindows.indices {
            guard
                let windowID = updatedWindows[index].windowID,
                let thumbnail = thumbnails[windowID]
            else { continue }
            updatedWindows[index].thumbnail = thumbnail
            didUpdate = true
        }
        if didUpdate { windows = updatedWindows }
    }

    func updatePreferences(_ preferences: WindowSwitcherPreferences) {
        self.preferences = preferences
    }

    func updateAppearance(_ appearance: OverlayAppearancePreferences) {
        self.appearance = appearance
    }

    func clearContent() {
        windows = []
        selectedIndex = 0
        initialIndex = 0
        navigationSession = WindowSwitcherNavigationSession()
    }
}

struct WindowSwitcherNavigationSession {
    private var originX = 0.0
    private var originY = 0.0
    private var resolver = WindowSwitcherNavigationResolver()

    mutating func begin(translationX: Double, translationY: Double) {
        originX = translationX.isFinite ? translationX : 0
        originY = translationY.isFinite ? translationY : 0
        resolver.reset()
    }

    mutating func index(
        translationX: Double,
        translationY: Double,
        itemCount: Int,
        initialIndex: Int,
        speed: Double
    ) -> Int {
        resolver.index(
            translationX: translationX - originX,
            translationY: translationY - originY,
            itemCount: itemCount,
            initialIndex: initialIndex,
            speed: speed
        )
    }
}

struct WindowSwitcherNavigationResolver {
    private var horizontalQuantizer = HystereticAxisQuantizer()
    private var verticalQuantizer = HystereticAxisQuantizer()

    mutating func reset() {
        horizontalQuantizer.reset()
        verticalQuantizer.reset()
    }

    mutating func index(
        translationX: Double,
        translationY: Double,
        itemCount: Int,
        initialIndex: Int,
        speed: Double
    ) -> Int {
        guard itemCount > 0 else { return 0 }
        let safeInitialIndex = min(max(initialIndex, 0), itemCount - 1)
        guard translationX.isFinite, translationY.isFinite else { return safeInitialIndex }
        let grid = WindowSwitcherGridLayout(itemCount: itemCount)
        guard let initialPosition = grid.position(for: safeInitialIndex) else { return safeInitialIndex }

        let profile = WindowSwitcherNavigationProfile(speed: speed)
        let horizontalSteps = horizontalQuantizer.steps(
            translation: translationX,
            profile: profile.horizontal
        )
        let verticalSteps = verticalQuantizer.steps(
            translation: translationY,
            profile: profile.vertical
        )
        let targetRow = min(max(initialPosition.row - verticalSteps, 0), grid.rowCount - 1)
        let targetColumn = min(
            max(initialPosition.column + horizontalSteps, 0),
            max(grid.itemCount(inRow: targetRow) - 1, 0)
        )
        return min(itemCount - 1, targetRow * grid.columnCount + targetColumn)
    }
}

private struct HystereticAxisQuantizer {
    private var currentSteps = 0

    mutating func reset() {
        currentSteps = 0
    }

    mutating func steps(translation: Double, profile: WindowSwitcherAxisProfile) -> Int {
        let proposedSteps = Self.proposedSteps(translation: translation, profile: profile)
        guard proposedSteps != currentSteps else { return currentSteps }

        let sameDirection = proposedSteps != 0 && proposedSteps.signum() == currentSteps.signum()
        let movingFarther = sameDirection && abs(proposedSteps) > abs(currentSteps)
        let changingDirection = proposedSteps != 0 && proposedSteps.signum() != currentSteps.signum()
        if currentSteps == 0 || movingFarther || changingDirection {
            currentSteps = proposedSteps
            return currentSteps
        }

        let currentBoundary =
            profile.activationDistance
            + Double(max(abs(currentSteps) - 1, 0)) * profile.stepDistance
        if abs(translation) <= max(0, currentBoundary - profile.hysteresisDistance) {
            currentSteps = proposedSteps
        }
        return currentSteps
    }

    private static func proposedSteps(translation: Double, profile: WindowSwitcherAxisProfile) -> Int {
        guard abs(translation) >= profile.activationDistance else { return 0 }
        let additionalDistance = max(0, abs(translation) - profile.activationDistance)
        let steps = 1 + Int(additionalDistance / profile.stepDistance)
        return translation < 0 ? -steps : steps
    }
}

struct WindowSwitcherAxisProfile {
    let activationDistance: Double
    let stepDistance: Double
    let hysteresisDistance: Double
}

struct WindowSwitcherNavigationProfile {
    let horizontal: WindowSwitcherAxisProfile
    let vertical: WindowSwitcherAxisProfile
    let animationResponse: Double
    let animationDamping: Double

    init(speed: Double) {
        let speed = min(max(speed, 0.25), 2.5)
        horizontal = .init(
            activationDistance: 0.052 / speed,
            stepDistance: 0.075 / speed,
            hysteresisDistance: 0.013 / speed
        )
        vertical = .init(
            activationDistance: 0.047 / speed,
            stepDistance: 0.085 / speed,
            hysteresisDistance: 0.014 / speed
        )
        animationResponse = min(max(0.16 / speed.squareRoot(), 0.1), 0.32)
        animationDamping = Self.interpolate(
            from: 0.88,
            to: 0.8,
            progress: (speed - 0.25) / 2.25
        )
    }

    private static func interpolate(from start: Double, to end: Double, progress: Double) -> Double {
        start + (end - start) * progress
    }
}
