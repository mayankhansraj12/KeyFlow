import AppKit
import SwiftUI

@main
struct KeyFlowApp: App {
    @NSApplicationDelegateAdaptor(KeyFlowApplicationDelegate.self) private var applicationDelegate
    @StateObject private var model = AppModel()

    var body: some Scene {
        Window("KeyFlow", id: "main") {
            ContentView()
                .environmentObject(model)
                .task { await model.startIfNeeded() }
        }
        .defaultSize(width: 1040, height: 680)
        .commands {
            CommandGroup(after: .newItem) {
                Button("New Mapping") { model.addMapping() }
                    .keyboardShortcut("n", modifiers: [.command])
            }
        }

        Window("Sound Bar", id: "sound-bar-settings") {
            SoundBarSettingsView()
                .environmentObject(model)
        }
        .defaultSize(width: 700, height: 520)
        .windowResizability(.contentSize)

        MenuBarExtra("KeyFlow", systemImage: model.isPaused ? "pause.circle.fill" : "command.circle.fill") {
            KeyFlowMenu(model: model)
        }
    }
}

private struct KeyFlowMenu: View {
    @Environment(\.openWindow) private var openWindow
    @ObservedObject var model: AppModel

    var body: some View {
        Button("Open KeyFlow") { showMainWindow() }
        Divider()
        Toggle(
            "Pause All Mappings",
            isOn: Binding(get: { model.isPaused }, set: { model.setPaused($0) })
        )
        Text(engineStatusSummary)
        Divider()
        if let supportURL = KeyFlowExternalLinks.supportURL {
            Link("Support…", destination: supportURL)
        }
        if let privacyURL = KeyFlowExternalLinks.privacyPolicyURL {
            Link("Privacy Policy…", destination: privacyURL)
        }
        Divider()
        Button("Quit KeyFlow") { NSApp.terminate(nil) }
    }

    private func showMainWindow() {
        // Unlike searching NSApp.windows, this recreates the singleton scene
        // after its last window has been closed.
        openWindow(id: "main")
        DispatchQueue.main.async {
            NSApp.unhide(nil)
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    private var engineStatusSummary: String {
        switch model.engineStatus {
        case .running: "Keyboard engine running"
        case .starting: "Keyboard engine starting…"
        case let .permissionRequired(permission): "Permission required: \(permission)"
        case .stopped: "Keyboard engine stopped"
        case .failed: "Keyboard engine failed"
        }
    }
}

enum KeyFlowExternalLinks {
    static var supportURL: URL? { bundleURL(forKey: "KeyFlowSupportURL") }
    static var privacyPolicyURL: URL? { bundleURL(forKey: "KeyFlowPrivacyPolicyURL") }

    private static func bundleURL(forKey key: String) -> URL? {
        guard
            let value = Bundle.main.object(forInfoDictionaryKey: key) as? String,
            let url = URL(string: value),
            url.scheme == "https"
        else { return nil }
        return url
    }
}
