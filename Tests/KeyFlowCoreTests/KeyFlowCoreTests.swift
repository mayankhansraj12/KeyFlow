import Foundation
import Testing

@testable import KeyFlowCore

@Suite("KeyFlow domain")
struct KeyFlowCoreTests {
    @Test("Configuration round-trips through Codable")
    func configurationRoundTrip() throws {
        let timestamp = Date(timeIntervalSince1970: 1_700_000_000)
        let mapping = Mapping(
            name: "Open docs",
            isEnabled: true,
            trigger: .init(kind: .keyboard, keyCode: 2, modifiers: [.command, .shift]),
            action: .init(kind: .openURL, value: "https://example.com/docs"),
            createdAt: timestamp,
            updatedAt: timestamp
        )
        var gestureSettings = GestureSettings.default
        gestureSettings.screenshotStorage = .init(
            saveAdditionalCopy: true,
            mode: .customFolder,
            customFolderPath: "/tmp/Captures"
        )
        let configuration = KeyFlowConfiguration(
            revision: 7,
            mappings: [mapping],
            gestureSettings: gestureSettings
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let decoded = try decoder.decode(KeyFlowConfiguration.self, from: encoder.encode(configuration))

        #expect(decoded == configuration)
    }

    @Test("Every window switcher size preset persists through configuration encoding")
    func windowSwitcherSizePersistence() throws {
        for size in WindowSwitcherCardSize.allCases {
            let preferences = WindowSwitcherPreferences(
                cardSize: size,
                navigationSpeed: 1.75,
                windowScope: .standardApplications,
                previewStyle: .edgeToEdge,
                accent: .purple,
                showWindowTitles: false,
                showApplicationIcons: true,
                usePreviewBackdrop: false
            )
            let configuration = KeyFlowConfiguration(windowSwitcherPreferences: preferences)
            let data = try JSONEncoder().encode(configuration)
            let decoded = try JSONDecoder().decode(KeyFlowConfiguration.self, from: data)

            #expect(decoded.windowSwitcherPreferences == preferences)
        }
    }

    @Test("Volume adjustment preferences clamp and persist production choices")
    func volumeAdjustmentPreferencePersistence() throws {
        var settings = GestureSettings.default
        settings.volumePreferences = VolumeAdjustmentPreferences(
            speedMultiplier: 2.25,
            responseMilliseconds: 400,
            stepPercentage: 5
        )
        let configuration = KeyFlowConfiguration(gestureSettings: settings)
        let decoded = try JSONDecoder().decode(
            KeyFlowConfiguration.self,
            from: JSONEncoder().encode(configuration)
        )

        #expect(decoded.gestureSettings.volumePreferences == settings.volumePreferences)
        #expect(VolumeAdjustmentPreferences(responseMilliseconds: 37).responseMilliseconds == 50)
        #expect(VolumeAdjustmentPreferences(stepPercentage: 10).stepPercentage == 2)
        #expect(VolumeAdjustmentPreferences(speedMultiplier: 9).speedMultiplier == 2.5)
    }

    @Test("Overlay appearance clamps and persists production choices")
    func overlayAppearancePersistence() throws {
        let appearance = OverlayAppearancePreferences(
            theme: .dark,
            surfaceStyle: .solid,
            backgroundColor: .midnight,
            accent: .purple,
            backgroundOpacity: 0.7,
            cornerRadius: 26,
            showsBorder: false
        )
        let configuration = KeyFlowConfiguration(overlayAppearance: appearance)
        let decoded = try JSONDecoder().decode(
            KeyFlowConfiguration.self,
            from: JSONEncoder().encode(configuration)
        )

        #expect(decoded.overlayAppearance == appearance)
        #expect(OverlayAppearancePreferences(backgroundOpacity: 0).backgroundOpacity == 0.45)
        #expect(OverlayAppearancePreferences(cornerRadius: 100).cornerRadius == 30)
    }

    @Test("Schema twelve gains the established overlay appearance defaults")
    func schemaTwelveAppearanceMigration() throws {
        let data = Data(
            """
            {
              "schemaVersion": 12,
              "revision": 6,
              "mappings": [],
              "windowSwitcherPreferences": {
                "accent": "purple"
              }
            }
            """.utf8
        )

        let migrated = try ConfigurationMigrator.decode(data, using: JSONDecoder())

        #expect(migrated.schemaVersion == KeyFlowConfiguration.currentSchemaVersion)
        #expect(migrated.overlayAppearance.theme == .system)
        #expect(migrated.overlayAppearance.backgroundOpacity == 0.96)
        #expect(migrated.overlayAppearance.accent == .purple)
    }

    @Test("Schema eleven gains immediate two-percent volume defaults")
    func schemaElevenVolumePreferenceMigration() throws {
        let data = Data(
            """
            {
              "schemaVersion": 11,
              "revision": 5,
              "mappings": [],
              "gestureSettings": {
                "volumeAdjustment": {"isEnabled": true, "trigger": "fourFinger"}
              }
            }
            """.utf8
        )

        let migrated = try ConfigurationMigrator.decode(data, using: JSONDecoder())

        #expect(migrated.schemaVersion == KeyFlowConfiguration.currentSchemaVersion)
        #expect(migrated.gestureSettings.volumePreferences.speedMultiplier == 1.25)
        #expect(migrated.gestureSettings.volumePreferences.responseMilliseconds == 0)
        #expect(migrated.gestureSettings.volumePreferences.stepPercentage == 2)
    }

    @Test("Schema eight switcher preferences gain navigation and window-source defaults")
    func schemaEightSwitcherPreferenceMigration() throws {
        let data = Data(
            """
            {
              "schemaVersion": 8,
              "revision": 2,
              "mappings": [],
              "windowSwitcherPreferences": {
                "cardSize": "large",
                "previewStyle": "fullWindow",
                "accent": "blue",
                "showWindowTitles": true,
                "showApplicationIcons": true,
                "usePreviewBackdrop": true
              }
            }
            """.utf8
        )

        let migrated = try ConfigurationMigrator.decode(data, using: JSONDecoder())

        #expect(migrated.schemaVersion == KeyFlowConfiguration.currentSchemaVersion)
        #expect(migrated.windowSwitcherPreferences.cardSize == .large)
        #expect(migrated.windowSwitcherPreferences.navigationSpeed == 1)
        #expect(migrated.windowSwitcherPreferences.windowScope == .allActiveWindows)
    }

    @Test("Schema nine discrete switcher speed migrates to the continuous scale")
    func schemaNineSwitcherSpeedMigration() throws {
        let data = Data(
            """
            {
              "schemaVersion": 9,
              "revision": 3,
              "mappings": [],
              "windowSwitcherPreferences": {
                "cardSize": "balanced",
                "navigationSpeed": "fast",
                "windowScope": "allActiveWindows",
                "previewStyle": "fullWindow",
                "accent": "system",
                "showWindowTitles": true,
                "showApplicationIcons": true,
                "usePreviewBackdrop": true
              }
            }
            """.utf8
        )

        let migrated = try ConfigurationMigrator.decode(data, using: JSONDecoder())

        #expect(migrated.schemaVersion == KeyFlowConfiguration.currentSchemaVersion)
        #expect(migrated.windowSwitcherPreferences.navigationSpeed == 2.5)
    }

    @Test("Schema ten normalized switcher speed migrates to a multiplier")
    func schemaTenSwitcherSpeedMigration() throws {
        let data = Data(
            """
            {
              "schemaVersion": 10,
              "revision": 4,
              "mappings": [],
              "windowSwitcherPreferences": {
                "cardSize": "balanced",
                "navigationSpeed": 0.5,
                "windowScope": "allActiveWindows",
                "previewStyle": "fullWindow",
                "accent": "system",
                "showWindowTitles": true,
                "showApplicationIcons": true,
                "usePreviewBackdrop": true
              }
            }
            """.utf8
        )

        let migrated = try ConfigurationMigrator.decode(data, using: JSONDecoder())

        #expect(migrated.schemaVersion == KeyFlowConfiguration.currentSchemaVersion)
        #expect(migrated.windowSwitcherPreferences.navigationSpeed == 1)
    }

    @Test("Runtime matches exact keyboard modifiers")
    func keyboardMatching() {
        let mapping = Mapping(
            name: "Match me",
            isEnabled: true,
            trigger: .init(kind: .keyboard, keyCode: 40, modifiers: [.command, .option]),
            action: .init(kind: .typeText, value: "matched")
        )
        let snapshot = RuntimeSnapshot(configuration: .init(mappings: [mapping]))

        #expect(snapshot.matchKeyboard(keyCode: 40, modifiers: [.command, .option])?.id == mapping.id)
        #expect(snapshot.matchKeyboard(keyCode: 40, modifiers: [.command]) == nil)
        #expect(snapshot.matchKeyboard(keyCode: 41, modifiers: [.command, .option]) == nil)
    }

    @Test("Disabled and invalid mappings are not compiled")
    func runtimeFiltersMappings() {
        let disabled = Mapping(name: "Disabled", isEnabled: false)
        let invalid = Mapping(
            name: "Invalid",
            isEnabled: true,
            action: .init(kind: .openURL, value: "not a URL")
        )
        let snapshot = RuntimeSnapshot(configuration: .init(mappings: [disabled, invalid]))

        #expect(snapshot.keyboardMappings.isEmpty)
        #expect(snapshot.gestureMappings.isEmpty)
    }

    @Test("Validator identifies bad URL and missing fields")
    func validation() {
        let mapping = Mapping(
            name: "  ",
            trigger: .init(kind: .keyboard),
            action: .init(kind: .openURL, value: "ftp://example.com")
        )
        let errors = MappingValidator.validate(mapping)

        #expect(errors.contains(.missingName))
        #expect(errors.contains(.missingKeyCode))
        #expect(errors.contains(.invalidURL))
    }

    @Test("Four-finger volume mapping compiles without an action value")
    func fourFingerVolumeMapping() {
        let settings = GestureSettings(
            volumeAdjustment: .init(isEnabled: true, trigger: .fourFinger)
        )
        let snapshot = RuntimeSnapshot(configuration: .init(gestureSettings: settings))

        #expect(snapshot.matchGesture(.fourFingerSwipeUp)?.action.kind == .volumeUp)
        #expect(snapshot.matchGesture(.fourFingerSwipeDown)?.action.kind == .volumeDown)
    }

    @Test("Fixed gesture features compile to their selected triggers")
    func fixedGestureFeatureCompilation() {
        let settings = GestureSettings(
            mute: .init(isEnabled: true, trigger: .threeFingerClick),
            playPause: .init(isEnabled: true, trigger: .threeFingerTap),
            screenshot: .init(isEnabled: true, trigger: .fourFingerClick),
            customScreenshot: .init(isEnabled: true, trigger: .fiveFingerTap),
            interactiveWindowSwitcherEnabled: true
        )
        let snapshot = RuntimeSnapshot(configuration: .init(gestureSettings: settings))

        #expect(snapshot.matchGesture(.threeFingerClick)?.action.kind == .toggleMute)
        #expect(snapshot.matchGesture(.threeFingerTap)?.action.kind == .playPause)
        #expect(snapshot.matchGesture(.fourFingerClick)?.action.kind == .captureScreenshot)
        #expect(snapshot.matchGesture(.fiveFingerTap)?.action.kind == .captureSelectionScreenshot)
        #expect(snapshot.matchGesture(.fourFingerHorizontalSwipe)?.action.kind == .windowSwitcher)
        #expect(snapshot.hasGestureMapping(fingerCount: 3))
        #expect(snapshot.hasGestureMapping(fingerCount: 4))
        #expect(snapshot.hasGestureMapping(fingerCount: 5))
        #expect(!snapshot.suppressesSystemGestures(fingerCount: 3))
        #expect(snapshot.suppressesSystemGestures(fingerCount: 4))
        #expect(!snapshot.suppressesSystemGestures(fingerCount: 5))
    }

    @Test("Volume adjustment offers only four- and five-finger swipes")
    func supportedVolumeTriggers() {
        #expect(VerticalGestureTrigger.volumeAdjustmentCases == [.fourFinger, .fiveFinger])

        let legacySettings = GestureSettings(
            volumeAdjustment: .init(isEnabled: true, trigger: .threeFinger)
        )
        let snapshot = RuntimeSnapshot(configuration: .init(gestureSettings: legacySettings))
        #expect(snapshot.matchGesture(.threeFingerSwipeUp) == nil)
        #expect(snapshot.matchGesture(.threeFingerSwipeDown) == nil)
    }

    @Test("Only enabled features reserve a discrete trigger")
    func gestureTriggerOwnership() {
        var settings = GestureSettings.default
        settings.playPause.isEnabled = true
        settings.playPause.trigger = .fourFingerTap
        settings.screenshot.trigger = .fourFingerTap

        #expect(settings.owner(of: .fourFingerTap, excluding: .screenshot) == .playPause)
        settings.playPause.isEnabled = false
        #expect(settings.owner(of: .fourFingerTap, excluding: .screenshot) == nil)
    }

    @Test("Conflicting decoded gesture settings fail closed")
    func conflictingGestureSettingsFailClosed() {
        var settings = GestureSettings.default
        settings.playPause = .init(isEnabled: true, trigger: .fourFingerTap)
        settings.screenshot = .init(isEnabled: true, trigger: .fourFingerTap)
        let snapshot = RuntimeSnapshot(configuration: .init(gestureSettings: settings))

        #expect(settings.conflictingFeatures == [.playPause, .screenshot])
        #expect(snapshot.matchGesture(.fourFingerTap) == nil)
    }

    @Test("Legacy gestures and unsafe continuous actions are rejected")
    func gestureContractValidation() {
        let legacy = Mapping(
            name: "Legacy swipe",
            trigger: .init(kind: .swipeUp),
            action: .init(kind: .volumeUp, value: "")
        )
        let unsafeContinuousAction = Mapping(
            name: "Repeated URL",
            trigger: .init(kind: .fourFingerSwipeUp),
            action: .init(kind: .openURL, value: "https://example.com")
        )

        #expect(MappingValidator.validate(legacy).contains(.unsupportedTrackpadGesture))
        #expect(
            MappingValidator.validate(unsafeContinuousAction).contains(.continuousSwipeRequiresVolumeAction)
        )
    }

