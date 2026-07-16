import AppKit
import KeyFlowCore
import SwiftUI

struct MappingsView: View {
    @EnvironmentObject private var model: AppModel
    @State private var selectedMappingID: UUID?

    private var shortcuts: [Mapping] {
        model.mappings.filter { $0.trigger.kind == .keyboard }
    }

    private var shortcutIDs: [UUID] {
        shortcuts.map(\.id)
    }

    var body: some View {
        NavigationSplitView {
            shortcutSidebar
                .navigationSplitViewColumnWidth(min: 240, ideal: 280, max: 340)
        } detail: {
            shortcutDetail
        }
        .navigationSplitViewStyle(.balanced)
        .onAppear(perform: reconcileSelection)
        .onChange(of: shortcutIDs) { _, _ in reconcileSelection() }
        .onChange(of: model.selectedMappingID) { _, newValue in
            guard let newValue, shortcutIDs.contains(newValue) else { return }
            selectedMappingID = newValue
        }
    }

    private var shortcutSidebar: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Shortcuts")
                        .font(.headline)
                    Text(shortcutCountLabel)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 8)
                Button(action: createShortcut) {
                    Image(systemName: "plus")
                        .frame(width: 22, height: 22)
                }
                .buttonStyle(.bordered)
                .help("Add application shortcut")
                .accessibilityLabel("Add Shortcut")
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)

            Divider()

            if shortcuts.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "keyboard")
                        .font(.title2)
                        .foregroundStyle(.tertiary)
                    Text("No shortcuts")
                        .font(.callout.weight(.medium))
                    Text("Add a keyboard shortcut to open an application.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                    Button("Add Shortcut", action: createShortcut)
                        .buttonStyle(.bordered)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(24)
            } else {
                List(shortcuts, selection: $selectedMappingID) { mapping in
                    ShortcutRow(
                        mapping: mapping,
                        hasConflict: model.conflictingMappingIDs.contains(mapping.id)
                    )
                    .tag(mapping.id)
                }
                .listStyle(.sidebar)
            }

            Divider()

            HStack {
                Text("Application launch shortcuts only")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Spacer(minLength: 8)
                Button(action: deleteSelectedShortcut) {
                    Image(systemName: "trash")
                        .frame(width: 22, height: 22)
                }
                .buttonStyle(.borderless)
                .disabled(selectedShortcut == nil)
                .help("Delete selected shortcut")
                .accessibilityLabel("Delete Shortcut")
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
        }
    }

    @ViewBuilder
    private var shortcutDetail: some View {
        if let mapping = selectedShortcut {
            ShortcutEditor(mappingID: mapping.id)
                .id(mapping.id)
        } else if shortcuts.isEmpty {
            ContentUnavailableView {
                Label("Create Your First Shortcut", systemImage: "keyboard.badge.ellipsis")
            } description: {
                Text("Record a keyboard combination and choose the application it should open.")
            } actions: {
                Button("Create Shortcut", action: createShortcut)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
            }
        } else {
            ContentUnavailableView {
                Label("Select a Shortcut", systemImage: "sidebar.left")
            } description: {
                Text("Choose a shortcut in the sidebar to configure it.")
            }
        }
    }

    private var shortcutCountLabel: String {
        shortcuts.count == 1 ? "1 shortcut" : "\(shortcuts.count) shortcuts"
    }

    private var selectedShortcut: Mapping? {
        guard let selectedMappingID else { return nil }
        return shortcuts.first { $0.id == selectedMappingID }
    }

    private func reconcileSelection() {
        if let selectedMappingID, shortcutIDs.contains(selectedMappingID) { return }
        if let modelSelection = model.selectedMappingID, shortcutIDs.contains(modelSelection) {
            selectedMappingID = modelSelection
        } else {
            selectedMappingID = shortcutIDs.first
        }
    }

    private func createShortcut() {
        model.addKeyboardMapping()
        selectedMappingID = model.selectedMappingID
    }

    private func deleteSelectedShortcut() {
        guard let selectedMappingID else { return }
        model.deleteMapping(id: selectedMappingID)
        self.selectedMappingID = model.selectedMappingID
        reconcileSelection()
    }
}

