import AppKit
import KeyFlowCore

/// A lightweight volume indicator for gesture-driven Core Audio changes.
///
/// Posting a media-key down/up pair for every touch frame makes WindowServer and the
/// system OSD process rebuild the native HUD repeatedly. Direct Core Audio updates plus
/// one reusable, layer-backed panel preserve immediate feedback without that hot path.
@MainActor
final class SystemVolumeHUDController {
    private let content = SystemVolumeHUDView(frame: NSRect(x: 0, y: 0, width: 260, height: 72))
    private var hideDeadline = ContinuousClock.now
    private var hideTask: Task<Void, Never>?

    private lazy var panel: NSPanel = {
        let panel = NSPanel(
            contentRect: content.bounds,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: true
        )
        panel.level = .statusBar
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.ignoresMouseEvents = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient, .ignoresCycle]
        panel.contentView = content
        return panel
    }()

    func prepare() {
        _ = panel
        content.update(level: 0.5)
        content.layoutSubtreeIfNeeded()
        positionPanel()
        panel.alphaValue = 0
        panel.orderFrontRegardless()
        panel.displayIfNeeded()
        panel.orderOut(nil)
        panel.alphaValue = 1
    }

    func updateAppearance(_ preferences: OverlayAppearancePreferences) {
        content.applyAppearance(preferences)
    }

    func show(level: Double) {
        content.update(level: min(max(level, 0), 1))
        hideDeadline = .now.advanced(by: .milliseconds(850))

        if !panel.isVisible {
            positionPanel()
            panel.orderFrontRegardless()
        }
        guard hideTask == nil else { return }
        hideTask = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                let remaining = ContinuousClock.now.duration(to: hideDeadline)
                if remaining <= .zero { break }
                try? await Task.sleep(for: remaining)
            }
            guard !Task.isCancelled else { return }
            panel.orderOut(nil)
            hideTask = nil
        }
    }

    private func positionPanel() {
        let screen = NSScreen.screens.first(where: { $0.frame.contains(NSEvent.mouseLocation) }) ?? NSScreen.main
        guard let screen else { return }
        let size = content.bounds.size
        panel.setFrameOrigin(
            NSPoint(
                x: screen.visibleFrame.midX - size.width / 2,
                y: screen.visibleFrame.minY + min(120, screen.visibleFrame.height * 0.12)
            )
        )
    }
}

@MainActor
private final class SystemVolumeHUDView: NSView {
    private let effectView = NSVisualEffectView()
    private let tintView = NSView()
    private let iconView = NSImageView()
    private let percentageLabel = NSTextField(labelWithString: "50%")
    private let trackLayer = CALayer()
    private let fillLayer = CALayer()
    private var level = 0.0
    private var displayedSymbol = ""
    private var appearancePreferences: OverlayAppearancePreferences = .default

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.masksToBounds = true

        effectView.material = .hudWindow
        effectView.blendingMode = .behindWindow
        effectView.state = .active
        addSubview(effectView)

        tintView.wantsLayer = true
        addSubview(tintView)

        iconView.contentTintColor = .labelColor
        iconView.imageScaling = .scaleProportionallyUpOrDown
        addSubview(iconView)

        percentageLabel.font = .monospacedDigitSystemFont(ofSize: 15, weight: .semibold)
        percentageLabel.textColor = .labelColor
        percentageLabel.alignment = .right
        addSubview(percentageLabel)

        trackLayer.backgroundColor = NSColor.secondaryLabelColor.withAlphaComponent(0.22).cgColor
        trackLayer.cornerRadius = 4
        fillLayer.backgroundColor = NSColor.controlAccentColor.cgColor
        fillLayer.cornerRadius = 4
        layer?.addSublayer(trackLayer)
        layer?.addSublayer(fillLayer)
        applyAppearance(.default)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func update(level: Double) {
        let clamped = min(max(level, 0), 1)
        guard abs(clamped - self.level) >= 0.001 || displayedSymbol.isEmpty else { return }
        self.level = clamped
        percentageLabel.stringValue = "\(Int((clamped * 100).rounded()))%"
        let symbol =
            if clamped <= 0.001 { "speaker.slash.fill" } else if clamped < 0.34 {
                "speaker.wave.1.fill"
            } else if clamped < 0.67 { "speaker.wave.2.fill" } else { "speaker.wave.3.fill" }
        if symbol != displayedSymbol {
            displayedSymbol = symbol
            iconView.image = NSImage(systemSymbolName: symbol, accessibilityDescription: "Volume")
        }
        needsLayout = true
    }

    func applyAppearance(_ preferences: OverlayAppearancePreferences) {
        appearancePreferences = preferences
        appearance = preferences.appKitAppearance
        let cornerRadius = CGFloat(preferences.cornerRadius * 0.8)
        layer?.cornerRadius = cornerRadius
        layer?.borderWidth = preferences.showsBorder ? 1 : 0
        layer?.borderColor = preferences.appKitTextColor.withAlphaComponent(0.14).cgColor
        effectView.isHidden = preferences.surfaceStyle == .solid
        effectView.alphaValue = preferences.backgroundOpacity
        effectView.layer?.cornerRadius = cornerRadius
        tintView.layer?.cornerRadius = cornerRadius
        let tintOpacity =
            preferences.surfaceStyle == .frosted
            ? preferences.backgroundOpacity * 0.34
            : preferences.backgroundOpacity
        tintView.layer?.backgroundColor = preferences.appKitBackgroundColor.withAlphaComponent(tintOpacity).cgColor
        iconView.contentTintColor = preferences.appKitTextColor
        percentageLabel.textColor = preferences.appKitTextColor
        trackLayer.backgroundColor = preferences.appKitTextColor.withAlphaComponent(0.22).cgColor
        fillLayer.backgroundColor = preferences.appKitAccentColor.cgColor
        needsLayout = true
    }

    override func layout() {
        super.layout()
        effectView.frame = bounds
        tintView.frame = bounds
        iconView.frame = NSRect(x: 20, y: 22, width: 28, height: 28)
        percentageLabel.frame = NSRect(x: bounds.width - 58, y: 25, width: 42, height: 22)
        let trackFrame = NSRect(x: 64, y: 31, width: bounds.width - 132, height: 10)
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        trackLayer.frame = trackFrame
        fillLayer.frame = NSRect(
            x: trackFrame.minX,
            y: trackFrame.minY,
            width: trackFrame.width * level,
            height: trackFrame.height
        )
        CATransaction.commit()
    }
}
