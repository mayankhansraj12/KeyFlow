import AppKit
import ApplicationServices
import CoreGraphics
import Foundation

struct PermissionStatus: Equatable, Sendable {
    var accessibilityGranted: Bool
    var inputMonitoringGranted: Bool
    var postEventGranted: Bool
    var screenRecordingGranted: Bool
}

enum SystemPermission: Equatable, Sendable {
    case accessibility
    case inputMonitoring
    case screenRecording

    var tccService: String {
        switch self {
        case .accessibility: "Accessibility"
        case .inputMonitoring: "ListenEvent"
        case .screenRecording: "ScreenCapture"
        }
    }

    var settingsAnchor: String {
        switch self {
        case .accessibility: "Privacy_Accessibility"
        case .inputMonitoring: "Privacy_ListenEvent"
        case .screenRecording: "Privacy_ScreenCapture"
        }
    }
}

@MainActor
protocol PermissionServicing: AnyObject {
    func currentStatus() -> PermissionStatus
    func request(_ permission: SystemPermission)
    func resetRegistration(for permission: SystemPermission) async throws
    func openSettings(for permission: SystemPermission)
    func revealApplicationInFinder()
}

enum PermissionServiceError: LocalizedError {
    case resetFailed(String)

    var errorDescription: String? {
        switch self {
        case let .resetFailed(message): "Could not reset the permission registration: \(message)"
        }
    }
}

final class SystemPermissionService: PermissionServicing {
    func currentStatus() -> PermissionStatus {
        PermissionStatus(
            accessibilityGranted: AXIsProcessTrusted(),
            inputMonitoringGranted: CGPreflightListenEventAccess(),
            postEventGranted: CGPreflightPostEventAccess(),
            screenRecordingGranted: CGPreflightScreenCaptureAccess()
        )
    }

    func request(_ permission: SystemPermission) {
        switch permission {
        case .accessibility:
            AXIsProcessTrustedWithOptions(["AXTrustedCheckOptionPrompt": true] as CFDictionary)
            _ = CGRequestPostEventAccess()
            if !AXIsProcessTrusted() || !CGPreflightPostEventAccess() {
                openSettings(for: permission)
            }
        case .inputMonitoring:
            if !CGRequestListenEventAccess() {
                openSettings(for: permission)
            }
        case .screenRecording:
            if !CGRequestScreenCaptureAccess() {
                openSettings(for: permission)
            }
        }
    }

    func resetRegistration(for permission: SystemPermission) async throws {
        let bundleIdentifier = Bundle.main.bundleIdentifier ?? "app.keyflow.desktop"
        let result = await Task.detached(priority: .userInitiated) { () -> (Int32, String) in
            let process = Process()
            let errorPipe = Pipe()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/tccutil")
            process.arguments = ["reset", permission.tccService, bundleIdentifier]
            process.standardError = errorPipe
            do {
                try process.run()
                process.waitUntilExit()
                let data = errorPipe.fileHandleForReading.readDataToEndOfFile()
                return (process.terminationStatus, String(data: data, encoding: .utf8) ?? "")
            } catch {
                return (-1, error.localizedDescription)
            }
        }.value
        guard result.0 == 0 else { throw PermissionServiceError.resetFailed(result.1) }
    }

    func openSettings(for permission: SystemPermission) {
        let anchoredURL = URL(
            string: "x-apple.systempreferences:com.apple.preference.security?\(permission.settingsAnchor)"
        )
        let privacyURL = URL(string: "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension")
        if let anchoredURL, NSWorkspace.shared.open(anchoredURL) { return }
        if let privacyURL { NSWorkspace.shared.open(privacyURL) }
    }

    func revealApplicationInFinder() {
        NSWorkspace.shared.activateFileViewerSelecting([Bundle.main.bundleURL])
    }
}
