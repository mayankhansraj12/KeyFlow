import AppKit
import KeyFlowCore

/// A lightweight volume indicator for gesture-driven Core Audio changes.
///
/// Posting a media-key down/up pair for every touch frame makes WindowServer and the
/// system OSD process rebuild the native HUD repeatedly. Direct Core Audio updates plus
/// one reusable, layer-backed panel preserve immediate feedback without that hot path.
@MainActor
final class SystemVolumeHUDController: VolumeHUDControlling {
    private let content = SystemVolumeHUDView(
        frame: NSRect(origin: .zero, size: SystemVolumeHUDLayout.preferredSize)
    )
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

    func updatePercentageAlignment(_ alignment: SoundBarPercentageAlignment) {
        content.applyPercentageAlignment(alignment)
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

struct SystemVolumeHUDLayout: Equatable {
    static let preferredSize = NSSize(width: 220, height: 48)

    let iconFrame: NSRect
    let trackFrame: NSRect
    let percentageFrame: NSRect

    static func frames(in bounds: NSRect) -> Self {
        let outerMargin: CGFloat = 14
        let itemSpacing: CGFloat = 10
        let iconSize: CGFloat = 22
        let trackHeight: CGFloat = 8
        let percentageWidth: CGFloat = 44
        let percentageHeight: CGFloat = 20

        let iconFrame = NSRect(
            x: bounds.minX + outerMargin,
            y: bounds.midY - iconSize / 2,
            width: iconSize,
            height: iconSize
        )
        let percentageFrame = NSRect(
            x: bounds.maxX - outerMargin - percentageWidth,
            y: bounds.midY - percentageHeight / 2,
            width: percentageWidth,
            height: percentageHeight
        )
        let trackX = iconFrame.maxX + itemSpacing
        let trackFrame = NSRect(
            x: trackX,
            y: bounds.midY - trackHeight / 2,
            width: max(0, percentageFrame.minX - itemSpacing - trackX),
            height: trackHeight
        )
        return Self(
            iconFrame: iconFrame,
            trackFrame: trackFrame,
            percentageFrame: percentageFrame
        )
    }
}

@MainActor
final class SystemVolumeHUDView: NSView {
    private let effectView = NSVisualEffectView()
    private let tintView = NSView()
    private let barView = NSView()
    private let iconView = NSImageView()
    private let percentageLabel = NSTextField(labelWithString: "50%")
    private let trackLayer = CALayer()
    private let fillLayer = CALayer()
    private var level = 0.0
    private var displayedSymbol = ""
    private var percentageAlignment = SoundBarPercentageAlignment.left

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.masksToBounds = true

        effectView.material = .hudWindow
        effectView.blendingMode = .behindWindow
        effectView.state = .active
        effectView.wantsLayer = true
        addSubview(effectView)

        tintView.wantsLayer = true
        addSubview(tintView)

        barView.wantsLayer = true
        addSubview(barView)

        iconView.contentTintColor = .labelColor
        iconView.imageScaling = .scaleProportionallyUpOrDown
        addSubview(iconView)

        percentageLabel.font = .monospacedDigitSystemFont(ofSize: 14, weight: .semibold)
        percentageLabel.textColor = .labelColor
        percentageLabel.alignment = percentageAlignment.textAlignment
        addSubview(percentageLabel)

        trackLayer.backgroundColor = NSColor.secondaryLabelColor.withAlphaComponent(0.22).cgColor
        trackLayer.cornerRadius = 4
        fillLayer.backgroundColor = NSColor.controlAccentColor.cgColor
        fillLayer.cornerRadius = 4
        barView.layer?.addSublayer(trackLayer)
        barView.layer?.addSublayer(fillLayer)
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
        appearance = preferences.appKitAppearance
        let cornerRadius = CGFloat(preferences.cornerRadius * 0.8)
        layer?.cornerRadius = cornerRadius
        layer?.borderWidth = preferences.showsBorder ? 1 : 0
        layer?.borderColor = resolvedCGColor(preferences.appKitTextColor, alpha: 0.14)
        effectView.isHidden = preferences.surfaceStyle == .solid
        effectView.alphaValue = preferences.backgroundOpacity
        effectView.layer?.cornerRadius = cornerRadius
        tintView.layer?.cornerRadius = cornerRadius
        let tintOpacity =
            preferences.surfaceStyle == .frosted
            ? preferences.backgroundOpacity * 0.34
            : preferences.backgroundOpacity
        tintView.layer?.backgroundColor = resolvedCGColor(preferences.appKitBackgroundColor, alpha: tintOpacity)
        iconView.contentTintColor = preferences.appKitTextColor
        percentageLabel.textColor = preferences.appKitTextColor
        trackLayer.backgroundColor = resolvedCGColor(preferences.appKitTextColor, alpha: 0.22)
        fillLayer.backgroundColor = resolvedCGColor(preferences.appKitAccentColor)
        needsLayout = true
    }

    func applyPercentageAlignment(_ alignment: SoundBarPercentageAlignment) {
        guard percentageAlignment != alignment else { return }
        percentageAlignment = alignment
        percentageLabel.alignment = alignment.textAlignment
    }

    private func resolvedCGColor(_ color: NSColor, alpha: CGFloat = 1) -> CGColor {
        var result = color.withAlphaComponent(alpha).cgColor
        effectiveAppearance.performAsCurrentDrawingAppearance {
            result = color.withAlphaComponent(alpha).cgColor
        }
        return result
    }

    override func layout() {
        super.layout()
        effectView.frame = bounds
        tintView.frame = bounds
        barView.frame = bounds
        let frames = SystemVolumeHUDLayout.frames(in: bounds)
        iconView.frame = frames.iconFrame
        percentageLabel.frame = frames.percentageFrame
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        trackLayer.frame = frames.trackFrame
        fillLayer.frame = NSRect(
            x: frames.trackFrame.minX,
            y: frames.trackFrame.minY,
            width: frames.trackFrame.width * level,
            height: frames.trackFrame.height
        )
        CATransaction.commit()
    }
}

private extension SoundBarPercentageAlignment {
    var textAlignment: NSTextAlignment {
        switch self {
        case .left: .left
        case .center: .center
        case .right: .right
        }
    }
}
