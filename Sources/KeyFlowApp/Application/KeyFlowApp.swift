import AppKit
import SwiftUI

@main
struct KeyFlowApp: App {
    @StateObject private var model = AppModel()

    var body: some Scene {
        WindowGroup("KeyFlow", id: "main") {
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

        MenuBarExtra("KeyFlow", systemImage: model.isPaused ? "pause.circle.fill" : "command.circle.fill") {
            Button("Open KeyFlow") { model.openMainWindow() }
            Divider()
            Toggle(
                "Pause All Mappings",
                isOn: Binding(get: { model.isPaused }, set: { model.setPaused($0) })
            )
            Text(engineStatusSummary)
            Divider()
            Button("Quit KeyFlow") { NSApp.terminate(nil) }
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
