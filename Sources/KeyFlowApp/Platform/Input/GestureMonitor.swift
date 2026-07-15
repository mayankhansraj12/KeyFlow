import Foundation
import KeyFlowCore

enum MultitouchProviderStatus: Equatable, Sendable {
    case starting
    case running
    case unavailable
    case failed
}

@MainActor
final class GestureMonitor {
    private var recognizer = MultifingerGestureRecognizer()
    private var provider: RawMultitouchProvider?
    private var lastReportedContactCount = -1
    private var contactLatch = GestureContactLatch()
    private var isPaused = false
    private var volumePreferences = VolumeAdjustmentPreferences.default

    var onGesture: ((TriggerKind) -> Void)?
    var onVerticalGesture: ((GestureRecognitionEvent) -> Void)?
    var onHorizontalGesture: ((GestureRecognitionEvent) -> Void)?
    var onProviderStatus: ((MultitouchProviderStatus) -> Void)?
    var onContactCountChanged: ((Int) -> Void)?
    var onGestureContactCountChanged: ((Int) -> Void)?

    func start() {
        guard provider == nil else { return }
        isPaused = false
        recognizer.reset()
        onProviderStatus?(.starting)

        let provider = RawMultitouchProvider { [weak self] frame in
            // The bridge callback is serial. Keep FIFO ordering when crossing
            // to the main actor so release can never overtake movement.
            DispatchQueue.main.async {
                MainActor.assumeIsolated {
                    self?.handle(frame)
                }
            }
        }
        self.provider = provider

        guard provider.isAvailable else {
            self.provider = nil
            onProviderStatus?(.unavailable)
            return
        }
        guard provider.start() else {
            self.provider = nil
            onProviderStatus?(.failed)
            return
        }
        onProviderStatus?(.running)
    }

    func stop() {
        provider?.stop()
        provider = nil
        cancelGestureIfNeeded()
        reportContactCount(0)
        updateGestureContactState(contactCount: 0)
    }

    func setPaused(_ paused: Bool) {
        isPaused = paused
        if paused {
            cancelGestureIfNeeded()
            reportContactCount(0)
            updateGestureContactState(contactCount: 0)
        }
    }

    func updateVolumePreferences(_ preferences: VolumeAdjustmentPreferences) {
        volumePreferences = preferences
    }

    func handlePhysicalClick(fingerCount: Int) {
        guard (3...5).contains(fingerCount) else { return }
        if let event = recognizer.suppressUntilRelease() {
            route(event)
        }
    }

    private func handle(_ frame: RawTouchFrame) {
        guard !isPaused else { return }
        // RawMultitouchProvider has already removed proximity and lingering contacts.
        // Avoid allocating another filtered array for every display-rate frame.
        let points = frame.points
        reportContactCount(points.count)
        updateGestureContactState(contactCount: points.count)

        let samples = points.map {
            TouchSample(identifier: $0.identifier, x: Double($0.x), y: Double($0.y))
        }
        for event in recognizer.process(
            points: samples,
            timestamp: frame.timestamp,
            verticalResponseMilliseconds: volumePreferences.responseMilliseconds
        ) {
            route(event)
        }
    }

    private func reportContactCount(_ count: Int) {
        guard count != lastReportedContactCount else { return }
        lastReportedContactCount = count
        onContactCountChanged?(count)
    }

    private func updateGestureContactState(contactCount: Int) {
        guard let latchedCount = contactLatch.update(contactCount: contactCount) else { return }
        onGestureContactCountChanged?(latchedCount)
    }

    private func cancelGestureIfNeeded() {
        if let event = recognizer.cancel() {
            route(event)
        }
    }

    private func route(_ event: GestureRecognitionEvent) {
        switch event {
        case let .discrete(gesture):
            onGesture?(gesture)
        case .verticalChanged, .verticalEnded, .verticalCancelled:
            onVerticalGesture?(event)
        case .horizontalBegan, .horizontalChanged, .horizontalEnded, .horizontalCancelled:
            onHorizontalGesture?(event)
        }
    }
}

struct GestureContactLatch {
    private(set) var activeFingerCount = 0

    mutating func update(contactCount: Int) -> Int? {
        if contactCount == 0 {
            guard activeFingerCount != 0 else { return nil }
            activeFingerCount = 0
            return 0
        }
        guard (3...5).contains(contactCount), contactCount > activeFingerCount else { return nil }
        activeFingerCount = contactCount
        return activeFingerCount
    }
}