    @Test("Duplicate enabled triggers fail closed instead of choosing one")
    func duplicateTriggersFailClosed() {
        let first = Mapping(
            name: "First",
            isEnabled: true,
            trigger: .init(kind: .fourFingerTap),
            action: .init(kind: .toggleMute, value: "")
        )
        let second = Mapping(
            name: "Second",
            isEnabled: true,
            trigger: .init(kind: .fourFingerTap),
            action: .init(kind: .volumeUp, value: "")
        )
        let conflicts = MappingCollectionValidator.conflictingMappingIDs(in: [first, second])
        let snapshot = RuntimeSnapshot(configuration: .init(mappings: [first, second]))

        #expect(conflicts == [first.id, second.id])
        #expect(snapshot.matchGesture(.fourFingerTap) == nil)
    }

    @Test("Raw four-finger recognizer detects tap and vertical swipes")
    func rawFourFingerRecognition() {
        let start = (0..<4).map { TouchSample(identifier: Int32($0), x: 0.2 + Double($0) * 0.1, y: 0.3) }

        var tapRecognizer = MultifingerGestureRecognizer()
        #expect(tapRecognizer.process(points: start, timestamp: 1.0).isEmpty)
        #expect(tapRecognizer.process(points: [], timestamp: 1.2) == [.discrete(.fourFingerTap)])

        var upRecognizer = MultifingerGestureRecognizer()
        #expect(upRecognizer.process(points: start, timestamp: 2.0).isEmpty)
        let movedUp = start.map { TouchSample(identifier: $0.identifier, x: $0.x, y: $0.y + 0.12) }
        let upEvents = upRecognizer.process(points: movedUp, timestamp: 2.2)
        guard case let .verticalChanged(fingerCount, deltaY) = upEvents.first else {
            Issue.record("Expected a continuous vertical update")
            return
        }
        #expect(fingerCount == 4)
        #expect(deltaY > 0.11)
        let movedFurtherUp = start.map { TouchSample(identifier: $0.identifier, x: $0.x, y: $0.y + 0.18) }
        #expect(!upRecognizer.process(points: movedFurtherUp, timestamp: 2.3).isEmpty)
        #expect(upRecognizer.process(points: [], timestamp: 2.4) == [.verticalEnded])

        var downRecognizer = MultifingerGestureRecognizer()
        #expect(downRecognizer.process(points: start, timestamp: 3.0).isEmpty)
        let movedDown = start.map { TouchSample(identifier: $0.identifier, x: $0.x, y: $0.y - 0.12) }
        guard
            case let .verticalChanged(downFingerCount, downDeltaY) = downRecognizer.process(
                points: movedDown,
                timestamp: 3.2
            ).first
        else {
            Issue.record("Expected a continuous downward update")
            return
        }
        #expect(downFingerCount == 4)
        #expect(downDeltaY < -0.11)
    }

