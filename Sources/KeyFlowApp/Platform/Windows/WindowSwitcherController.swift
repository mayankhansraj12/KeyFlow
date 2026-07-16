import AppKit
import Foundation
import KeyFlowCore
import SwiftUI

@MainActor
protocol WindowSwitching: AnyObject {
    func setEnabled(_ enabled: Bool)
    func update(preferences: WindowSwitcherPreferences)
    func update(appearance: OverlayAppearancePreferences)
    func begin(translationX: Double, translationY: Double) throws
    func update(translationX: Double, translationY: Double)
    func finish(translationX: Double, translationY: Double) throws
    func cancel()
}

extension WindowSwitching {
    func update(appearance _: OverlayAppearancePreferences) {}
}

@MainActor
protocol WindowSwitcherPresenting: AnyObject {
    func show(windowCount: Int, cardSize: WindowSwitcherCardSize)
    func hide()
}

@MainActor
final class WindowSwitcherController: WindowSwitching {
    private let model: WindowSwitcherModel
    private let catalog: any WindowCataloging
    private let thumbnails: any WindowThumbnailProviding
    private let presenter: any WindowSwitcherPresenting
    private var isActive = false
    private var thumbnailTask: Task<Void, Never>?
    private var isEnabled = false
    private var preferences: WindowSwitcherPreferences = .default

    init(
        catalog: any WindowCataloging = SystemWindowCatalog(),
        thumbnails: any WindowThumbnailProviding = WindowThumbnailProvider(),
        presenter: (any WindowSwitcherPresenting)? = nil
    ) {
        let model = WindowSwitcherModel()
        self.model = model
        self.catalog = catalog
        self.thumbnails = thumbnails
        self.presenter = presenter ?? SystemWindowSwitcherPresenter(model: model)
    }

    func update(preferences: WindowSwitcherPreferences) {
        self.preferences = preferences
        model.updatePreferences(preferences)
        if isActive {
            presenter.show(windowCount: model.windows.count, cardSize: preferences.cardSize)
        }
    }

    func update(appearance: OverlayAppearancePreferences) {
        model.updateAppearance(appearance)
    }

    func setEnabled(_ enabled: Bool) {
        isEnabled = enabled
        if !enabled {
            cancel()
        }
    }

    func begin(translationX: Double, translationY: Double) throws {
        let performance = KeyFlowPerformance.begin("BeginSwitcher", using: KeyFlowPerformance.windows)
        defer { performance.end() }
        guard isEnabled else { return }
        cancel()
        let availableWindows = catalog.availableWindows(scope: preferences.windowScope)
        guard !availableWindows.isEmpty else { throw WindowCatalogError.noWindows }
        let arrangement = centeredArrangement(
            windows: availableWindows,
            initialTranslationX: translationX
        )
        var windows = arrangement.windows
        let cachedImages = thumbnails.cachedThumbnails(for: windows)
        for index in windows.indices {
            guard let image = cachedImages[windows[index].windowID] else { continue }
            windows[index].thumbnail = image
        }
        isActive = true
        model.configure(
            windows: windows,
            initialIndex: arrangement.initialIndex,
            translationX: translationX,
            translationY: translationY
        )
        KeyFlowLog.input.info(
            "Window gesture began x=\(translationX, privacy: .public) y=\(translationY, privacy: .public) windows=\(windows.count, privacy: .public) selected=\(self.model.selectedIndex, privacy: .public)"
        )
        presenter.show(windowCount: windows.count, cardSize: preferences.cardSize)

        let captureOrder = prioritizedCaptureOrder(
            windows: windows,
            selectedIndex: arrangement.initialIndex
        )
        // Cached thumbnails make presentation immediate; every launch still
        // reconciles them with current ScreenCaptureKit content in the background.
        let captureTargets = captureOrder
        thumbnailTask = Task { [weak self] in
            guard let self else { return }
            let images = await thumbnails.thumbnails(for: captureTargets) { [weak self] update in
                guard let self, !Task.isCancelled, isActive else { return }
                model.updateThumbnails(update)
            }
            guard !Task.isCancelled, isActive else { return }
            model.updateThumbnails(images)
        }
    }

    func update(translationX: Double, translationY: Double) {
        guard isActive else { return }
        let previousIndex = model.selectedIndex
        model.updateSelection(translationX: translationX, translationY: translationY)
        if model.selectedIndex != previousIndex {
            KeyFlowLog.input.debug(
                "Window gesture moved x=\(translationX, privacy: .public) y=\(translationY, privacy: .public) selected=\(self.model.selectedIndex, privacy: .public)"
            )
        }
    }

