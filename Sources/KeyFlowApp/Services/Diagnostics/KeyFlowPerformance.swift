import Foundation
import OSLog

/// Opt-in signposts for Instruments. They are disabled by default so global-input
/// hot paths do not pay diagnostic overhead during ordinary use.
enum KeyFlowPerformance {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "app.keyflow.desktop"
    private static let isEnabled =
        ProcessInfo.processInfo.environment["KEYFLOW_PERFORMANCE_SIGNPOSTS"] == "1"

    static let audio = OSSignposter(subsystem: subsystem, category: "Performance.Audio")
    static let screenshots = OSSignposter(subsystem: subsystem, category: "Performance.Screenshots")
    static let windows = OSSignposter(subsystem: subsystem, category: "Performance.Windows")
    static let thumbnails = OSSignposter(subsystem: subsystem, category: "Performance.Thumbnails")

    static func begin(_ name: StaticString, using signposter: OSSignposter) -> KeyFlowPerformanceInterval {
        guard isEnabled else { return .disabled }
        return KeyFlowPerformanceInterval(
            name: name,
            signposter: signposter,
            state: signposter.beginInterval(name)
        )
    }
}

struct KeyFlowPerformanceInterval {
    fileprivate static let disabled = KeyFlowPerformanceInterval(name: "Disabled", signposter: nil, state: nil)

    private let name: StaticString
    private let signposter: OSSignposter?
    private let state: OSSignpostIntervalState?

    fileprivate init(
        name: StaticString,
        signposter: OSSignposter?,
        state: OSSignpostIntervalState?
    ) {
        self.name = name
        self.signposter = signposter
        self.state = state
    }

    func end() {
        guard let signposter, let state else { return }
        signposter.endInterval(name, state)
    }
}
