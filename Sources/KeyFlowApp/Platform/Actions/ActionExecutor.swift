import AppKit
import CoreGraphics
import Foundation
import KeyFlowCore

enum ActionExecutionError: LocalizedError {
    case invalidURL
    case applicationNotFound
    case eventCreationFailed
    case interactiveGestureRequired
    case screenshotFolderUnavailable
    case screenshotFailed(Int32)
    case screenshotOutputUnavailable

    var errorDescription: String? {
        switch self {
        case .invalidURL: "The URL is invalid."
        case .applicationNotFound: "The application could not be found. Use a bundle identifier or app path."
        case .eventCreationFailed: "macOS could not create a synthetic keyboard event."
        case .interactiveGestureRequired: "This action requires its interactive four-finger gesture."
        case .screenshotFolderUnavailable: "The selected screenshot folder is unavailable or is not a directory."
        case let .screenshotFailed(status): "The macOS screenshot tool failed with status \(status)."
        case .screenshotOutputUnavailable: "The screenshot was cancelled or did not produce an image."
        }
    }
}

@MainActor
protocol ActionExecuting: AnyObject {
    func execute(_ action: ActionDefinition, screenshotStorage: ScreenshotStorageSettings) async throws
    func executeContinuousVolume(_ action: ActionDefinition, stepCount: Int, stepPercentage: Int) throws
    func updateVolumeHUDAppearance(_ preferences: OverlayAppearancePreferences)
    func updateVolumeHUDPercentageAlignment(_ alignment: SoundBarPercentageAlignment)
    func previewVolumeHUD()
}

extension ActionExecuting {
    func execute(_ action: ActionDefinition) async throws {
        try await execute(action, screenshotStorage: .default)
    }

    func updateVolumeHUDAppearance(_: OverlayAppearancePreferences) {}
    func updateVolumeHUDPercentageAlignment(_: SoundBarPercentageAlignment) {}
    func previewVolumeHUD() {}
}

@MainActor
final class ActionExecutor: ActionExecuting {
    private let syntheticMarker: Int64
    private let volumeHUD = SystemVolumeHUDController()
    private var screenshotPasteboardProviders: [ScreenshotPasteboardFileProvider] = []

