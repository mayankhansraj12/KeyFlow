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

@MainActor
protocol PermissionSystemAccessing: AnyObject {
    var bundleIdentifier: String { get }
    var applicationURL: URL { get }
    func accessibilityGranted() -> Bool
    func inputMonitoringGranted() -> Bool
    func postEventGranted() -> Bool
    func screenRecordingGranted() -> Bool
    func requestAccessibility()
    func requestInputMonitoring() -> Bool
    func requestPostEvent() -> Bool
    func requestScreenRecording() -> Bool
    func reset(service: String, bundleIdentifier: String) async -> (status: Int32, error: String)
    func open(_ url: URL) -> Bool
    func revealInFinder(_ url: URL)
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
    private let system: any PermissionSystemAccessing

    init(system: (any PermissionSystemAccessing)? = nil) {
        self.system = system ?? SystemPermissionAccess()
    }

    func currentStatus() -> PermissionStatus {
        PermissionStatus(
            accessibilityGranted: system.accessibilityGranted(),
            inputMonitoringGranted: system.inputMonitoringGranted(),
            postEventGranted: system.postEventGranted(),
            screenRecordingGranted: system.screenRecordingGranted()
        )
    }

    func request(_ permission: SystemPermission) {
        switch permission {
        case .accessibility:
            system.requestAccessibility()
            _ = system.requestPostEvent()
            if !system.accessibilityGranted() || !system.postEventGranted() {
                openSettings(for: permission)
            }
        case .inputMonitoring:
            if !system.requestInputMonitoring() {
                openSettings(for: permission)
            }
        case .screenRecording:
            if !system.requestScreenRecording() {
                openSettings(for: permission)
            }
        }
    }

    func resetRegistration(for permission: SystemPermission) async throws {
        let result = await system.reset(
            service: permission.tccService,
            bundleIdentifier: system.bundleIdentifier
        )
        guard result.status == 0 else { throw PermissionServiceError.resetFailed(result.error) }
    }

    func openSettings(for permission: SystemPermission) {
        let anchoredURL = URL(
            string: "x-apple.systempreferences:com.apple.preference.security?\(permission.settingsAnchor)"
        )
        let privacyURL = URL(string: "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension")
        if let anchoredURL, system.open(anchoredURL) { return }
        if let privacyURL { _ = system.open(privacyURL) }
    }

    func revealApplicationInFinder() {
        system.revealInFinder(system.applicationURL)
    }
}

@MainActor
final class SystemPermissionAccess: PermissionSystemAccessing {
    var bundleIdentifier: String { Bundle.main.bundleIdentifier ?? "app.keyflow.desktop" }
    var applicationURL: URL { Bundle.main.bundleURL }

    func accessibilityGranted() -> Bool { AXIsProcessTrusted() }
    func inputMonitoringGranted() -> Bool { CGPreflightListenEventAccess() }
    func postEventGranted() -> Bool { CGPreflightPostEventAccess() }
    func screenRecordingGranted() -> Bool { CGPreflightScreenCaptureAccess() }
    func requestAccessibility() {
        AXIsProcessTrustedWithOptions(["AXTrustedCheckOptionPrompt": true] as CFDictionary)
    }
    func requestInputMonitoring() -> Bool { CGRequestListenEventAccess() }
    func requestPostEvent() -> Bool { CGRequestPostEventAccess() }
    func requestScreenRecording() -> Bool { CGRequestScreenCaptureAccess() }

    func reset(service: String, bundleIdentifier: String) async -> (status: Int32, error: String) {
        await Task.detached(priority: .userInitiated) { () -> (Int32, String) in
            let process = Process()
            let errorPipe = Pipe()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/tccutil")
            process.arguments = ["reset", service, bundleIdentifier]
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
    }

    func open(_ url: URL) -> Bool { NSWorkspace.shared.open(url) }
    func revealInFinder(_ url: URL) { NSWorkspace.shared.activateFileViewerSelecting([url]) }
}
