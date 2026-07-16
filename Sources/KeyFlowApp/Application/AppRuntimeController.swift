import Foundation
import KeyFlowCore

@MainActor
protocol RuntimeControlling: AnyObject {
    var onMapping: ((Mapping) -> Void)? { get set }
    var onKeyboardStatus: ((KeyboardEngineStatus) -> Void)? { get set }
    var onMultitouchStatus: ((MultitouchProviderStatus) -> Void)? { get set }
    var onContactCountChanged: ((Int) -> Void)? { get set }
    var onContinuousVolume: ((Mapping, Int) -> Void)? { get set }
    var onContinuousVolumeEnded: ((Mapping) -> Void)? { get set }
    var onInteractiveWindowSwitcher: ((Mapping, GestureRecognitionEvent) -> Void)? { get set }

    func start()
    func stop()
    func update(snapshot: RuntimeSnapshot)
    func setPaused(_ paused: Bool)
}

@MainActor
final class AppRuntimeController: RuntimeControlling {
    var onMapping: ((Mapping) -> Void)?
    var onKeyboardStatus: ((KeyboardEngineStatus) -> Void)?
    var onMultitouchStatus: ((MultitouchProviderStatus) -> Void)?
    var onContactCountChanged: ((Int) -> Void)?
    var onContinuousVolume: ((Mapping, Int) -> Void)?
    var onContinuousVolumeEnded: ((Mapping) -> Void)?
    var onInteractiveWindowSwitcher: ((Mapping, GestureRecognitionEvent) -> Void)?

    private lazy var keyboardEngine = KeyboardEngine(
        syntheticMarker: syntheticMarker,
        onMatch: { [weak self] mapping in
            Task { @MainActor in self?.onMapping?(mapping) }
        },
        onStatus: { [weak self] status in
            Task { @MainActor in self?.onKeyboardStatus?(status) }
        },
        onGestureClick: { [weak self] fingerCount in
            DispatchQueue.main.sync {
                MainActor.assumeIsolated {
                    self?.gestureMonitor.handlePhysicalClick(fingerCount: fingerCount)
                }
            }
        }
    )

    private lazy var gestureMonitor: GestureMonitor = {
        let monitor = GestureMonitor()
        monitor.onGesture = { [weak self] kind in self?.receiveGesture(kind) }
        monitor.onVerticalGesture = { [weak self] event in self?.receiveVerticalGesture(event) }
        monitor.onHorizontalGesture = { [weak self] event in self?.receiveHorizontalGesture(event) }
        monitor.onProviderStatus = { [weak self] status in self?.onMultitouchStatus?(status) }
        monitor.onContactCountChanged = { [weak self] count in self?.onContactCountChanged?(count) }
        monitor.onGestureContactCountChanged = { [weak self] count in
            self?.keyboardEngine.setGestureContactCount(count)
        }
        return monitor
    }()

    private let syntheticMarker: Int64
    private var snapshot = RuntimeSnapshot(configuration: .init())
    private var paused = false
    private var activeWindowSwitcherMapping: Mapping?
    private var activeVolumeMapping: Mapping?
    private var volumeGestureAccumulator = VerticalVolumeAccumulator()

    init(syntheticMarker: Int64) {
        self.syntheticMarker = syntheticMarker
    }

    func start() {
        keyboardEngine.start()
        gestureMonitor.start()
    }

    func stop() {
        keyboardEngine.stop()
        gestureMonitor.stop()
    }

    func update(snapshot: RuntimeSnapshot) {
        if let activeWindowSwitcherMapping,
            snapshot.matchGesture(.fourFingerHorizontalSwipe)?.id != activeWindowSwitcherMapping.id
        {
            onInteractiveWindowSwitcher?(activeWindowSwitcherMapping, .horizontalCancelled)
            self.activeWindowSwitcherMapping = nil
        }
        self.snapshot = snapshot
        volumeGestureAccumulator.reset()
        activeVolumeMapping = nil
        gestureMonitor.updateVolumePreferences(snapshot.volumePreferences)
        keyboardEngine.update(snapshot: snapshot)
    }

