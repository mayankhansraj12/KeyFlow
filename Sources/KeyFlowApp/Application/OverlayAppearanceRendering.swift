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

    var swiftUIAccentColor: Color { Color(accent) }

    var appKitAccentColor: NSColor {
        switch accent {
        case .system: .controlAccentColor
        case .blue: .systemBlue
        case .indigo: .systemIndigo
        case .purple: .systemPurple
        case .green: .systemGreen
        case .orange: .systemOrange
        case .pink: .systemPink
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
