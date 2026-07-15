import AppKit
import Foundation
import KeyFlowCore

struct DiagnosticsSnapshot: Sendable {
    let appVersion: String
    let appBuild: String
    let configurationSchema: Int
    let configurationRevision: Int
    let mappingCount: Int
    let enabledMappingCount: Int
    let keyboardStatus: String
    let multitouchStatus: String
    let accessibilityGranted: Bool
    let inputMonitoringGranted: Bool
    let postEventGranted: Bool
    let screenRecordingGranted: Bool
}

@MainActor
protocol DiagnosticsExporting: AnyObject {
    func export(_ snapshot: DiagnosticsSnapshot) throws -> URL?
}

@MainActor
final class SystemDiagnosticsExporter: DiagnosticsExporting {
    func export(_ snapshot: DiagnosticsSnapshot) throws -> URL? {
        let panel = NSSavePanel()
        panel.title = "Export KeyFlow Diagnostics"
        panel.nameFieldStringValue = "KeyFlow-Diagnostics.txt"
        panel.canCreateDirectories = true
        guard panel.runModal() == .OK, let url = panel.url else { return nil }
        try DiagnosticsReportBuilder.build(snapshot).write(to: url, atomically: true, encoding: .utf8)
        return url
    }
}

enum DiagnosticsReportBuilder {
    static func build(_ snapshot: DiagnosticsSnapshot) -> String {
        """
        KeyFlow Diagnostics
        Generated: \(ISO8601DateFormatter().string(from: Date()))

        Application
        Version: \(snapshot.appVersion) (\(snapshot.appBuild))
        Bundle identifier: \(Bundle.main.bundleIdentifier ?? "unknown")
        macOS: \(ProcessInfo.processInfo.operatingSystemVersionString)
        Architecture: \(architecture)

        Configuration
        Schema: \(snapshot.configurationSchema)
        Revision: \(snapshot.configurationRevision)
        Mappings: \(snapshot.mappingCount)
        Enabled mappings: \(snapshot.enabledMappingCount)

        Runtime
        Keyboard: \(snapshot.keyboardStatus)
        Multitouch: \(snapshot.multitouchStatus)

        Permissions
        Accessibility: \(yesNo(snapshot.accessibilityGranted))
        Input Monitoring: \(yesNo(snapshot.inputMonitoringGranted))
        Event Posting: \(yesNo(snapshot.postEventGranted))
        Screen Recording: \(yesNo(snapshot.screenRecordingGranted))

        Mapping names, triggers, action values, and typed text are intentionally excluded.
        """
    }

    private static var architecture: String {
        #if arch(arm64)
            "arm64"
        #elseif arch(x86_64)
            "x86_64"
        #else
            "unknown"
        #endif
    }

    private static func yesNo(_ value: Bool) -> String { value ? "granted" : "not granted" }
}
