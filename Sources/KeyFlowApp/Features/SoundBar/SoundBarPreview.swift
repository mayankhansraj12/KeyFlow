import AppKit
import KeyFlowCore
import SwiftUI

struct SoundBarPreview: NSViewRepresentable {
    let level: Double
    let appearance: OverlayAppearancePreferences
    let percentageAlignment: SoundBarPercentageAlignment

    func makeNSView(context _: Context) -> SystemVolumeHUDView {
        let view = SystemVolumeHUDView(
            frame: NSRect(origin: .zero, size: SystemVolumeHUDLayout.preferredSize)
        )
        view.applyAppearance(appearance)
        view.applyPercentageAlignment(percentageAlignment)
        view.update(level: level)
        view.layoutSubtreeIfNeeded()
        return view
    }

    func updateNSView(_ view: SystemVolumeHUDView, context _: Context) {
        view.applyAppearance(appearance)
        view.applyPercentageAlignment(percentageAlignment)
        view.update(level: level)
        view.needsLayout = true
    }
}
