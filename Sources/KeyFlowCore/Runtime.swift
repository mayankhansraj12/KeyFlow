import Foundation

public struct RuntimeSnapshot: Sendable {
    public let revision: Int
    public let keyboardMappings: [Mapping]
    public let gestureMappings: [TriggerKind: [Mapping]]
    public let volumePreferences: VolumeAdjustmentPreferences

    public init(configuration: KeyFlowConfiguration) {
        revision = configuration.revision
        volumePreferences = configuration.gestureSettings.volumePreferences
        let conflictIDs = MappingCollectionValidator.conflictingMappingIDs(in: configuration.mappings)
        keyboardMappings = configuration.mappings.filter {
            $0.isEnabled && MappingValidator.validate($0).isEmpty
                && !conflictIDs.contains($0.id)
                && $0.trigger.kind == .keyboard
        }

        let gestureMappings = RuntimeSnapshot.builtInGestureMappings(from: configuration.gestureSettings)
        self.gestureMappings = Dictionary(grouping: gestureMappings) {
            $0.trigger.kind
        }
    }

    public func matchKeyboard(keyCode: UInt16, modifiers: ModifierKeys) -> Mapping? {
        keyboardMappings.first {
            $0.trigger.keyCode == keyCode
                && $0.trigger.modifiers.intersection(.supportedMask) == modifiers.intersection(.supportedMask)
        }
    }

    public func matchGesture(_ kind: TriggerKind) -> Mapping? {
        gestureMappings[kind]?.first
    }

    public func hasGestureMapping(fingerCount: Int) -> Bool {
        gestureMappings.keys.contains { $0.fingerCount == fingerCount }
    }

    public func suppressesSystemGestures(fingerCount: Int) -> Bool {
        gestureMappings.keys.contains {
            $0.fingerCount == fingerCount
                && [
                    .threeFingerSwipeUp, .threeFingerSwipeDown,
                    .fourFingerSwipeUp, .fourFingerSwipeDown,
                    .fiveFingerSwipeUp, .fiveFingerSwipeDown,
                    .fourFingerHorizontalSwipe,
                ].contains($0)
        }
    }

    private static func builtInGestureMappings(from settings: GestureSettings) -> [Mapping] {
        var mappings: [Mapping] = []
        let conflicts = settings.conflictingFeatures
        if settings.volumeAdjustment.isEnabled,
            settings.volumeAdjustment.trigger.isAvailableForVolumeAdjustment
        {
            mappings.append(
                builtInMapping(
                    id: BuiltInMappingID.volumeUp,
                    name: "Volume Up",
                    trigger: settings.volumeAdjustment.trigger.upTrigger,
                    action: .volumeUp
                )
            )
            mappings.append(
                builtInMapping(
                    id: BuiltInMappingID.volumeDown,
                    name: "Volume Down",
                    trigger: settings.volumeAdjustment.trigger.downTrigger,
                    action: .volumeDown
                )
            )
        }
        if settings.mute.isEnabled, !conflicts.contains(.mute) {
            mappings.append(
                builtInMapping(
                    id: BuiltInMappingID.mute,
                    name: "Mute / Unmute",
                    trigger: settings.mute.trigger.triggerKind,
                    action: .toggleMute
                )
            )
        }
        if settings.playPause.isEnabled, !conflicts.contains(.playPause) {
            mappings.append(
                builtInMapping(
                    id: BuiltInMappingID.playPause,
                    name: "Play / Pause",
                    trigger: settings.playPause.trigger.triggerKind,
                    action: .playPause
                )
            )
        }
        if settings.screenshot.isEnabled, !conflicts.contains(.screenshot) {
            mappings.append(
                builtInMapping(
                    id: BuiltInMappingID.screenshot,
                    name: "Screenshot",
                    trigger: settings.screenshot.trigger.triggerKind,
                    action: .captureScreenshot
                )
            )
        }
        if settings.customScreenshot.isEnabled, !conflicts.contains(.customScreenshot) {
            mappings.append(
                builtInMapping(
                    id: BuiltInMappingID.customScreenshot,
                    name: "Custom Screenshot",
                    trigger: settings.customScreenshot.trigger.triggerKind,
                    action: .captureSelectionScreenshot
                )
            )
        }
        if settings.interactiveWindowSwitcherEnabled {
            mappings.append(
                builtInMapping(
                    id: BuiltInMappingID.windowSwitcher,
                    name: "Interactive Window Switcher",
                    trigger: .fourFingerHorizontalSwipe,
                    action: .windowSwitcher
                )
            )
        }
        return mappings
    }

    private static func builtInMapping(
        id: UUID,
        name: String,
        trigger: TriggerKind,
        action: ActionKind
    ) -> Mapping {
        Mapping(
            id: id,
            name: name,
            isEnabled: true,
            trigger: .init(kind: trigger),
            action: .init(kind: action, value: "")
        )
    }
}

