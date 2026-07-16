import AppKit
import KeyFlowCore
import SwiftUI

struct ShortcutRecorder: NSViewRepresentable {
    let shortcutLabel: String
    let isRecording: Bool
    let onRecordingChanged: (Bool) -> Void
    let onCapture: (UInt16, ModifierKeys) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeNSView(context: Context) -> NSButton {
        let button = NSButton(
            title: shortcutLabel, target: context.coordinator, action: #selector(Coordinator.toggleRecording))
        button.bezelStyle = .rounded
        button.setButtonType(.momentaryPushIn)
        return button
    }

    func updateNSView(_ button: NSButton, context: Context) {
        context.coordinator.parent = self
        if !isRecording, context.coordinator.isMonitoring {
            context.coordinator.cancelRecording()
        }
        button.title = isRecording ? "Press shortcut… (Esc to cancel)" : shortcutLabel
    }

    static func dismantleNSView(_: NSButton, coordinator: Coordinator) {
        coordinator.cancelRecording()
    }

    @MainActor
    final class Coordinator: NSObject {
        var parent: ShortcutRecorder
        private var monitor: Any?

        var isMonitoring: Bool { monitor != nil }

        init(parent: ShortcutRecorder) {
            self.parent = parent
        }

        @objc func toggleRecording() {
            if monitor == nil { beginRecording() } else { finishRecording() }
        }

        private func beginRecording() {
            parent.onRecordingChanged(true)
            monitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { [weak self] event in
                guard let self else { return event }
                if event.keyCode == 53 {
                    finishRecording()
                    return nil
                }
                let modifiers = ModifierKeys(nsEventFlags: event.modifierFlags)
                parent.onCapture(event.keyCode, modifiers)
                finishRecording()
                return nil
            }
        }

        func cancelRecording() {
            finishRecording()
        }

        private func finishRecording() {
            guard monitor != nil else { return }
            if let monitor { NSEvent.removeMonitor(monitor) }
            monitor = nil
            parent.onRecordingChanged(false)
        }
    }
}

private extension ModifierKeys {
    init(nsEventFlags flags: NSEvent.ModifierFlags) {
        var value: ModifierKeys = []
        if flags.contains(.command) { value.insert(.command) }
        if flags.contains(.option) { value.insert(.option) }
        if flags.contains(.control) { value.insert(.control) }
        if flags.contains(.shift) { value.insert(.shift) }
        if flags.contains(.function) { value.insert(.function) }
        self = value
    }
}
