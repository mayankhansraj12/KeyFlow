import Foundation

enum SystemScreenshotTarget: Equatable, Sendable {
    case file
    case clipboard
    case preview
    case mail
    case messages
}

struct SystemScreenshotConfiguration: Equatable, Sendable {
    let target: SystemScreenshotTarget
    let fileDirectory: URL
    let description: String
}

enum SystemScreenshotSettings {
    static func current(
        homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser
    ) -> SystemScreenshotConfiguration {
        let applicationID = "com.apple.screencapture" as CFString
        let target =
            CFPreferencesCopyValue(
                "target" as CFString,
                applicationID,
                kCFPreferencesCurrentUser,
                kCFPreferencesAnyHost
            ) as? String
        let location =
            CFPreferencesCopyValue(
                "location" as CFString,
                applicationID,
                kCFPreferencesCurrentUser,
                kCFPreferencesAnyHost
            ) as? String
        return configuration(target: target, location: location, homeDirectory: homeDirectory)
    }

    static func destinationDescription() -> String { current().description }

    static func configuration(
        target: String? = nil,
        location: String?,
        homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser
    ) -> SystemScreenshotConfiguration {
        let fileDirectory = resolvedFileDirectory(location: location, homeDirectory: homeDirectory)
        switch target?.lowercased() {
        case "clipboard":
            return .init(
                target: .clipboard,
                fileDirectory: fileDirectory,
                description: "Clipboard — image remains ready to paste"
            )
        case "mail":
            return .init(target: .mail, fileDirectory: fileDirectory, description: "Mail — new message")
        case "messages":
            return .init(target: .messages, fileDirectory: fileDirectory, description: "Messages — new message")
        case "preview":
            return .init(target: .preview, fileDirectory: fileDirectory, description: "Preview — opens automatically")
        default:
            let name = fileDirectory.lastPathComponent.isEmpty ? fileDirectory.path : fileDirectory.lastPathComponent
            return .init(
                target: .file,
                fileDirectory: fileDirectory,
                description: "\(name) — \(fileDirectory.path)"
            )
        }
    }

    private static func resolvedFileDirectory(location: String?, homeDirectory: URL) -> URL {
        guard let location = location?.trimmingCharacters(in: .whitespacesAndNewlines), !location.isEmpty else {
            return homeDirectory.appendingPathComponent("Desktop", isDirectory: true).standardizedFileURL
        }
        let expandedPath: String
        if location == "~" {
            expandedPath = homeDirectory.path
        } else if location.hasPrefix("~/") {
            expandedPath = homeDirectory.appendingPathComponent(String(location.dropFirst(2))).path
        } else {
            expandedPath = location
        }
        return URL(fileURLWithPath: expandedPath, isDirectory: true).standardizedFileURL
    }
}
