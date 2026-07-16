import AppKit
import CoreGraphics
import IOKit

@MainActor
protocol MediaKeyControlling: AnyObject {
    func pressPlayPause() -> Bool
}

@MainActor
final class SystemMediaKeyController: MediaKeyControlling {
    enum Key {
        case playPause

        var nxKeyType: Int32 {
            switch self {
            case .playPause: Int32(NX_KEYTYPE_PLAY)
            }
        }
    }

    func pressPlayPause() -> Bool {
        press(.playPause)
    }

    private func press(_ key: Key) -> Bool {
        guard post(key, isDown: true) else { return false }
        return post(key, isDown: false)
    }

    private func post(_ key: Key, isDown: Bool) -> Bool {
        let state = isDown ? 0xA : 0xB
        let modifierFlags = NSEvent.ModifierFlags(rawValue: UInt(state << 8))
        let data1 = Int((key.nxKeyType << 16) | Int32(state << 8))
        guard
            let event = NSEvent.otherEvent(
                with: .systemDefined,
                location: .zero,
                modifierFlags: modifierFlags,
                timestamp: ProcessInfo.processInfo.systemUptime,
                windowNumber: 0,
                context: nil,
                subtype: 8,
                data1: data1,
                data2: -1
            ),
            let cgEvent = event.cgEvent
        else { return false }
        cgEvent.post(tap: CGEventTapLocation.cghidEventTap)
        return true
    }
}