    func finish(translationX: Double, translationY: Double) throws {
        let performance = KeyFlowPerformance.begin("FinishSwitcher", using: KeyFlowPerformance.windows)
        defer { performance.end() }
        guard isActive else { return }
        // Activate the card represented by the visible blue outline. The recognizer has
        // already delivered every meaningful movement through `update`; recomputing from a
        // tiny final lift sample could silently cross a threshold after the UI last rendered.
        _ = (translationX, translationY)
        let selectedWindow = model.selectedWindow
        KeyFlowLog.input.info(
            "Window gesture ended x=\(translationX, privacy: .public) y=\(translationY, privacy: .public) selected=\(self.model.selectedIndex, privacy: .public) pid=\(selectedWindow?.processID ?? 0, privacy: .public)"
        )
        closePanel()
        guard let selectedWindow else { throw WindowCatalogError.noWindows }
        try catalog.activate(selectedWindow)
    }

    func cancel() {
        guard isActive else { return }
        closePanel()
    }

    private func closePanel() {
        isActive = false
        thumbnailTask?.cancel()
        thumbnailTask = nil
        presenter.hide()
        model.clearContent()
    }
}

@MainActor
final class SystemWindowSwitcherPresenter: WindowSwitcherPresenting {
    private let model: WindowSwitcherModel
    private lazy var panel: NSPanel = {
        let panel = NSPanel(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .popUpMenu
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.ignoresMouseEvents = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient, .ignoresCycle]
        panel.contentView = NSHostingView(rootView: WindowSwitcherView(model: model))
        return panel
    }()

    init(model: WindowSwitcherModel) {
        self.model = model
    }

    func show(windowCount: Int, cardSize: WindowSwitcherCardSize) {
        let screen = NSScreen.screens.first(where: { $0.frame.contains(NSEvent.mouseLocation) }) ?? NSScreen.main
        guard let screen else { return }
        let metrics = WindowSwitcherLayoutMetrics(cardSize)
        let grid = WindowSwitcherGridLayout(itemCount: windowCount)
        let horizontalMargin = min(72, max(32, screen.visibleFrame.width * 0.04))
        let maximumWidth = max(420, screen.visibleFrame.width - horizontalMargin)
        let preferredSize = metrics.preferredPanelSize(for: grid)
        let width = min(preferredSize.width, maximumWidth)
        let height = min(preferredSize.height, screen.visibleFrame.height - 56)
        let frame = CGRect(
            x: screen.visibleFrame.midX - width / 2,
            y: screen.visibleFrame.midY - height / 2,
            width: width,
            height: height
        )
        panel.setFrame(frame, display: true)
        panel.orderFrontRegardless()
    }

    func hide() {
        panel.orderOut(nil)
    }

}

private extension WindowSwitcherController {
    func centeredArrangement(
        windows: [SwitchableWindow],
        initialTranslationX: Double
    ) -> (windows: [SwitchableWindow], initialIndex: Int) {
        guard windows.count > 1 else { return (windows, 0) }

        // The frontmost window arrives first. Put it in the middle so the outline can
        // move in the same physical direction as the fingers without wrapping across edges.
        // With only two cards, place the current card opposite the initial swipe direction.
        let initialIndex: Int
        if windows.count == 2 {
            initialIndex = initialTranslationX < 0 ? 1 : 0
        } else {
            initialIndex = WindowSwitcherGridLayout(itemCount: windows.count).preferredInitialIndex
        }
        let rotation = windows.count - initialIndex
        let arranged = Array(windows[rotation...]) + Array(windows[..<rotation])
        return (arranged, initialIndex)
    }

    func prioritizedCaptureOrder(
        windows: [SwitchableWindow],
        selectedIndex: Int
    ) -> [SwitchableWindow] {
        guard windows.indices.contains(selectedIndex) else { return windows }
        var ordered = [windows[selectedIndex]]
        ordered.reserveCapacity(windows.count)
        for distance in 1..<windows.count {
            let right = selectedIndex + distance
            if windows.indices.contains(right) { ordered.append(windows[right]) }
            let left = selectedIndex - distance
            if windows.indices.contains(left) { ordered.append(windows[left]) }
        }
        return ordered
    }

}
