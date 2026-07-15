import AppKit
import KeyFlowCore
import SwiftUI

extension OverlayAppearancePreferences {
    var preferredColorScheme: ColorScheme? {
        switch theme {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }

    var appKitAppearance: NSAppearance? {
        switch theme {
        case .system: nil
        case .light: NSAppearance(named: .aqua)
        case .dark: NSAppearance(named: .darkAqua)
        }
    }

    var swiftUIAccentColor: Color { Color(nsColor: appKitAccentColor) }

    var appKitAccentColor: NSColor {
        if let customAccentColor {
            return NSColor(
                srgbRed: customAccentColor.red,
                green: customAccentColor.green,
                blue: customAccentColor.blue,
                alpha: customAccentColor.alpha
            )
        }
        return switch accent {
        case .system: NSColor.controlAccentColor
        case .blue: NSColor.systemBlue
        case .indigo: NSColor.systemIndigo
        case .purple: NSColor.systemPurple
        case .green: NSColor.systemGreen
        case .orange: NSColor.systemOrange
        case .pink: NSColor.systemPink
        }
    }

    var swiftUIBackgroundColor: Color { Color(nsColor: appKitBackgroundColor) }

    var appKitBackgroundColor: NSColor {
        switch backgroundColor {
        case .system: .windowBackgroundColor
        case .graphite: NSColor(srgbRed: 0.14, green: 0.15, blue: 0.17, alpha: 1)
        case .midnight: NSColor(srgbRed: 0.035, green: 0.065, blue: 0.11, alpha: 1)
        case .light: NSColor(srgbRed: 0.94, green: 0.95, blue: 0.97, alpha: 1)
        case .accent: appKitAccentColor
        }
    }

    var appKitTextColor: NSColor {
        switch theme {
        case .system: .labelColor
        case .light: NSColor(white: 0.1, alpha: 1)
        case .dark: NSColor(white: 0.96, alpha: 1)
        }
    }
}