private enum BuiltInMappingID {
    static let volumeUp = UUID(uuidString: "A36CC60A-A4A0-48BC-B91D-000000000001") ?? UUID()
    static let volumeDown = UUID(uuidString: "A36CC60A-A4A0-48BC-B91D-000000000002") ?? UUID()
    static let playPause = UUID(uuidString: "A36CC60A-A4A0-48BC-B91D-000000000003") ?? UUID()
    static let screenshot = UUID(uuidString: "A36CC60A-A4A0-48BC-B91D-000000000004") ?? UUID()
    static let customScreenshot = UUID(uuidString: "A36CC60A-A4A0-48BC-B91D-000000000005") ?? UUID()
    static let windowSwitcher = UUID(uuidString: "A36CC60A-A4A0-48BC-B91D-000000000006") ?? UUID()
    static let mute = UUID(uuidString: "A36CC60A-A4A0-48BC-B91D-000000000007") ?? UUID()
}

public enum WindowSelectionResolver {
    public static func index(
        translationX: Double,
        windowCount: Int,
        initialIndex: Int = 0,
        activationDistance: Double = 0.055,
        stepDistance: Double = 0.075
    ) -> Int {
        guard windowCount > 0 else { return 0 }
        guard abs(translationX) >= activationDistance else {
            return min(max(initialIndex, 0), windowCount - 1)
        }
        let additionalDistance = max(0, abs(translationX) - activationDistance)
        let steps = 1 + Int(additionalDistance / stepDistance)
        let signedSteps = translationX < 0 ? -steps : steps
        return min(max(initialIndex + signedSteps, 0), windowCount - 1)
    }
}

public struct TouchSample: Sendable {
    public let identifier: Int32
    public let x: Double
    public let y: Double

    public init(identifier: Int32, x: Double, y: Double) {
        self.identifier = identifier
        self.x = x
        self.y = y
    }
}

public enum GestureRecognitionEvent: Equatable, Sendable {
    case discrete(TriggerKind)
    case verticalChanged(fingerCount: Int, deltaY: Double)
    case verticalEnded
    case verticalCancelled
    case horizontalBegan(translationX: Double, translationY: Double)
    case horizontalChanged(translationX: Double, translationY: Double)
    case horizontalEnded(translationX: Double, translationY: Double)
    case horizontalCancelled
}

public struct MultifingerGestureRecognizer: Sendable {
    private struct Point: Sendable {
        let x: Double
        let y: Double
    }

    private struct Candidate: Sendable {
        enum Mode: Sendable {
            case undecided
            case vertical
            case horizontal
        }

        let startedAt: TimeInterval
        let initialPositions: [Int32: Point]
        let initialCentroid: Point
        var latestCentroid: Point
        var maximumFingerMovement: Double
        var lastInteractiveCentroid: Point
        var mode: Mode
    }

    private var candidate: Candidate?
    private var lockedUntilRelease = false

    public init() {}

    public mutating func reset() {
        candidate = nil
        lockedUntilRelease = false
    }

    public mutating func cancel() -> GestureRecognitionEvent? {
        let result: GestureRecognitionEvent? =
            switch candidate?.mode {
            case .horizontal: .horizontalCancelled
            case .vertical: .verticalCancelled
            case .undecided, nil: nil
            }
        reset()
        return result
    }

    public mutating func suppressUntilRelease() -> GestureRecognitionEvent? {
        let result: GestureRecognitionEvent? =
            switch candidate?.mode {
            case .horizontal: .horizontalCancelled
            case .vertical: .verticalCancelled
            case .undecided, nil: nil
            }
        candidate = nil
        lockedUntilRelease = true
        return result
    }