private struct ShortcutRow: View {
    let mapping: Mapping
    let hasConflict: Bool

    private var application: ApplicationSelection? {
        guard mapping.action.kind == .launchApplication else { return nil }
        return ApplicationSelection.resolve(storedValue: mapping.action.value)
    }

    private var hasValidationError: Bool {
        !MappingValidator.validate(mapping).isEmpty
    }

    var body: some View {
        HStack(spacing: 10) {
            applicationIcon(size: 30)

            VStack(alignment: .leading, spacing: 3) {
                Text(mapping.name)
                    .font(.callout.weight(.medium))
                    .lineLimit(1)
                Text(application?.name ?? "Choose an application")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 6)

            VStack(alignment: .trailing, spacing: 4) {
                Text(triggerLabel)
                    .font(.caption2.monospaced())
                    .lineLimit(1)
                    .frame(maxWidth: 74)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(.quaternary, in: RoundedRectangle(cornerRadius: 5, style: .continuous))
                statusIndicator
            }
        }
        .contentShape(Rectangle())
        .padding(.vertical, 4)
    }

    private var triggerLabel: String {
        mapping.trigger.keyCode == nil ? "Not set" : mapping.trigger.displayName
    }

    @ViewBuilder
    private var statusIndicator: some View {
        if hasConflict || hasValidationError {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.caption2)
                .foregroundStyle(.orange)
                .accessibilityLabel(hasConflict ? "Shortcut conflict" : "Shortcut needs attention")
        } else if !mapping.isEnabled {
            Text("Off")
                .font(.caption2)
                .foregroundStyle(.secondary)
        } else {
            Image(systemName: "checkmark.circle.fill")
                .font(.caption2)
                .foregroundStyle(.green)
                .accessibilityLabel("Enabled")
        }
    }

    @ViewBuilder
    private func applicationIcon(size: CGFloat) -> some View {
        Group {
            if let application {
                Image(nsImage: application.icon)
                    .resizable()
                    .interpolation(.high)
            } else {
                Image(systemName: "app.dashed")
                    .resizable()
                    .scaledToFit()
                    .padding(size * 0.18)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: size, height: size)
    }
}

private struct ShortcutEditor: View {
    @EnvironmentObject private var model: AppModel
    let mappingID: UUID

    private var mapping: Mapping? {
        model.mappings.first { $0.id == mappingID }
    }

