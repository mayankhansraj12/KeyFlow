import ApplicationServices
import CoreGraphics
import Foundation
import KeyFlowCore

enum KeyboardEngineStatus: Equatable, Sendable {
    case stopped
    case starting
    case running
    case permissionRequired(String)
    case failed(String)
}

final class KeyboardEngine: @unchecked Sendable {
    private let lock = NSLock()
    private var snapshot = RuntimeSnapshot(configuration: .init())
    private var paused = false
    private var gestureContactCount = 0
    private var suppressNextMouseUp = false
    private var eventTap: CFMachPort?
    private var runLoop: CFRunLoop?
    private var thread: Thread?

    private let executionQueue = DispatchQueue(label: "app.keyflow.action-dispatch", qos: .userInteractive)
    private let syntheticMarker: Int64
    private let onMatch: @Sendable (Mapping) -> Void
    private let onStatus: @Sendable (KeyboardEngineStatus) -> Void
    private let onGestureClick: @Sendable (Int) -> Void

    init(
        syntheticMarker: Int64,
        onMatch: @escaping @Sendable (Mapping) -> Void,
        onStatus: @escaping @Sendable (KeyboardEngineStatus) -> Void,
        onGestureClick: @escaping @Sendable (Int) -> Void
    ) {
        self.syntheticMarker = syntheticMarker
        self.onMatch = onMatch
        self.onStatus = onStatus
        self.onGestureClick = onGestureClick
    }

    func update(snapshot: RuntimeSnapshot) {
        lock.withLock { self.snapshot = snapshot }
    }

    func setPaused(_ paused: Bool) {
        lock.withLock { self.paused = paused }
    }

    func setGestureContactCount(_ count: Int) {
        lock.withLock { gestureContactCount = count }
    }

    func start() {
        guard lock.withLock({ thread == nil }) else { return }
        onStatus(.starting)
        let worker = Thread { [weak self] in
            self?.runEventLoop()
        }
        worker.name = "KeyFlow Keyboard Event Tap"
        worker.qualityOfService = .userInteractive
        lock.withLock { thread = worker }
        worker.start()
    }

    func stop() {
        let loop = lock.withLock { () -> CFRunLoop? in
            let current = runLoop
            runLoop = nil
            thread = nil
            return current
        }
        if let loop { CFRunLoopStop(loop) }
        onStatus(.stopped)
    }

    private func runEventLoop() {
        let gestureEventTypeValues: [UInt32] = [18, 19, 20, 29, 30, 31, 32]
        let mask = gestureEventTypeValues.reduce(
            CGEventMask(1 << CGEventType.keyDown.rawValue)
                | CGEventMask(1 << CGEventType.leftMouseDown.rawValue)
                | CGEventMask(1 << CGEventType.leftMouseUp.rawValue)
        ) { partial, eventType in
            partial | CGEventMask(1 << eventType)
        }
        guard
            let tap = CGEvent.tapCreate(
                tap: .cgSessionEventTap,
                place: .headInsertEventTap,
                options: .defaultTap,
                eventsOfInterest: mask,
                callback: keyFlowEventTapCallback,
                userInfo: Unmanaged.passUnretained(self).toOpaque()
            )
        else {
            lock.withLock { thread = nil }
            var missingPermissions: [String] = []
            if !AXIsProcessTrusted() || !CGPreflightPostEventAccess() {
                missingPermissions.append("Accessibility/Event Control")
            }
            if !CGPreflightListenEventAccess() {
                missingPermissions.append("Input Monitoring")
            }
            if missingPermissions.isEmpty {
                onStatus(.failed("macOS rejected the keyboard event tap even though permission preflight passed."))
            } else {
                onStatus(.permissionRequired(missingPermissions.joined(separator: " and ")))
            }
            return
        }

        let currentLoop = CFRunLoopGetCurrent()
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        lock.withLock {
            eventTap = tap
            runLoop = currentLoop
        }
        CFRunLoopAddSource(currentLoop, source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        onStatus(.running)
        CFRunLoopRun()
        CFRunLoopRemoveSource(currentLoop, source, .commonModes)
        lock.withLock {
            eventTap = nil
            if runLoop === currentLoop { runLoop = nil }
        }
    }

    func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap = lock.withLock({ eventTap }) {
                CGEvent.tapEnable(tap: tap, enable: true)
            }
            return Unmanaged.passUnretained(event)
        }

        if type == .leftMouseUp {
            let shouldSuppress = lock.withLock { () -> Bool in
                defer { suppressNextMouseUp = false }
                return suppressNextMouseUp
            }
            return shouldSuppress ? nil : Unmanaged.passUnretained(event)
        }

        let state = lock.withLock { (snapshot, paused, gestureContactCount) }
        let gestureEventTypeValues: Set<UInt32> = [18, 19, 20, 29, 30, 31, 32]
        if gestureEventTypeValues.contains(type.rawValue),
            state.2 > 0,
            state.0.suppressesSystemGestures(fingerCount: state.2),
            !state.1
        {
            return nil
        }

        guard event.getIntegerValueField(.eventSourceUserData) != syntheticMarker else {
            return Unmanaged.passUnretained(event)
        }

        guard !state.1 else { return Unmanaged.passUnretained(event) }

        if type == .leftMouseDown, let clickTrigger = clickTrigger(fingerCount: state.2) {
            onGestureClick(state.2)
            if let mapping = state.0.matchGesture(clickTrigger) {
                lock.withLock { suppressNextMouseUp = true }
                executionQueue.async { [onMatch] in onMatch(mapping) }
                return nil
            }
        }

        guard type == .keyDown else { return Unmanaged.passUnretained(event) }

        let keyCode = UInt16(event.getIntegerValueField(.keyboardEventKeycode))
        let modifiers = ModifierKeys(cgEventFlags: event.flags)
        guard let mapping = state.0.matchKeyboard(keyCode: keyCode, modifiers: modifiers) else {
            return Unmanaged.passUnretained(event)
        }

        executionQueue.async { [onMatch] in onMatch(mapping) }
        return mapping.consumesKeyboardInput ? nil : Unmanaged.passUnretained(event)
    }

    private func clickTrigger(fingerCount: Int) -> TriggerKind? {
        switch fingerCount {
        case 3: .threeFingerClick
        case 4: .fourFingerClick
        case 5: .fiveFingerClick
        default: nil
        }
    }
}

private let keyFlowEventTapCallback: CGEventTapCallBack = { _, type, event, userInfo in
    guard let userInfo else { return Unmanaged.passUnretained(event) }
    let engine = Unmanaged<KeyboardEngine>.fromOpaque(userInfo).takeUnretainedValue()
    return engine.handle(type: type, event: event)
}

extension ModifierKeys {
    init(cgEventFlags flags: CGEventFlags) {
        var value: ModifierKeys = []
        if flags.contains(.maskCommand) { value.insert(.command) }
        if flags.contains(.maskAlternate) { value.insert(.option) }
        if flags.contains(.maskControl) { value.insert(.control) }
        if flags.contains(.maskShift) { value.insert(.shift) }
        if flags.contains(.maskSecondaryFn) { value.insert(.function) }
        self = value
    }
}