    private static let screenshotFilenameFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd 'at' HH.mm.ss.SSS"
        return formatter
    }()

    init(syntheticMarker: Int64) {
        self.syntheticMarker = syntheticMarker
        volumeHUD.prepare()
    }

    func updateVolumeHUDAppearance(_ preferences: OverlayAppearancePreferences) {
        volumeHUD.updateAppearance(preferences)
    }

    func updateVolumeHUDPercentageAlignment(_ alignment: SoundBarPercentageAlignment) {
        volumeHUD.updatePercentageAlignment(alignment)
    }

    func previewVolumeHUD() {
        // Exercise the widest percentage label in the on-screen appearance preview.
        volumeHUD.show(level: 1)
    }

    func execute(_ action: ActionDefinition, screenshotStorage: ScreenshotStorageSettings) async throws {
        switch action.kind {
        case .openURL:
            guard let url = URL(string: action.value), ["http", "https"].contains(url.scheme?.lowercased()) else {
                throw ActionExecutionError.invalidURL
            }
            guard NSWorkspace.shared.open(url) else { throw ActionExecutionError.invalidURL }

        case .launchApplication:
            let value = action.value.trimmingCharacters(in: .whitespacesAndNewlines)
            let url: URL?
            if value.hasPrefix("/") {
                url = URL(fileURLWithPath: value)
            } else {
                url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: value)
            }
            guard let url else { throw ActionExecutionError.applicationNotFound }
            let configuration = NSWorkspace.OpenConfiguration()
            configuration.activates = true
            _ = try await NSWorkspace.shared.openApplication(at: url, configuration: configuration)

        case .typeText:
            try typeText(action.value)

        case .volumeUp:
            try executeContinuousVolume(action, stepCount: 1, stepPercentage: 2)

        case .volumeDown:
            try executeContinuousVolume(action, stepCount: 1, stepPercentage: 2)

        case .toggleMute:
            let state = try SystemAudioController.toggleMute()
            volumeHUD.show(level: state.isMuted ? 0 : Double(state.volume))

        case .playPause:
            guard SystemMediaKeyController.press(.playPause) else {
                throw ActionExecutionError.eventCreationFailed
            }

        case .captureScreenshot:
            try await captureScreenshot(interactive: false, storage: screenshotStorage)

        case .captureSelectionScreenshot:
            try await captureScreenshot(interactive: true, storage: screenshotStorage)

        case .windowSwitcher:
            throw ActionExecutionError.interactiveGestureRequired
        }
    }

    func executeContinuousVolume(
        _ action: ActionDefinition,
        stepCount: Int,
        stepPercentage: Int
    ) throws {
        guard stepCount > 0 else { return }
        let volume: Float32
        switch action.kind {
        case .volumeUp:
            volume = try SystemAudioController.adjustVolume(
                up: true,
                stepCount: stepCount,
                stepPercentage: stepPercentage
            )
        case .volumeDown:
            volume = try SystemAudioController.adjustVolume(
                up: false,
                stepCount: stepCount,
                stepPercentage: stepPercentage
            )
        default:
            return
        }
        volumeHUD.show(level: Double(volume))
    }

    private func captureScreenshot(interactive: Bool, storage: ScreenshotStorageSettings) async throws {
        guard storage.saveAdditionalCopy else {
            try postScreenshotShortcut(interactive: interactive)
            return
        }
        let systemConfiguration = SystemScreenshotSettings.current()
        let path: String
        switch storage.mode {
        case .systemDefault:
            path = systemConfiguration.fileDirectory.path
        case .customFolder:
            guard let customPath = storage.customFolderPath?.trimmingCharacters(in: .whitespacesAndNewlines),
                !customPath.isEmpty
            else {
                throw ActionExecutionError.screenshotFolderUnavailable
            }
            path = customPath
        }
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory), isDirectory.boolValue else {
            throw ActionExecutionError.screenshotFolderUnavailable
        }

        let filename = "Screenshot \(Self.screenshotFilenameFormatter.string(from: .now)).png"
        let outputURL = URL(fileURLWithPath: path, isDirectory: true).appendingPathComponent(filename)

        switch systemConfiguration.target {
        case .clipboard:
            // Capture once into the requested additional-copy location and advertise
            // that encoded PNG lazily on the clipboard. The old route captured to the
            // clipboard and immediately copied the full-resolution pasteboard payload
            // back through KeyFlow, producing a large transient CPU/memory spike.
            var arguments = ["-t", "png"]
            if interactive { arguments.append("-i") }
            arguments.append(outputURL.path)
            let status = try await runScreenshotTool(arguments: arguments)
            guard status == 0 else { throw ActionExecutionError.screenshotFailed(status) }
            let capturedURLs = try capturedFiles(for: outputURL)
            publishFilesToPasteboard(capturedURLs)
            return

        case .file:
            let captureStartedAt = Date()
            let previousDirectoryModificationDate = try directoryModificationDate(
                systemConfiguration.fileDirectory
            )
            try postScreenshotShortcut(interactive: interactive)
            let sourceURLs = try await waitForNewScreenshotFiles(
                in: systemConfiguration.fileDirectory,
                capturedAfter: captureStartedAt,
                previousDirectoryModificationDate: previousDirectoryModificationDate,
                timeout: interactive ? 90 : 12
            )
            try await Task.detached(priority: .utility) {
                for (index, sourceURL) in sourceURLs.enumerated() {
                    let destinationBase =
                        index == 0
                        ? outputURL
                        : outputURL.deletingPathExtension()
                            .appendingPathExtension("\(index + 1).png")
                    let sourceExtension = sourceURL.pathExtension.isEmpty ? "png" : sourceURL.pathExtension
                    let destination = destinationBase.deletingPathExtension()
                        .appendingPathExtension(sourceExtension)
                    try FileManager.default.copyItem(at: sourceURL, to: destination)
                }
            }.value
            return

        case .preview, .mail, .messages:
            break
        }

        var arguments = ["-t", "png"]
        if interactive {
            arguments.append("-i")
        }
        arguments.append(outputURL.path)

        let status = try await runScreenshotTool(arguments: arguments)
        guard status == 0 else { throw ActionExecutionError.screenshotFailed(status) }
        let capturedURLs = try capturedFiles(for: outputURL)
        try await deliverToMacOSDestination(
            capturedURLs,
            savedDirectory: outputURL.deletingLastPathComponent(),
            configuration: systemConfiguration
        )
    }

    private func postScreenshotShortcut(interactive: Bool) throws {
        try postShortcut(
            keyCode: interactive ? 21 : 20,
            modifiers: [.maskCommand, .maskShift]
        )
    }

    private func waitForNewScreenshotFiles(
        in directory: URL,
        capturedAfter startedAt: Date,
        previousDirectoryModificationDate: Date?,
        timeout: TimeInterval
    ) async throws -> [URL] {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            let currentModificationDate = try directoryModificationDate(directory)
            if currentModificationDate != previousDirectoryModificationDate {
                // The directory notification arrives while screencapture may still be
                // finalizing multi-display files. Debounce once, then enumerate once.
                try await Task.sleep(for: .milliseconds(120))
                let files = try imageFiles(in: directory, modifiedAfter: startedAt.addingTimeInterval(-0.25))
                if !files.isEmpty {
                    return files.sorted { $0.lastPathComponent < $1.lastPathComponent }
                }
            }
            // `stat`-ing the directory is constant-time. The old implementation rebuilt
            // the complete screenshot-file set every 200 ms while waiting.
            try await Task.sleep(for: .milliseconds(50))
        }
        throw ActionExecutionError.screenshotOutputUnavailable
    }

    private func directoryModificationDate(_ directory: URL) throws -> Date? {
        try FileManager.default.attributesOfItem(atPath: directory.path)[.modificationDate] as? Date
    }

    private func imageFiles(in directory: URL, modifiedAfter: Date? = nil) throws -> [URL] {
        let extensions: Set<String> = ["png", "jpg", "jpeg", "tiff", "pdf", "heic"]
        return try FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.contentModificationDateKey, .creationDateKey],
            options: [.skipsHiddenFiles]
        ).filter { url in
            guard extensions.contains(url.pathExtension.lowercased()) else { return false }
            guard let modifiedAfter else { return true }
            guard let values = try? url.resourceValues(forKeys: [.contentModificationDateKey, .creationDateKey])
            else { return false }
            return (values.creationDate ?? values.contentModificationDate ?? .distantPast) >= modifiedAfter
                || (values.contentModificationDate ?? .distantPast) >= modifiedAfter
        }
    }

    private func capturedFiles(for outputURL: URL) throws -> [URL] {
        if FileManager.default.fileExists(atPath: outputURL.path) { return [outputURL] }
        let directory = outputURL.deletingLastPathComponent()
        let stem = outputURL.deletingPathExtension().lastPathComponent
        let matches = try FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ).filter {
            $0.pathExtension.caseInsensitiveCompare("png") == .orderedSame
                && $0.deletingPathExtension().lastPathComponent.hasPrefix(stem)
        }.sorted { $0.lastPathComponent < $1.lastPathComponent }
        guard !matches.isEmpty else { throw ActionExecutionError.screenshotOutputUnavailable }
        return matches
    }

    private func publishFilesToPasteboard(_ urls: [URL]) {
        let providers = urls.map(ScreenshotPasteboardFileProvider.init(fileURL:))
        let items = providers.map { provider in
            let item = NSPasteboardItem()
            item.setDataProvider(provider, forTypes: [.png])
            return item
        }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.writeObjects(items)
        // AppKit calls the providers later, when another application requests the
        // clipboard bytes. Retain only the current clipboard generation.
        screenshotPasteboardProviders = providers
    }

    private func deliverToMacOSDestination(
        _ capturedURLs: [URL],
        savedDirectory: URL,
        configuration: SystemScreenshotConfiguration
    ) async throws {
        switch configuration.target {
        case .clipboard:
            let images = capturedURLs.compactMap(NSImage.init(contentsOf:))
            guard images.count == capturedURLs.count else {
                throw ActionExecutionError.screenshotOutputUnavailable
            }
            NSPasteboard.general.clearContents()
            guard NSPasteboard.general.writeObjects(images) else {
                throw ActionExecutionError.screenshotOutputUnavailable
            }

        case .file:
            guard savedDirectory.standardizedFileURL != configuration.fileDirectory.standardizedFileURL else {
                return
            }
            var isDirectory: ObjCBool = false
            guard
                FileManager.default.fileExists(
                    atPath: configuration.fileDirectory.path,
                    isDirectory: &isDirectory
                ),
                isDirectory.boolValue
            else {
                throw ActionExecutionError.screenshotFolderUnavailable
            }
            for source in capturedURLs {
                let destination = configuration.fileDirectory.appendingPathComponent(source.lastPathComponent)
                try FileManager.default.copyItem(at: source, to: destination)
            }

        case .preview:
            guard let previewURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.Preview")
            else {
                throw ActionExecutionError.applicationNotFound
            }
            let openConfiguration = NSWorkspace.OpenConfiguration()
            openConfiguration.arguments = capturedURLs.map(\.path)
            openConfiguration.activates = true
            _ = try await NSWorkspace.shared.openApplication(at: previewURL, configuration: openConfiguration)

        case .mail:
            guard let service = NSSharingService(named: .composeEmail) else {
                throw ActionExecutionError.applicationNotFound
            }
            service.perform(withItems: capturedURLs)

        case .messages:
            guard let service = NSSharingService(named: .composeMessage) else {
                throw ActionExecutionError.applicationNotFound
            }
            service.perform(withItems: capturedURLs)
        }
    }

    private func runScreenshotTool(arguments: [String]) async throws -> Int32 {
        try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
            process.arguments = arguments
            process.terminationHandler = { completed in
                continuation.resume(returning: completed.terminationStatus)
            }
            do {
                try process.run()
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    private func typeText(_ text: String) throws {
        for character in text {
            let utf16 = Array(String(character).utf16)
            guard
                let down = CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: true),
                let up = CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: false)
            else { throw ActionExecutionError.eventCreationFailed }

            down.setIntegerValueField(.eventSourceUserData, value: syntheticMarker)
            up.setIntegerValueField(.eventSourceUserData, value: syntheticMarker)
            down.keyboardSetUnicodeString(stringLength: utf16.count, unicodeString: utf16)
            up.keyboardSetUnicodeString(stringLength: utf16.count, unicodeString: utf16)
            down.post(tap: .cgSessionEventTap)
            up.post(tap: .cgSessionEventTap)
        }
    }

    private func postShortcut(keyCode: CGKeyCode, modifiers: CGEventFlags) throws {
        guard
            let down = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: true),
            let up = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: false)
        else { throw ActionExecutionError.eventCreationFailed }
        down.flags = modifiers
        up.flags = modifiers
        down.setIntegerValueField(.eventSourceUserData, value: syntheticMarker)
        up.setIntegerValueField(.eventSourceUserData, value: syntheticMarker)
        down.post(tap: .cghidEventTap)
        up.post(tap: .cghidEventTap)
    }
}

private final class ScreenshotPasteboardFileProvider: NSObject, NSPasteboardItemDataProvider {
    private let fileURL: URL

    init(fileURL: URL) {
        self.fileURL = fileURL
    }

    func pasteboard(
        _ pasteboard: NSPasteboard?,
        item: NSPasteboardItem,
        provideDataForType type: NSPasteboard.PasteboardType
    ) {
        guard type == .png, let data = try? Data(contentsOf: fileURL, options: .mappedIfSafe) else { return }
        item.setData(data, forType: .png)
    }

    func pasteboardFinishedWithDataProvider(_ pasteboard: NSPasteboard) {}
}