    func setPaused(_ paused: Bool) {
        self.paused = paused
        if paused {
            if let activeWindowSwitcherMapping {
                onInteractiveWindowSwitcher?(activeWindowSwitcherMapping, .horizontalCancelled)
                self.activeWindowSwitcherMapping = nil
            }
            volumeGestureAccumulator.reset()
            activeVolumeMapping = nil
        }
        keyboardEngine.setPaused(paused)
        gestureMonitor.setPaused(paused)
    }

    func receiveGesture(_ kind: TriggerKind) {
        guard !paused else { return }
        if let mapping = snapshot.matchGesture(kind) {
            onMapping?(mapping)
        }
    }

    func receiveVerticalGesture(_ event: GestureRecognitionEvent) {
        guard !paused else { return }
        if case .verticalEnded = event {
            if let activeVolumeMapping { onContinuousVolumeEnded?(activeVolumeMapping) }
            activeVolumeMapping = nil
            volumeGestureAccumulator.reset()
            return
        }
        if case .verticalCancelled = event {
            activeVolumeMapping = nil
            volumeGestureAccumulator.reset()
            return
        }
        for adjustment in volumeGestureAccumulator.process(
            event,
            preferences: snapshot.volumePreferences
        ) {
            guard let mapping = snapshot.matchGesture(adjustment.trigger) else { continue }
            activeVolumeMapping = mapping
            onContinuousVolume?(mapping, adjustment.stepCount)
        }
    }

    func receiveHorizontalGesture(_ event: GestureRecognitionEvent) {
        guard !paused else { return }
        switch event {
        case .horizontalBegan:
            guard
                let mapping = snapshot.matchGesture(.fourFingerHorizontalSwipe),
                mapping.action.kind == .windowSwitcher
            else { return }
            activeWindowSwitcherMapping = mapping
            onInteractiveWindowSwitcher?(mapping, event)
        case .horizontalChanged:
            guard let mapping = activeWindowSwitcherMapping else { return }
            onInteractiveWindowSwitcher?(mapping, event)
        case .horizontalEnded, .horizontalCancelled:
            guard let mapping = activeWindowSwitcherMapping else { return }
            onInteractiveWindowSwitcher?(mapping, event)
            activeWindowSwitcherMapping = nil
        case .discrete, .verticalChanged, .verticalEnded, .verticalCancelled:
            break
        }
    }
}

struct VerticalVolumeAccumulator {
    private var activeFingerCount: Int?
    private var remainder = 0.0

    mutating func reset() {
        activeFingerCount = nil
        remainder = 0
    }

    mutating func process(
        _ event: GestureRecognitionEvent,
        preferences: VolumeAdjustmentPreferences = .default
    ) -> [VolumeGestureAdjustment] {
        switch event {
        case let .verticalChanged(fingerCount, deltaY):
            guard (4...5).contains(fingerCount), deltaY.isFinite else {
                reset()
                return []
            }
            if activeFingerCount != fingerCount {
                activeFingerCount = fingerCount
                remainder = 0
            }
            remainder += deltaY
            let movementPerStep = preferences.movementPerStep
            let stepCount = Int(abs(remainder) / movementPerStep)
            guard stepCount > 0 else { return [] }
            guard let trigger = trigger(fingerCount: fingerCount, movesUp: remainder > 0) else {
                return []
            }
            remainder -= (remainder > 0 ? 1 : -1) * movementPerStep * Double(stepCount)
            return [.init(trigger: trigger, stepCount: stepCount)]

        case .verticalEnded, .verticalCancelled:
            reset()
            return []

        case .discrete, .horizontalBegan, .horizontalChanged, .horizontalEnded, .horizontalCancelled:
            return []
        }
    }

    private func trigger(fingerCount: Int, movesUp: Bool) -> TriggerKind? {
        switch (fingerCount, movesUp) {
        case (4, true): .fourFingerSwipeUp
        case (4, false): .fourFingerSwipeDown
        case (5, true): .fiveFingerSwipeUp
        case (5, false): .fiveFingerSwipeDown
        default: nil
        }
    }
}

struct VolumeGestureAdjustment: Equatable {
    let trigger: TriggerKind
    let stepCount: Int
}