    @Test("Raw recognizer distinguishes three-, four-, and five-finger taps")
    func multifingerTapRecognition() {
        for (fingerCount, expected) in [
            (3, TriggerKind.threeFingerTap),
            (4, TriggerKind.fourFingerTap),
            (5, TriggerKind.fiveFingerTap),
        ] {
            let touches = (0..<fingerCount).map {
                TouchSample(identifier: Int32($0), x: 0.15 + Double($0) * 0.1, y: 0.4)
            }
            var recognizer = MultifingerGestureRecognizer()
            #expect(recognizer.process(points: touches, timestamp: 1).isEmpty)
            #expect(recognizer.process(points: [], timestamp: 1.2) == [.discrete(expected)])
        }
    }

    @Test("Volume response milliseconds delay only vertical commitment")
    func volumeResponseDelay() {
        let start = (0..<4).map {
            TouchSample(identifier: Int32($0), x: 0.2 + Double($0) * 0.1, y: 0.3)
        }
        let firstMove = start.map {
            TouchSample(identifier: $0.identifier, x: $0.x, y: $0.y + 0.02)
        }
        let laterMove = start.map {
            TouchSample(identifier: $0.identifier, x: $0.x, y: $0.y + 0.03)
        }

        var immediate = MultifingerGestureRecognizer()
        #expect(immediate.process(points: start, timestamp: 1).isEmpty)
        #expect(
            !immediate.process(
                points: firstMove,
                timestamp: 1.01,
                verticalResponseMilliseconds: 0
            ).isEmpty
        )