    public mutating func process(
        points samples: [TouchSample],
        timestamp: TimeInterval,
        verticalResponseMilliseconds: Int = 0
    ) -> [GestureRecognitionEvent] {
        if samples.isEmpty {
            let result = candidate.map { finish($0, timestamp: timestamp) } ?? []
            reset()
            return result
        }

        guard !lockedUntilRelease else { return [] }
        guard samples.allSatisfy({ $0.x.isFinite && $0.y.isFinite }) else {
            let result = cancellationEvents(for: candidate)
            candidate = nil
            lockedUntilRelease = true
            return result
        }
        guard samples.count <= 5 else {
            let result = cancellationEvents(for: candidate)
            candidate = nil
            lockedUntilRelease = true
            return result
        }

        if (3...5).contains(samples.count) {
            let positions = Dictionary(
                uniqueKeysWithValues: samples.map {
                    ($0.identifier, Point(x: $0.x, y: $0.y))
                })
            let center = centroid(Array(positions.values))
            guard var current = candidate else {
                candidate = makeCandidate(positions: positions, center: center, timestamp: timestamp)
                return []
            }

            if positions.count > current.initialPositions.count,
                current.mode == .undecided,
                current.maximumFingerMovement < 0.025
            {
                candidate = makeCandidate(positions: positions, center: center, timestamp: timestamp)
                return []
            }

            if positions.count < current.initialPositions.count {
                // Fingers commonly lift one at a time. Preserve the candidate
                // until the final contact releases so tap and horizontal end
                // semantics are based on the complete gesture.
                return []
            }

            guard positions.keys.count == current.initialPositions.keys.count,
                positions.keys.allSatisfy({ current.initialPositions[$0] != nil })
            else {
                let result = cancellationEvents(for: current)
                candidate = nil
                lockedUntilRelease = true
                return result
            }

            let previousCentroid = current.latestCentroid
            current.latestCentroid = center
            for (identifier, position) in positions {
                guard let initial = current.initialPositions[identifier] else { continue }
                current.maximumFingerMovement = max(
                    current.maximumFingerMovement,
                    hypot(position.x - initial.x, position.y - initial.y)
                )
            }
            let overallX = current.latestCentroid.x - current.initialCentroid.x
            let overallY = current.latestCentroid.y - current.initialCentroid.y

            if current.mode == .horizontal {
                let movementSinceLastEvent = hypot(
                    current.latestCentroid.x - current.lastInteractiveCentroid.x,
                    current.latestCentroid.y - current.lastInteractiveCentroid.y
                )
                let changedEnough = movementSinceLastEvent >= 0.003
                if changedEnough {
                    current.lastInteractiveCentroid = current.latestCentroid
                }
                candidate = current
                return changedEnough
                    ? [.horizontalChanged(translationX: overallX, translationY: overallY)]
                    : []
            }

            if current.mode == .vertical {
                let deltaY = current.latestCentroid.y - previousCentroid.y
                candidate = current
                guard abs(deltaY) >= 0.001 else { return [] }
                return [.verticalChanged(fingerCount: current.initialPositions.count, deltaY: deltaY)]
            }

            if current.initialPositions.count == 4,
                current.mode == .undecided,
                abs(overallX) >= 0.008,
                abs(overallX) > abs(overallY) * 1.25
            {
                current.mode = .horizontal
                current.lastInteractiveCentroid = current.latestCentroid
                candidate = current
                return [.horizontalBegan(translationX: overallX, translationY: overallY)]
            }

            let responseDelay = Double(min(max(verticalResponseMilliseconds, 0), 500)) / 1_000
            if abs(overallY) >= 0.006,
                abs(overallY) > abs(overallX) * 1.25,
                current.mode == .undecided,
                timestamp - current.startedAt >= responseDelay
            {
                current.mode = .vertical
                candidate = current
                return [
                    .verticalChanged(
                        fingerCount: current.initialPositions.count,
                        deltaY: overallY
                    )
                ]
            }
            candidate = current
            return []
        }

        // Do not commit when the first finger leaves the surface. Raw multitouch frames
        // frequently transition through one-to-three active contacts both because fingers
        // lift at slightly different times and because an individual contact can briefly
        // leave the touching state. The gesture ends only when every contact has lifted.
        return []
    }

    private func finish(_ candidate: Candidate, timestamp: TimeInterval) -> [GestureRecognitionEvent] {
        switch candidate.mode {
        case .horizontal:
            return [
                .horizontalEnded(
                    translationX: candidate.latestCentroid.x - candidate.initialCentroid.x,
                    translationY: candidate.latestCentroid.y - candidate.initialCentroid.y
                )
            ]
        case .vertical:
            return [.verticalEnded]
        case .undecided:
            break
        }
        let duration = timestamp - candidate.startedAt
        if duration <= 0.55,
            candidate.maximumFingerMovement <= 0.05,
            let trigger = tapTrigger(fingerCount: candidate.initialPositions.count)
        {
            return [.discrete(trigger)]
        }
        return []
    }

    private func centroid(_ points: [Point]) -> Point {
        let sums = points.reduce((x: 0.0, y: 0.0)) { ($0.x + $1.x, $0.y + $1.y) }
        return Point(x: sums.x / Double(points.count), y: sums.y / Double(points.count))
    }

    private func makeCandidate(
        positions: [Int32: Point],
        center: Point,
        timestamp: TimeInterval
    ) -> Candidate {
        Candidate(
            startedAt: timestamp,
            initialPositions: positions,
            initialCentroid: center,
            latestCentroid: center,
            maximumFingerMovement: 0,
            lastInteractiveCentroid: center,
            mode: .undecided
        )
    }

    private func cancellationEvents(for candidate: Candidate?) -> [GestureRecognitionEvent] {
        switch candidate?.mode {
        case .horizontal: [.horizontalCancelled]
        case .vertical: [.verticalCancelled]
        case .undecided, nil: []
        }
    }

    private func tapTrigger(fingerCount: Int) -> TriggerKind? {
        switch fingerCount {
        case 3: .threeFingerTap
        case 4: .fourFingerTap
        case 5: .fiveFingerTap
        default: nil
        }
    }
}