    var body: some View {
        if let mapping {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    editorHeader(mapping)
                    shortcutSettings(mapping)
                    applicationSettings(mapping)
                    validationErrors(mapping)
                }
                .frame(maxWidth: 820, alignment: .leading)
                .padding(.horizontal, 30)
                .padding(.vertical, 26)
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }
            .background(Color(nsColor: .windowBackgroundColor))
        }
    }

    private func editorHeader(_ mapping: Mapping) -> some View {
        HStack(spacing: 14) {
            applicationIcon(mapping, size: 46)
            VStack(alignment: .leading, spacing: 3) {
                Text(mapping.name)
                    .font(.title2.weight(.semibold))
                    .lineLimit(1)
                Text("Open an application with a global keyboard shortcut")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 16)
            Toggle(
                "Enabled",
                isOn: binding(\.isEnabled, fallback: mapping.isEnabled)
            )
            .toggleStyle(.switch)
            .fixedSize()
        }
    }

    private func shortcutSettings(_ mapping: Mapping) -> some View {
        ShortcutSection(title: "Shortcut", systemImage: "keyboard") {
            VStack(spacing: 0) {
                ShortcutSettingRow(
                    title: "Name",
                    detail: "Shown in the sidebar and activity history."
                ) {
                    TextField("Shortcut name", text: binding(\.name, fallback: mapping.name))
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 280)
                }

                Divider().padding(.vertical, 14)

                ShortcutSettingRow(
                    title: "Keyboard combination",
                    detail: "Click the control, then press the keys you want to use."
                ) {
                    ShortcutRecorder(
                        shortcutLabel: mapping.trigger.displayName,
                        isRecording: model.isRecording,
                        onRecordingChanged: { model.setRecording($0) },
                        onCapture: { keyCode, modifiers in
                            model.updateMapping(id: mappingID) {
                                $0.trigger.keyCode = keyCode
                                $0.trigger.modifiers = modifiers
                            }
                        }
                    )
                    .frame(width: 230)
                }

                Divider().padding(.vertical, 14)

                ShortcutSettingRow(
                    title: "Suppress original shortcut",
                    detail: "Prevent this key combination from reaching the active application."
                ) {
                    Toggle(
                        "Suppress original shortcut",
                        isOn: binding(\.consumesKeyboardInput, fallback: mapping.consumesKeyboardInput)
                    )
                    .labelsHidden()
                    .toggleStyle(.switch)
                }
            }
        }
    }

    private func applicationSettings(_ mapping: Mapping) -> some View {
        let application =
            mapping.action.kind == .launchApplication
            ? ApplicationSelection.resolve(storedValue: mapping.action.value)
            : nil

        return ShortcutSection(title: "Application", systemImage: "app.badge") {
            VStack(spacing: 16) {
                HStack(spacing: 14) {
                    applicationIcon(mapping, size: 52)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(application?.name ?? "No application selected")
                            .font(.headline)
                        if let application {
                            Text(application.url.path)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                                .truncationMode(.middle)
                        } else {
                            Text("Choose an installed macOS application.")
                                .font(.callout)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Spacer(minLength: 16)

                    Button(application == nil ? "Choose Application…" : "Change…") {
                        model.chooseApplication(forMappingID: mappingID)
                    }
                }

                Divider()

                HStack(spacing: 12) {
                    Label(
                        "This shortcut only opens the selected application.",
                        systemImage: "lock.shield"
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    Spacer()
                    Button("Open Now") { model.testMapping(mapping) }
                        .disabled(
                            !MappingValidator.validate(mapping).isEmpty
                                || model.conflictingMappingIDs.contains(mapping.id)
                        )
                }
            }
        }
    }

    @ViewBuilder
    private func validationErrors(_ mapping: Mapping) -> some View {
        let errors = MappingValidator.validate(mapping)
        let hasConflict = model.conflictingMappingIDs.contains(mapping.id)
        if !errors.isEmpty || hasConflict {
            ShortcutSection(title: "Needs Attention", systemImage: "exclamationmark.triangle.fill") {
                VStack(alignment: .leading, spacing: 8) {
                    if hasConflict {
                        Label(
                            "Another enabled shortcut uses this key combination.",
                            systemImage: "exclamationmark.triangle.fill"
                        )
                    }
                    ForEach(Array(errors.enumerated()), id: \.offset) { _, error in
                        Label(error.localizedDescription, systemImage: "exclamationmark.triangle.fill")
                    }
                }
                .font(.callout)
                .foregroundStyle(.orange)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    @ViewBuilder
    private func applicationIcon(_ mapping: Mapping, size: CGFloat) -> some View {
        let application =
            mapping.action.kind == .launchApplication
            ? ApplicationSelection.resolve(storedValue: mapping.action.value)
            : nil
        Group {
            if let application {
                Image(nsImage: application.icon)
                    .resizable()
                    .interpolation(.high)
            } else {
                Image(systemName: "app.dashed")
                    .resizable()
                    .scaledToFit()
                    .padding(size * 0.2)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: size, height: size)
    }

    private func binding<Value>(_ keyPath: WritableKeyPath<Mapping, Value>, fallback: Value) -> Binding<Value> {
        Binding(
            get: { model.mappings.first(where: { $0.id == mappingID })?[keyPath: keyPath] ?? fallback },
            set: { value in model.updateMapping(id: mappingID) { $0[keyPath: keyPath] = value } }
        )
    }
}

private struct ShortcutSection<Content: View>: View {
    let title: String
    let systemImage: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                    .foregroundStyle(.secondary)
                    .frame(width: 18)
                Text(title)
                    .font(.headline)
                Spacer()
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 13)

            Divider()

            content
                .padding(18)
        }
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.72))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color(nsColor: .separatorColor).opacity(0.7), lineWidth: 1)
        }
    }
}

private struct ShortcutSettingRow<Control: View>: View {
    let title: String
    let detail: String
    @ViewBuilder let control: Control

    var body: some View {
        HStack(alignment: .center, spacing: 24) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.callout.weight(.medium))
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 16)
            control
        }
    }
}