        var delayed = MultifingerGestureRecognizer()
        #expect(delayed.process(points: start, timestamp: 2).isEmpty)
        #expect(
            delayed.process(
                points: firstMove,
                timestamp: 2.2,
                verticalResponseMilliseconds: 500
            ).isEmpty
        )
        #expect(
            !delayed.process(
                points: laterMove,
                timestamp: 2.51,
                verticalResponseMilliseconds: 500
            ).isEmpty
        )
    }

    @Test("Recognizer upgrades the candidate while additional fingers are being placed")
    func multifingerCandidateUpgrade() {
        let three = (0..<3).map {
            TouchSample(identifier: Int32($0), x: 0.2 + Double($0) * 0.1, y: 0.4)
        }
        let four = three + [TouchSample(identifier: 3, x: 0.5, y: 0.4)]
        var recognizer = MultifingerGestureRecognizer()

        #expect(recognizer.process(points: three, timestamp: 1).isEmpty)
        #expect(recognizer.process(points: four, timestamp: 1.05).isEmpty)
        #expect(recognizer.process(points: [], timestamp: 1.2) == [.discrete(.fourFingerTap)])
    }

    @Test("Physical click suppresses the tap produced on finger release")
    func physicalClickSuppressesTap() {
        let touches = (0..<4).map {
            TouchSample(identifier: Int32($0), x: 0.2 + Double($0) * 0.1, y: 0.4)
        }
        var recognizer = MultifingerGestureRecognizer()

        #expect(recognizer.process(points: touches, timestamp: 1).isEmpty)
        #expect(recognizer.suppressUntilRelease() == nil)
        #expect(recognizer.process(points: touches, timestamp: 1.1).isEmpty)
        #expect(recognizer.process(points: [], timestamp: 1.2).isEmpty)
    }

    @Test("Raw recognizer does not turn movement or diagonal noise into a tap")
    func rawRecognizerRejectsAmbiguousTap() {
        let start = (0..<4).map { TouchSample(identifier: Int32($0), x: 0.2 + Double($0) * 0.1, y: 0.3) }
        var recognizer = MultifingerGestureRecognizer()
        #expect(recognizer.process(points: start, timestamp: 1).isEmpty)

        let diagonal = start.map {
            TouchSample(identifier: $0.identifier, x: $0.x + 0.06, y: $0.y + 0.06)
        }
        #expect(recognizer.process(points: diagonal, timestamp: 1.2).isEmpty)
        #expect(recognizer.process(points: [], timestamp: 1.3).isEmpty)
    }

    @Test("Vertical gesture streams reversals without requiring release")
    func verticalGestureDirectionReversal() {
        let start = (0..<4).map { TouchSample(identifier: Int32($0), x: 0.2 + Double($0) * 0.1, y: 0.3) }
        var recognizer = MultifingerGestureRecognizer()
        #expect(recognizer.process(points: start, timestamp: 1).isEmpty)

        let up = start.map { TouchSample(identifier: $0.identifier, x: $0.x, y: $0.y + 0.10) }
        guard case let .verticalChanged(_, upDelta) = recognizer.process(points: up, timestamp: 1.1).first else {
            Issue.record("Expected upward movement")
            return
        }
        #expect(upDelta > 0)

        let reversed = start.map { TouchSample(identifier: $0.identifier, x: $0.x, y: $0.y + 0.04) }
        guard
            case let .verticalChanged(_, downDelta) = recognizer.process(
                points: reversed,
                timestamp: 1.2
            ).first
        else {
            Issue.record("Expected reversed movement without lifting")
            return
        }
        #expect(downDelta < 0)
        #expect(recognizer.process(points: [], timestamp: 1.3) == [.verticalEnded])
    }

    @Test("Recognizer rejects contact identity replacement mid-gesture")
    func rawRecognizerRejectsIdentityReplacement() {
        let start = (0..<4).map { TouchSample(identifier: Int32($0), x: 0.2 + Double($0) * 0.1, y: 0.3) }
        var recognizer = MultifingerGestureRecognizer()
        #expect(recognizer.process(points: start, timestamp: 1).isEmpty)

        let replacements = (4..<8).map {
            TouchSample(identifier: Int32($0), x: 0.2 + Double($0 - 4) * 0.1, y: 0.3)
        }
        #expect(recognizer.process(points: replacements, timestamp: 1.1).isEmpty)
        #expect(recognizer.process(points: [], timestamp: 1.2).isEmpty)
    }

    @Test("Repository persists atomically and ignores stale revisions")
    func repositoryPersistence() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let fileURL = directory.appendingPathComponent("configuration.json")
        let repository = ConfigurationRepository(fileURL: fileURL)
        defer { try? FileManager.default.removeItem(at: directory) }

        let newer = KeyFlowConfiguration(revision: 2, mappings: [Mapping(name: "Newer")])
        let stale = KeyFlowConfiguration(revision: 1, mappings: [Mapping(name: "Stale")])
        try await repository.save(newer)
        try await repository.save(stale)

        let loaded = try await repository.load()
        #expect(loaded.revision == 2)
        #expect(loaded.mappings.first?.name == "Newer")
    }

    @Test("Repository rejects configurations from a newer schema")
    func repositoryRejectsFutureSchema() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let fileURL = directory.appendingPathComponent("configuration.json")
        let repository = ConfigurationRepository(fileURL: fileURL)
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let futureVersion = KeyFlowConfiguration.currentSchemaVersion + 1
        let data = Data("{\"schemaVersion\":\(futureVersion),\"revision\":0,\"mappings\":[]}".utf8)
        try data.write(to: fileURL)

        await #expect(throws: ConfigurationMigrationError.self) {
            _ = try await repository.load()
        }
    }

    @Test("Raw recognizer cancels when more than five contacts are present")
    func rawRecognizerRejectsExtraContacts() {
        var recognizer = MultifingerGestureRecognizer()
        let sixTouches = (0..<6).map {
            TouchSample(identifier: Int32($0), x: Double($0) / 10, y: 0.5)
        }

        #expect(recognizer.process(points: sixTouches, timestamp: 1).isEmpty)
        #expect(recognizer.process(points: [], timestamp: 1.1).isEmpty)
    }

    @Test("Actions requiring configuration reject whitespace values")
    func requiredActionValues() {
        for kind in [ActionKind.openURL, .launchApplication, .typeText] {
            let mapping = Mapping(
                name: "Required value",
                trigger: .init(kind: .fourFingerTap),
                action: .init(kind: kind, value: "   ")
            )
            #expect(MappingValidator.validate(mapping).contains(.missingActionValue))
        }
    }

    @Test("Raw recognizer emits a persistent horizontal gesture lifecycle")
    func horizontalGestureLifecycle() {
        let start = (0..<4).map { TouchSample(identifier: Int32($0), x: 0.3 + Double($0) * 0.1, y: 0.5) }
        var recognizer = MultifingerGestureRecognizer()
        #expect(recognizer.process(points: start, timestamp: 1).isEmpty)

        let began = start.map { TouchSample(identifier: $0.identifier, x: $0.x - 0.08, y: $0.y) }
        let beganEvents = recognizer.process(points: began, timestamp: 1.1)
        guard case let .horizontalBegan(translationX, translationY) = beganEvents.first else {
            Issue.record("Expected horizontal begin event")
            return
        }
        #expect(abs(translationX + 0.08) < 0.000_001)
        #expect(abs(translationY) < 0.000_001)

        let changed = start.map { TouchSample(identifier: $0.identifier, x: $0.x - 0.16, y: $0.y - 0.11) }
        let changedEvents = recognizer.process(points: changed, timestamp: 1.2)
        guard case let .horizontalChanged(changedX, changedY) = changedEvents.first else {
            Issue.record("Expected horizontal change event")
            return
        }
        #expect(abs(changedX + 0.16) < 0.000_001)
        #expect(abs(changedY + 0.11) < 0.000_001)

        let endedEvents = recognizer.process(points: [], timestamp: 1.3)
        guard case let .horizontalEnded(endedX, endedY) = endedEvents.first else {
            Issue.record("Expected horizontal end event")
            return
        }
        #expect(abs(endedX + 0.16) < 0.000_001)
        #expect(abs(endedY + 0.11) < 0.000_001)
    }

    @Test("Horizontal gesture accumulates smooth sub-threshold movement")
    func horizontalGestureAccumulatesSmallFrames() {
        let start = (0..<4).map { TouchSample(identifier: Int32($0), x: 0.3 + Double($0) * 0.1, y: 0.5) }
        var recognizer = MultifingerGestureRecognizer()
        #expect(recognizer.process(points: start, timestamp: 1).isEmpty)

        let began = start.map { TouchSample(identifier: $0.identifier, x: $0.x - 0.06, y: $0.y) }
        #expect(recognizer.process(points: began, timestamp: 1.1).count == 1)

        let tinyMove = start.map { TouchSample(identifier: $0.identifier, x: $0.x - 0.062, y: $0.y) }
        #expect(recognizer.process(points: tinyMove, timestamp: 1.11).isEmpty)

        let accumulatedMove = start.map { TouchSample(identifier: $0.identifier, x: $0.x - 0.064, y: $0.y) }
        guard
            case let .horizontalChanged(translationX, _) = recognizer.process(
                points: accumulatedMove,
                timestamp: 1.12
            ).first
        else {
            Issue.record("Expected small horizontal samples to accumulate into an update")
            return
        }
        #expect(abs(translationX + 0.064) < 0.000_001)
    }

    @Test("Window switcher mappings require the interactive horizontal trigger")
    func windowSwitcherValidation() {
        let valid = Mapping(
            name: "Windows",
            trigger: .init(kind: .fourFingerHorizontalSwipe),
            action: .init(kind: .windowSwitcher, value: "")
        )
        #expect(MappingValidator.validate(valid).isEmpty)

        var wrongTrigger = valid
        wrongTrigger.trigger.kind = .fourFingerTap
        #expect(MappingValidator.validate(wrongTrigger).contains(.windowSwitcherRequiresHorizontalSwipe))

        var wrongAction = valid
        wrongAction.action.kind = .toggleMute
        #expect(MappingValidator.validate(wrongAction).contains(.horizontalSwipeRequiresWindowSwitcher))
    }

    @Test("Window selection follows finger direction and stops at the layout edges")
    func windowSelection() {
        #expect(WindowSelectionResolver.index(translationX: 0, windowCount: 4, initialIndex: 2) == 2)
        #expect(WindowSelectionResolver.index(translationX: -0.06, windowCount: 4, initialIndex: 2) == 1)
        #expect(WindowSelectionResolver.index(translationX: -0.14, windowCount: 4, initialIndex: 2) == 0)
        #expect(WindowSelectionResolver.index(translationX: 0.06, windowCount: 4, initialIndex: 2) == 3)
        #expect(WindowSelectionResolver.index(translationX: 0.31, windowCount: 4, initialIndex: 2) == 3)
    }

    @Test("Raw horizontal gesture commits only after every finger is lifted")
    func horizontalGestureWaitsForFullRelease() {
        let start = (0..<4).map { TouchSample(identifier: Int32($0), x: 0.3 + Double($0) * 0.1, y: 0.5) }
        var recognizer = MultifingerGestureRecognizer()
        #expect(recognizer.process(points: start, timestamp: 1).isEmpty)

        let moved = start.map { TouchSample(identifier: $0.identifier, x: $0.x - 0.14, y: $0.y) }
        #expect(recognizer.process(points: moved, timestamp: 1.1).count == 1)
        #expect(recognizer.process(points: Array(moved.prefix(3)), timestamp: 1.2).isEmpty)
        #expect(recognizer.process(points: Array(moved.prefix(2)), timestamp: 1.3).isEmpty)

        let ended = recognizer.process(points: [], timestamp: 1.4)
        guard case let .horizontalEnded(translationX, translationY) = ended.first else {
            Issue.record("Expected horizontal end only after the final contact lifted")
            return
        }
        #expect(abs(translationX + 0.14) < 0.000_001)
        #expect(abs(translationY) < 0.000_001)
    }

    @Test("Schema one configurations migrate to the current schema")
    func configurationMigration() throws {
        let mappingID = UUID()
        let json = """
            {
              "schemaVersion": 1,
              "revision": 3,
              "mappings": [{
                "id": "\(mappingID.uuidString)",
                "name": "Migrated",
                "isEnabled": false,
                "trigger": {"kind":"fourFingerTap","modifiers":0},
                "action": {"kind":"toggleMute","value":""},
                "consumesKeyboardInput": true,
                "createdAt": "2026-07-14T12:00:00Z",
                "updatedAt": "2026-07-14T12:00:00Z"
              }]
            }
            """
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let migrated = try ConfigurationMigrator.decode(Data(json.utf8), using: decoder)

        #expect(migrated.schemaVersion == KeyFlowConfiguration.currentSchemaVersion)
        #expect(migrated.revision == 3)
        #expect(migrated.mappings.first?.id == mappingID)
        #expect(migrated.windowSwitcherPreferences == .default)
    }

    @Test("Schema three gesture mappings migrate to fixed feature settings")
    func gestureSettingsMigration() throws {
        let firstID = UUID()
        let secondID = UUID()
        let json = """
            {
              "schemaVersion": 3,
              "revision": 9,
              "mappings": [
                {
                  "id": "\(firstID.uuidString)",
                  "name": "Volume",
                  "isEnabled": true,
                  "trigger": {"kind":"fourFingerSwipeUp","modifiers":0},
                  "action": {"kind":"volumeUp","value":""},
                  "consumesKeyboardInput": true,
                  "createdAt": "2026-07-14T12:00:00Z",
                  "updatedAt": "2026-07-14T12:00:00Z"
                },
                {
                  "id": "\(secondID.uuidString)",
                  "name": "Windows",
                  "isEnabled": true,
                  "trigger": {"kind":"fourFingerHorizontalSwipe","modifiers":0},
                  "action": {"kind":"windowSwitcher","value":""},
                  "consumesKeyboardInput": true,
                  "createdAt": "2026-07-14T12:00:00Z",
                  "updatedAt": "2026-07-14T12:00:00Z"
                }
              ]
            }
            """
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let migrated = try ConfigurationMigrator.decode(Data(json.utf8), using: decoder)

        #expect(migrated.schemaVersion == KeyFlowConfiguration.currentSchemaVersion)
        #expect(migrated.gestureSettings.volumeAdjustment.isEnabled)
        #expect(migrated.gestureSettings.volumeAdjustment.trigger == .fourFinger)
        #expect(migrated.gestureSettings.interactiveWindowSwitcherEnabled)
        #expect(migrated.mappings.count == 2)
    }

    @Test("Schema four migrates three-finger volume and supplies mute defaults")
    func schemaFourGestureSettingsMigration() throws {
        let json = """
            {
              "schemaVersion": 4,
              "revision": 10,
              "mappings": [],
              "gestureSettings": {
                "volumeAdjustment": {"isEnabled":true,"trigger":"threeFinger"},
                "playPause": {"isEnabled":false,"trigger":"fourFingerTap"},
                "screenshot": {"isEnabled":false,"trigger":"threeFingerClick"},
                "customScreenshot": {"isEnabled":false,"trigger":"fiveFingerClick"},
                "interactiveWindowSwitcherEnabled": false
              }
            }
            """

        let migrated = try ConfigurationMigrator.decode(Data(json.utf8), using: JSONDecoder())

        #expect(migrated.schemaVersion == KeyFlowConfiguration.currentSchemaVersion)
        #expect(migrated.gestureSettings.volumeAdjustment.isEnabled)
        #expect(migrated.gestureSettings.volumeAdjustment.trigger == .fourFinger)
        #expect(!migrated.gestureSettings.mute.isEnabled)
        #expect(migrated.gestureSettings.mute.trigger == .fiveFingerTap)
        #expect(migrated.gestureSettings.screenshotStorage.saveAdditionalCopy)
        #expect(migrated.gestureSettings.screenshotStorage.mode == .systemDefault)
    }

    @Test("Repository recovers the newest valid backup when the primary file is corrupt")
    func repositoryRecovery() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let fileURL = directory.appendingPathComponent("configuration.json")
        defer { try? FileManager.default.removeItem(at: directory) }
        let writer = ConfigurationRepository(fileURL: fileURL)
        try await writer.save(.init(revision: 1, mappings: [Mapping(name: "Recover me")]))
        try await writer.save(.init(revision: 2, mappings: [Mapping(name: "Current")]))
        try Data("corrupt".utf8).write(to: fileURL, options: .atomic)

        let reader = ConfigurationRepository(fileURL: fileURL)
        let recovered = try await reader.load()

        #expect(recovered.revision == 1)
        #expect(recovered.mappings.first?.name == "Recover me")
    }
}
