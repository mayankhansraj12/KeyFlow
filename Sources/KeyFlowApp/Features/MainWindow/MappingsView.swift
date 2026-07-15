import AppKit
import KeyFlowCore
import SwiftUI

struct MappingsView: View {
    @EnvironmentObject private var model: AppModel
    @State private var selectedMappingID: UUID?

    private var shortcuts: [Mapping] {
        model.mappings.filter { $0.trigger.kind == .keyboard }
    }

    var body: some View {
        NavigationSplitView {
            VStack(spacing: 0) {
                HStack {
                    Text("Keyboard Shortcuts")
                        .font(.headline)
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)

                Divider()

                List(shortcuts, selection: $selectedMappingID) { mapping in
                    ShortcutRow(
                        mapping: mapping,
                        hasConflict: model.conflictingMappingIDs.contains(mapping.id)
                    )
                    .tag(mapping.id)
                }
                .listStyle(.sidebar)

                Divider()

                HStack {
                    Button(action: createShortcut) {
                        Label("Add Shortcut", systemImage: "plus")
                    }
                    .buttonStyle(.borderless)
                    Spacer()
                    Button(action: deleteSelectedShortcut) {
                        Image(systemName: "trash")
                    }
                    .buttonStyle(.borderless)
                    .disabled(selectedShortcut == nil)
                    .help("Delete selected shortcut")
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
            }
            .navigationSplitViewColumnWidth(min: 220, ideal: 270, max: 340)
        } detail: {
            if let mapping = selectedShortcut {
                ShortcutEditor(mappingID: mapping.id)
            } else {
                ContentUnavailableView {
                    Label("No Shortcuts Yet", systemImage: "keyboard")
                } description: {
                    Text("Connect a keyboard shortcut to an action.")
                } actions: {
                    Button("Create Shortcut", action: createShortcut)
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                }
            }
        }
        .onAppear {
            if selectedShortcut == nil { selectedMappingID = shortcuts.first?.id }
        }
        .onChange(of: model.selectedMappingID) { _, newValue in
            guard let newValue, shortcuts.contains(where: { $0.id == newValue }) else { return }
            selectedMappingID = newValue
        }
    }

    private var selectedShortcut: Mapping? {
        guard let selectedMappingID else { return nil }
        return shortcuts.first { $0.id == selectedMappingID }
    }

    private func createShortcut() {
        model.addKeyboardMapping()
        selectedMappingID = model.selectedMappingID
    }

    private func deleteSelectedShortcut() {
        guard let selectedMappingID else { return }
        model.deleteMapping(id: selectedMappingID)
        self.selectedMappingID = shortcuts.first?.id
    }
}

private struct ShortcutRow: View {
    let mapping: Mapping
    let hasConflict: Bool

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "keyboard")
                .foregroundStyle(mapping.isEnabled ? Color.accentColor : Color.secondary)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 3) {
                Text(mapping.name).lineLimit(1)
                Text(mapping.trigger.displayName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            if hasConflict {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
            } else if !mapping.isEnabled {
                Text("Off").font(.caption2).foregroundStyle(.secondary)
            } else if !MappingValidator.validate(mapping).isEmpty {
                Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
            }
        }
        .padding(.vertical, 3)
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
                VStack(alignment: .leading, spacing: 24) {
                    HStack {
                        TextField("Shortcut name", text: binding(\.name, fallback: mapping.name))
                            .font(.title2.weight(.semibold))
                            .textFieldStyle(.plain)
                        Toggle("Enabled", isOn: binding(\.isEnabled, fallback: mapping.isEnabled))
                            .toggleStyle(.switch)
                    }

                    GroupBox("Keyboard Trigger") {
                        VStack(alignment: .leading, spacing: 14) {
                            LabeledContent("Shortcut") {
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
                                .frame(width: 220)
                            }
                            Toggle(
                                "Prevent the original shortcut from reaching the active app",
                                isOn: binding(\.consumesKeyboardInput, fallback: mapping.consumesKeyboardInput)
                            )
                        }
                        .padding(8)
                    }

                    actionEditor(mapping)
                    validationErrors(mapping)
                }
                .padding(28)
                .frame(maxWidth: 760, alignment: .leading)
            }
            .navigationTitle(mapping.name)
        }
    }

    private func actionEditor(_ mapping: Mapping) -> some View {
        GroupBox("Action") {
            VStack(alignment: .leading, spacing: 14) {
                Picker("Action", selection: actionKindBinding(mapping)) {
                    ForEach(ActionKind.allCases.filter { $0 != .windowSwitcher }) { kind in
                        Text(kind.displayName).tag(kind)
                    }
                }
                if mapping.action.kind == .typeText {
                    TextEditor(text: actionValueBinding(mapping))
                        .font(.body.monospaced())
                        .frame(minHeight: 100)
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(.quaternary))
                } else if mapping.action.kind.requiresValue {
                    TextField(
                        mapping.action.kind.valueLabel,
                        text: actionValueBinding(mapping),
                        prompt: Text(mapping.action.kind.example)
                    )
                } else {
                    Label("No additional configuration required.", systemImage: "checkmark.circle")
                        .foregroundStyle(.secondary)
                }
                HStack {
                    Spacer()
                    Button("Test Action") { model.testMapping(mapping) }
                        .keyboardShortcut(.return, modifiers: [.command])
                        .disabled(
                            !MappingValidator.validate(mapping).isEmpty
                                || model.conflictingMappingIDs.contains(mapping.id)
                        )
                }
            }
            .padding(8)
        }
    }

    @ViewBuilder
    private func validationErrors(_ mapping: Mapping) -> some View {
        let errors = MappingValidator.validate(mapping)
        let hasConflict = model.conflictingMappingIDs.contains(mapping.id)
        if !errors.isEmpty || hasConflict {
            GroupBox("Needs Attention") {
                VStack(alignment: .leading, spacing: 6) {
                    if hasConflict {
                        Label(
                            "Another enabled shortcut uses this key combination.",
                            systemImage: "exclamationmark.triangle.fill"
                        )
                        .foregroundStyle(.orange)
                    }
                    ForEach(Array(errors.enumerated()), id: \.offset) { _, error in
                        Label(error.localizedDescription, systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(4)
            }
        }
    }

    private func binding<Value>(_ keyPath: WritableKeyPath<Mapping, Value>, fallback: Value) -> Binding<Value> {
        Binding(
            get: { model.mappings.first(where: { $0.id == mappingID })?[keyPath: keyPath] ?? fallback },
            set: { value in model.updateMapping(id: mappingID) { $0[keyPath: keyPath] = value } }
        )
    }

    private func actionKindBinding(_ mapping: Mapping) -> Binding<ActionKind> {
        Binding(
            get: { model.mappings.first(where: { $0.id == mappingID })?.action.kind ?? mapping.action.kind },
            set: { kind in
                model.updateMapping(id: mappingID) {
                    $0.action = .init(kind: kind, value: kind.requiresValue ? kind.example : "")
                }
            }
        )
    }

    private func actionValueBinding(_ mapping: Mapping) -> Binding<String> {
        Binding(
            get: { model.mappings.first(where: { $0.id == mappingID })?.action.value ?? mapping.action.value },
            set: { value in model.updateMapping(id: mappingID) { $0.action.value = value } }
        )
    }
}
