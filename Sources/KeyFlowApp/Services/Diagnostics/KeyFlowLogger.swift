import Foundation
import OSLog

enum KeyFlowLog {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "app.keyflow.desktop"

    static let application = Logger(subsystem: subsystem, category: "application")
    static let configuration = Logger(subsystem: subsystem, category: "configuration")
    static let input = Logger(subsystem: subsystem, category: "input")
    static let actions = Logger(subsystem: subsystem, category: "actions")
}
