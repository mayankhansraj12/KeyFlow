import AppKit
import KeyFlowCore
import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        TabView {
            MappingsView()
                .tabItem { Label("Shortcuts", systemImage: "keyboard") }
            GestureSettingsView()
                .tabItem { Label("Gestures", systemImage: "hand.draw") }
            WindowSwitcherSettingsView()
                .tabItem { Label("Switcher", systemImage: "rectangle.3.group") }
            ActivityView()
                .tabItem { Label("Activity", systemImage: "waveform.path.ecg") }
            PermissionsView()
                .tabItem { Label("Permissions", systemImage: "lock.shield") }
        }
        .frame(minWidth: 860, minHeight: 560)
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            model.refreshPermissions()
        }
        .alert(
            "KeyFlow",
            isPresented: Binding(
                get: { model.errorMessage != nil },
                set: { if !$0 { model.errorMessage = nil } }
            )
        ) {
            Button("OK") { model.errorMessage = nil }
        } message: {
            Text(model.errorMessage ?? "Unknown error")
        }
    }
}
