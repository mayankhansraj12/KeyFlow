import AppKit
import KeyFlowCore
import SwiftUI

struct PermissionsView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        Form {
            Section {
                PermissionRow(
                    title: "Accessibility",
                    detail:
                        "Required to suppress shortcuts, post keyboard events, type text, and raise selected windows.",
                    granted: model.accessibilityGranted && model.postEventGranted,
                    requestTitle: "Request Access",
                    request: { model.requestAccessibilityPermission() }
                )
                PermissionRow(
                    title: "Screen Recording (Optional)",
                    detail:
                        "Adds live window thumbnails to the interactive switcher. Window titles and app icons work without it.",
                    granted: model.screenRecordingGranted,
                    requestTitle: "Enable Thumbnails",
                    request: { model.requestScreenRecordingPermission() }
                )
                PermissionRow(
                    title: "Input Monitoring",
                    detail: "May be required by macOS to observe global keyboard and gesture input.",
                    granted: model.inputMonitoringGranted,
                    requestTitle: "Request Access",
                    request: { model.requestInputMonitoringPermission() }
                )
                Button("Refresh Permission Status", action: { model.refreshPermissions() })
                Button("Export Diagnostics…", action: { model.exportDiagnostics() })
                Text(
                    "Technical status — AX trusted: \(yesNo(model.accessibilityGranted)); event posting: \(yesNo(model.postEventGranted)); event listening: \(yesNo(model.inputMonitoringGranted)); thumbnails: \(yesNo(model.screenRecordingGranted))"
                )
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
                if !model.accessibilityGranted || !model.postEventGranted {
                    Button("Reset Stale Accessibility Entry…") {
                        model.resetAccessibilityRegistration()
                    }
                    .help(
                        "Removes only KeyFlow's Accessibility registration, then opens System Settings so the current build can be added again."
                    )
                }
                if !model.inputMonitoringGranted {
                    Button("Reset Stale Input Monitoring Entry…") {
                        model.resetInputMonitoringRegistration()
                    }
                    .help(
                        "Removes only KeyFlow's Input Monitoring registration, then opens System Settings so the current build can be added again."
                    )
                }
                if !model.screenRecordingGranted {
                    Button("Reset Stale Screen Recording Entry…") {
                        model.resetScreenRecordingRegistration()
                    }
                    .help("Removes only KeyFlow's Screen Recording registration, then opens System Settings.")
                }
                if !model.accessibilityGranted || !model.postEventGranted || !model.inputMonitoringGranted
                    || !model.screenRecordingGranted
                {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(
                            "After System Settings opens, enable KeyFlow in the requested list. Screen Recording is optional and only affects thumbnails. Return here and relaunch KeyFlow if macOS still shows the old state."
                        )
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        Button("Reveal KeyFlow.app in Finder") { model.revealApplicationInFinder() }
                    }
                    .padding(.vertical, 4)
                }
            } header: {
                Text("System permissions")
            }

            Section {
                LabeledContent("Keyboard engine") {
                    Label(engineStatusText, systemImage: engineStatusIcon)
                        .foregroundStyle(engineStatusColor)
                }
                LabeledContent("Raw multitouch engine") {
                    Label(multitouchStatusText, systemImage: multitouchStatusIcon)
                        .foregroundStyle(multitouchStatusColor)
                }
                Toggle(
                    "Launch KeyFlow at login",
                    isOn: Binding(get: { model.launchAtLoginEnabled }, set: { model.setLaunchAtLogin($0) })
                )
                Toggle(
                    "Hide KeyFlow from Dock",
                    isOn: Binding(
                        get: { model.applicationPreferences.hideFromDock },
                        set: { model.setHiddenFromDock($0) }
                    )
                )
                if model.dockVisibilityRequiresRelaunch {
                    HStack {
                        Label("Relaunch required to update Dock visibility", systemImage: "arrow.clockwise")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button("Relaunch KeyFlow") { model.relaunchToApplyDockVisibility() }
                            .buttonStyle(.borderedProminent)
                    }
                }
            } header: {
                Text("Runtime")
            } footer: {
                Text(
                    "When hidden from the Dock, KeyFlow remains available from its menu-bar item. Launch at login works from the packaged KeyFlow.app build."
                )
            }

            Section("Safety") {
                Toggle(
                    "Pause all mappings",
                    isOn: Binding(get: { model.isPaused }, set: { model.setPaused($0) })
                )
                Text(
                    "If a mapping behaves unexpectedly, use the KeyFlow menu-bar item to pause the engine. Input fails open if the event tap cannot run."
                )
                .font(.caption).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    private var engineStatusText: String {
        switch model.engineStatus {
        case .stopped: "Stopped"
        case .starting: "Starting"
        case .running: "Running — \(model.rawTouchContactCount) contacts"
        case let .permissionRequired(permission): "Permission required: \(permission)"
        case let .failed(message): "Failed: \(message)"
        }
    }

    private var engineStatusIcon: String {
        switch model.engineStatus {
        case .running: "checkmark.circle.fill"
        case .starting: "clock"
        case .stopped: "pause.circle"
        case .permissionRequired, .failed: "exclamationmark.triangle.fill"
        }
    }

    private var multitouchStatusText: String {
        switch model.multitouchStatus {
        case .starting: "Starting"
        case .running: "Running"
        case .unavailable: "Unavailable on this Mac"
        case .failed: "Could not start"
        }
    }

    private var multitouchStatusIcon: String {
        switch model.multitouchStatus {
        case .running: "checkmark.circle.fill"
        case .starting: "clock"
        case .unavailable, .failed: "exclamationmark.triangle.fill"
        }
    }

    private var multitouchStatusColor: Color {
        switch model.multitouchStatus {
        case .running: .green
        case .starting: .secondary
        case .unavailable, .failed: .orange
        }
    }

    private var engineStatusColor: Color {
        switch model.engineStatus {
        case .running: .green
        case .starting, .stopped: .secondary
        case .permissionRequired, .failed: .orange
        }
    }

    private func yesNo(_ value: Bool) -> String { value ? "yes" : "no" }
}

private struct PermissionRow: View {
    let title: String
    let detail: String
    let granted: Bool
    let requestTitle: String
    let request: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: granted ? "checkmark.shield.fill" : "exclamationmark.shield.fill")
                .font(.title2)
                .foregroundStyle(granted ? .green : .orange)
                .frame(width: 30)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).fontWeight(.medium)
                Text(detail).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            if granted {
                Text("Granted").foregroundStyle(.green)
            } else {
                Button(requestTitle, action: request)
            }
        }
        .padding(.vertical, 4)
    }
}
