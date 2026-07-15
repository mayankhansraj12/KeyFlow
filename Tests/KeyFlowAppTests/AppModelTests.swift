import AppKit
import Combine
import CoreGraphics
import Foundation
import KeyFlowCore
import Testing

@testable import KeyFlowApp

@Suite("KeyFlow application model", .serialized)
@MainActor
struct AppModelTests {
    @Test("Sound Bar layout uses compact symmetric spacing")
    func soundBarLayoutSpacing() {
        let bounds = NSRect(origin: .zero, size: SystemVolumeHUDLayout.preferredSize)
        let layout = SystemVolumeHUDLayout.frames(in: bounds)

        #expect(bounds.width == 220)
        #expect(bounds.height == 48)
        #expect(layout.iconFrame.minX == 14)
        #expect(layout.iconFrame.midY == bounds.midY)
        #expect(layout.trackFrame.minX - layout.iconFrame.maxX == 10)
        #expect(layout.percentageFrame.minX - layout.trackFrame.maxX == 10)
        #expect(bounds.maxX - layout.percentageFrame.maxX == 14)
        #expect(layout.trackFrame.midY == bounds.midY)
        #expect(layout.percentageFrame.midY == bounds.midY)

        let view = SystemVolumeHUDView(frame: bounds)
        let percentageLabel = view.subviews.compactMap { $0 as? NSTextField }.first
        #expect(percentageLabel?.alignment == .left)
        view.applyPercentageAlignment(.center)
        #expect(percentageLabel?.alignment == .center)
        view.applyPercentageAlignment(.right)
        #expect(percentageLabel?.alignment == .right)
    }

    @Test("Raw touch callback ignores pointer frames and forwards one gesture release")
    func rawTouchFrameGate() {
        var gate = RawTouchFrameGate()
        func forward(_ count: Int) -> Bool {
            gate.shouldForward(activeContactCount: count)
        }

        #expect(!forward(0))
        #expect(!forward(1))
        #expect(!forward(2))
        #expect(forward(3))
        #expect(forward(4))
        #expect(!forward(2))
        #expect(forward(0))
        #expect(!forward(0))
    }

    @Test("Three-finger tap and click mappings preserve macOS swipe events")
    func discreteGesturesPreserveSystemSwipes() {
        var settings = GestureSettings.default
        settings.mute = .init(isEnabled: true, trigger: .threeFingerTap)
        let engine = KeyboardEngine(
            syntheticMarker: 42,
            onMatch: { _ in },
            onStatus: { _ in },
            onGestureClick: { _ in }
        )
        guard
            let event = CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: true),
            let systemGestureType = CGEventType(rawValue: 18)
        else {
            Issue.record("Could not create gesture test event")
            return
        }

        engine.update(snapshot: RuntimeSnapshot(configuration: .init(gestureSettings: settings)))
        engine.setGestureContactCount(3)
        #expect(engine.handle(type: systemGestureType, event: event) != nil)

        settings.volumeAdjustment = .init(isEnabled: true, trigger: .fourFinger)
        engine.update(snapshot: RuntimeSnapshot(configuration: .init(gestureSettings: settings)))
        engine.setGestureContactCount(4)
        #expect(engine.handle(type: systemGestureType, event: event) == nil)
    }

    @Test("Continuous volume movement accumulates small deltas and reverses in place")
    func continuousVolumeAccumulator() {
        var accumulator = VerticalVolumeAccumulator()

        #expect(accumulator.process(.verticalChanged(fingerCount: 4, deltaY: 0.001)).isEmpty)
        #expect(
            accumulator.process(
                .verticalChanged(fingerCount: 4, deltaY: 0.004)
            )
                == [.init(trigger: .fourFingerSwipeUp, stepCount: 2)]
        )
        #expect(
            accumulator.process(
                .verticalChanged(fingerCount: 4, deltaY: 0.2)
            ) == [.init(trigger: .fourFingerSwipeUp, stepCount: 80)]
        )
        #expect(
            accumulator.process(
                .verticalChanged(fingerCount: 4, deltaY: -0.25)
            )
                == [.init(trigger: .fourFingerSwipeDown, stepCount: 100)]
        )
        #expect(accumulator.process(.verticalEnded).isEmpty)
        #expect(
            accumulator.process(
                .verticalChanged(fingerCount: 5, deltaY: -0.019)
            ) == [.init(trigger: .fiveFingerSwipeDown, stepCount: 7)]
        )
        #expect(accumulator.process(.verticalChanged(fingerCount: 3, deltaY: 0.1)).isEmpty)
    }

    @Test("Gesture contact suppression upgrades and stays active through staggered release")
    func gestureContactLatch() {
        var latch = GestureContactLatch()

        #expect(latch.update(contactCount: 1) == nil)
        #expect(latch.update(contactCount: 3) == 3)
        #expect(latch.update(contactCount: 4) == 4)
        #expect(latch.update(contactCount: 3) == nil)
        #expect(latch.activeFingerCount == 4)
        #expect(latch.update(contactCount: 1) == nil)
        #expect(latch.update(contactCount: 0) == 0)
        #expect(latch.activeFingerCount == 0)
    }

    @Test("Configured multi-finger click is consumed with its matching mouse-up")
    func configuredClickIsConsumed() {
        var settings = GestureSettings.default
        settings.screenshot = .init(isEnabled: true, trigger: .threeFingerClick)
        let engine = KeyboardEngine(
            syntheticMarker: 42,
            onMatch: { _ in },
            onStatus: { _ in },
            onGestureClick: { _ in }
        )
        engine.update(snapshot: RuntimeSnapshot(configuration: .init(gestureSettings: settings)))
        engine.setGestureContactCount(3)
        guard
            let down = CGEvent(
                mouseEventSource: nil,
                mouseType: .leftMouseDown,
                mouseCursorPosition: .zero,
                mouseButton: .left
            ),
            let up = CGEvent(
                mouseEventSource: nil,
                mouseType: .leftMouseUp,
                mouseCursorPosition: .zero,
                mouseButton: .left
            )
        else {
            Issue.record("Could not create mouse events")
            return
        }

        #expect(engine.handle(type: .leftMouseDown, event: down) == nil)
        #expect(engine.handle(type: .leftMouseUp, event: up) == nil)
    }

    @Test("Window geometry matching rejects browser sub-surfaces")
    func windowGeometryMatching() {
        let applicationWindow = CGRect(x: 0, y: 33, width: 1470, height: 840)
        let matchingSurface = CGRect(x: 1, y: 34, width: 1468, height: 838)
        let browserToolbarSurface = CGRect(x: 99, y: 58, width: 1218, height: 139)

        #expect(
            WindowGeometryMatcher.matches(
                accessibility: applicationWindow,
                windowServer: matchingSurface
            )
        )
        #expect(
            !WindowGeometryMatcher.matches(
                accessibility: applicationWindow,
                windowServer: browserToolbarSurface
            )
        )
    }

    @Test("Window catalog requires real standard windows and rejects shell surfaces")
    func windowCatalogScope() {
        #expect(WindowCatalogFilter.includesApplication(activationPolicy: .regular, scope: .standardApplications))
        #expect(
            !WindowCatalogFilter.includesApplication(activationPolicy: .accessory, scope: .standardApplications)
        )
        #expect(
            !WindowCatalogFilter.includesApplication(activationPolicy: .prohibited, scope: .standardApplications)
        )
        #expect(WindowCatalogFilter.includesApplication(activationPolicy: .regular, scope: .allActiveWindows))
        #expect(WindowCatalogFilter.includesApplication(activationPolicy: .accessory, scope: .allActiveWindows))
        #expect(WindowCatalogFilter.includesApplication(activationPolicy: .prohibited, scope: .allActiveWindows))
        #expect(
            !WindowCatalogFilter.includesWindow(
                layer: 24,
                isOnscreen: true,
                activationPolicy: .accessory,
                bundleIdentifier: "com.example.MenuUtility",
                scope: .allActiveWindows
            )
        )
        #expect(
            !WindowCatalogFilter.includesWindow(
                layer: 24,
                isOnscreen: true,
                activationPolicy: .regular,
                bundleIdentifier: "com.example.Editor",
                scope: .allActiveWindows
            )
        )
        #expect(
            WindowCatalogFilter.includesWindow(
                layer: 0,
                isOnscreen: false,
                activationPolicy: .accessory,
                bundleIdentifier: "com.example.MenuUtility",
                scope: .allActiveWindows
            )
        )
        #expect(
            !WindowCatalogFilter.includesWindow(
                layer: 0,
                isOnscreen: true,
                activationPolicy: .accessory,
                bundleIdentifier: "com.apple.dock",
                scope: .allActiveWindows
            )
        )
        #expect(
            !WindowCatalogFilter.includesWindow(
                layer: 25,
                isOnscreen: true,
                activationPolicy: .accessory,
                bundleIdentifier: "com.apple.controlcenter",
                scope: .allActiveWindows
            )
        )
        #expect(
            WindowCatalogFilter.includesAccessibilityWindow(
                role: kAXWindowRole as String,
                subrole: kAXStandardWindowSubrole as String
            )
        )
        #expect(
            WindowCatalogFilter.includesAccessibilityWindow(
                role: kAXWindowRole as String,
                subrole: kAXDialogSubrole as String
            )
        )
        #expect(
            !WindowCatalogFilter.includesAccessibilityWindow(
                role: kAXWindowRole as String,
                subrole: kAXFloatingWindowSubrole as String
            )
        )
        #expect(
            !WindowCatalogFilter.includesAccessibilityWindow(
                role: kAXButtonRole as String,
                subrole: nil
            )
        )
    }

    @Test("Window thumbnail cache rejects content from an old browser tab")
    func windowThumbnailCacheIdentity() {
        let processID = ProcessInfo.processInfo.processIdentifier
        let applicationElement = AXUIElementCreateApplication(processID)
        let window = SwitchableWindow(
            id: 42,
            windowID: 42,
            processID: processID,
            title: "Current Tab",
            applicationName: "Browser",
            bounds: CGRect(x: 10, y: 20, width: 1200, height: 800),
            applicationIcon: NSImage(size: NSSize(width: 32, height: 32)),
            applicationElement: applicationElement,
            windowElement: applicationElement,
            thumbnail: nil
        )

        #expect(
            WindowThumbnailCacheValidator.matches(
                cachedProcessID: processID,
                cachedTitle: "Current Tab",
                cachedBounds: window.bounds,
                window: window
            )
        )
        #expect(
            !WindowThumbnailCacheValidator.matches(
                cachedProcessID: processID,
                cachedTitle: "Closed Tab",
                cachedBounds: window.bounds,
                window: window
            )
        )
    }

    @Test("Window switcher grid wraps after five cards and centers incomplete rows")
    func windowSwitcherGridLayout() {
        #expect(WindowSwitcherGridLayout(itemCount: 1).columnCount == 1)
        #expect(WindowSwitcherGridLayout(itemCount: 1).rowCount == 1)
        #expect(WindowSwitcherGridLayout(itemCount: 5).columnCount == 5)
        #expect(WindowSwitcherGridLayout(itemCount: 5).rowCount == 1)
        #expect(WindowSwitcherGridLayout(itemCount: 6).columnCount == 5)
        #expect(WindowSwitcherGridLayout(itemCount: 6).rowCount == 2)
        #expect(WindowSwitcherGridLayout(itemCount: 10).rowCount == 2)
        #expect(WindowSwitcherGridLayout(itemCount: 11).rowCount == 3)
        #expect(WindowSwitcherGridLayout(itemCount: 9).preferredInitialIndex == 2)
        #expect(WindowSwitcherGridLayout(itemCount: 15).preferredInitialIndex == 7)

        let layout = WindowSwitcherGridLayout(itemCount: 9)
        #expect(layout.position(for: 4) == .init(row: 0, column: 4))
        #expect(layout.position(for: 5) == .init(row: 1, column: 0))
        #expect(layout.position(for: 8) == .init(row: 1, column: 3))

        let contentWidth = layout.contentSize(cardWidth: 200, cardHeight: 150, spacing: 10).width
        let firstBottomCard = layout.center(for: 5, cardWidth: 200, cardHeight: 150, spacing: 10)
        let lastBottomCard = layout.center(for: 8, cardWidth: 200, cardHeight: 150, spacing: 10)
        #expect(firstBottomCard != nil)
        #expect(lastBottomCard != nil)
        #expect(abs((firstBottomCard?.x ?? 0) + (lastBottomCard?.x ?? 0) - contentWidth) < 0.001)
    }

    @Test("Window switcher navigation follows horizontal, vertical, and diagonal movement")
    func windowSwitcherDirectionalNavigation() {
        let initialIndex = WindowSwitcherGridLayout(itemCount: 15).preferredInitialIndex
        func resolve(_ x: Double, _ y: Double, speed: Double = 1) -> Int {
            var resolver = WindowSwitcherNavigationResolver()
            return resolver.index(
                translationX: x,
                translationY: y,
                itemCount: 15,
                initialIndex: initialIndex,
                speed: speed
            )
        }

        #expect(initialIndex == 7)
        #expect(resolve(0, 0) == 7)
        #expect(resolve(-0.06, 0) == 6)
        #expect(resolve(0.06, 0) == 8)
        #expect(resolve(0, 0.05) == 2)
        #expect(resolve(0, -0.05) == 12)
        #expect(resolve(0.06, -0.05) == 13)
        #expect(resolve(0.11, 0, speed: 0.25) == 7)
        #expect(resolve(0.11, 0, speed: 1) == 8)
        #expect(resolve(0.11, 0, speed: 2.5) == 9)

        var session = WindowSwitcherNavigationSession()
        session.begin(translationX: -0.06, translationY: 0.01)
        #expect(
            session.index(
                translationX: -0.06,
                translationY: 0.01,
                itemCount: 15,
                initialIndex: initialIndex,
                speed: 1
            ) == 7
        )
        #expect(
            session.index(
                translationX: -0.12,
                translationY: 0.01,
                itemCount: 15,
                initialIndex: initialIndex,
                speed: 1
            ) == 6
        )
        session.begin(translationX: -0.06, translationY: 0.01)
        #expect(
            session.index(
                translationX: -0.06,
                translationY: 0.06,
                itemCount: 15,
                initialIndex: initialIndex,
                speed: 1
            ) == 2
        )

        var stableResolver = WindowSwitcherNavigationResolver()
        #expect(
            stableResolver.index(
                translationX: 0.054,
                translationY: 0,
                itemCount: 15,
                initialIndex: initialIndex,
                speed: 1
            ) == 8
        )
        #expect(
            stableResolver.index(
                translationX: 0.045,
                translationY: 0,
                itemCount: 15,
                initialIndex: initialIndex,
                speed: 1
            ) == 8
        )
        #expect(
            stableResolver.index(
                translationX: 0.039,
                translationY: 0,
                itemCount: 15,
                initialIndex: initialIndex,
                speed: 1
            ) == 7
        )

        let incompleteGridInitialIndex = WindowSwitcherGridLayout(itemCount: 9).preferredInitialIndex
        var incompleteGridResolver = WindowSwitcherNavigationResolver()
        #expect(
            incompleteGridResolver.index(
                translationX: 0,
                translationY: -0.05,
                itemCount: 9,
                initialIndex: incompleteGridInitialIndex,
                speed: 1
            ) == 7
        )
        incompleteGridResolver.reset()
        #expect(
            incompleteGridResolver.index(
                translationX: 1,
                translationY: -0.05,
                itemCount: 9,
                initialIndex: incompleteGridInitialIndex,
                speed: 1
            ) == 8
        )
    }

    @Test("Window switcher presets preserve their geometry when constrained")
    func windowSwitcherPresetGeometry() {
        let compact = WindowSwitcherLayoutMetrics(.compact)
        let balanced = WindowSwitcherLayoutMetrics(.balanced)
        let large = WindowSwitcherLayoutMetrics(.large)

        #expect(compact.maximumCardWidth < balanced.maximumCardWidth)
        #expect(balanced.maximumCardWidth < large.maximumCardWidth)
        #expect(compact.maximumCardHeight < balanced.maximumCardHeight)
        #expect(balanced.maximumCardHeight < large.maximumCardHeight)

        let grid = WindowSwitcherGridLayout(itemCount: 9)
        let compactPanel = compact.preferredPanelSize(for: grid)
        let balancedPanel = balanced.preferredPanelSize(for: grid)
        let largePanel = large.preferredPanelSize(for: grid)
        #expect(compactPanel.width < balancedPanel.width)
        #expect(balancedPanel.width < largePanel.width)
        #expect(compactPanel.height < balancedPanel.height)
        #expect(balancedPanel.height < largePanel.height)

        for size in WindowSwitcherCardSize.allCases {
            let metrics = WindowSwitcherLayoutMetrics(size)
            let resolved = WindowSwitcherResolvedLayout(
                itemCount: 9,
                metrics: metrics,
                availableSize: CGSize(width: 1_000, height: 480)
            )
            #expect(resolved.scale > 0 && resolved.scale <= 1)
            #expect(resolved.contentSize.width <= 1_000 - metrics.outerPadding * 2 + 0.001)
            #expect(resolved.contentSize.height <= 480 - metrics.outerPadding * 2 + 0.001)
            #expect(
                abs(
                    resolved.cardWidth / resolved.cardHeight
                        - metrics.maximumCardWidth / metrics.maximumCardHeight
                ) < 0.001
            )
        }
    }

    @Test("Window preview fit and fill preserve the source aspect ratio")
    func windowPreviewGeometry() {
        let source = CGSize(width: 1_600, height: 900)
        let container = CGSize(width: 300, height: 200)
        let fitted = WindowPreviewGeometry.imageSize(
            sourceSize: source,
            containerSize: container,
            style: .fullWindow
        )
        let filled = WindowPreviewGeometry.imageSize(
            sourceSize: source,
            containerSize: container,
            style: .edgeToEdge
        )

        #expect(fitted.width <= container.width + 0.001)
        #expect(fitted.height <= container.height + 0.001)
        #expect(filled.width >= container.width - 0.001)
        #expect(filled.height >= container.height - 0.001)
        #expect(abs(fitted.width / fitted.height - source.width / source.height) < 0.001)
        #expect(abs(filled.width / filled.height - source.width / source.height) < 0.001)

        let portrait = CGSize(width: 900, height: 1_600)
        let portraitFit = WindowPreviewGeometry.imageSize(
            sourceSize: portrait,
            containerSize: container,
            style: .fullWindow
        )
        #expect(abs(portraitFit.height - container.height) < 0.001)
        #expect(portraitFit.width < container.width)
        #expect(
            WindowPreviewGeometry.imageSize(sourceSize: .zero, containerSize: container, style: .fullWindow) == .zero)
    }

    @Test("Startup loads configuration and publishes it to the runtime")
    func startupLoadsConfiguration() async {
        let mapping = Mapping(name: "Loaded mapping", isEnabled: true)
        let store = MockConfigurationStore(configuration: .init(revision: 4, mappings: [mapping]))
        let dependencies = makeDependencies(store: store)
        let model = dependencies.model

        await model.startIfNeeded()

        #expect(model.revision == 4)
        #expect(model.mappings.map(\.id) == [mapping.id])
        #expect(model.selectedMappingID == mapping.id)
        #expect(dependencies.runtime.startCount == 1)
        #expect(dependencies.runtime.snapshots.last?.revision == 4)
    }

    @Test("Mapping edits update the runtime and persist a newer revision")
    func mappingEditsPersist() async {
        let store = MockConfigurationStore(configuration: .init())
        let dependencies = makeDependencies(store: store)
        let model = dependencies.model
        await model.startIfNeeded()

        model.addMapping()
        await eventually { await store.savedConfigurations().count == 1 }

        #expect(model.revision == 1)
        #expect(model.mappings.count == 1)
        #expect(model.mappings[0].action.kind == .launchApplication)
        #expect(model.mappings[0].action.value.isEmpty)
        #expect(model.mappings[0].trigger.keyCode == nil)
        #expect(dependencies.runtime.snapshots.last?.revision == 1)
        #expect(await store.savedConfigurations().last?.revision == 1)

        let calculatorURL = URL(fileURLWithPath: "/System/Applications/Calculator.app")
        model.setApplication(calculatorURL, forMappingID: model.mappings[0].id)
        await eventually { await store.savedConfigurations().count == 2 }

        #expect(model.mappings[0].action.kind == .launchApplication)
        #expect(model.mappings[0].action.value == "com.apple.calculator")
        #expect(model.mappings[0].name == "Open Calculator")
        #expect(await store.savedConfigurations().last?.mappings[0].action.value == "com.apple.calculator")
    }

    @Test("Fixed gesture features do not create or delete mappings")
    func fixedGestureFeatures() async {
        let dependencies = makeDependencies()
        let model = dependencies.model
        await model.startIfNeeded()

        model.addKeyboardMapping()
        model.setVolumeAdjustmentTrigger(.fiveFinger)
        model.setVolumeAdjustmentEnabled(true)
        model.setGestureFeatureEnabled(.mute, enabled: true)
        model.setGestureFeatureEnabled(.playPause, enabled: true)
        model.setInteractiveWindowSwitcherEnabled(true)

        #expect(model.mappings.count == 1)
        #expect(model.mappings[0].trigger.kind == .keyboard)
        #expect(model.gestureSettings.volumeAdjustment.isEnabled)
        #expect(model.gestureSettings.volumeAdjustment.trigger == .fiveFinger)
        #expect(model.gestureSettings.mute.isEnabled)
        #expect(model.gestureSettings.playPause.isEnabled)
        #expect(model.gestureSettings.interactiveWindowSwitcherEnabled)
        #expect(dependencies.windowSwitcher.enabledValues.last == true)
    }

    @Test("App model rejects legacy three-finger volume selection")
    func rejectsThreeFingerVolume() async {
        let dependencies = makeDependencies()
        let model = dependencies.model
        await model.startIfNeeded()

        model.setVolumeAdjustmentTrigger(.threeFinger)

        #expect(model.gestureSettings.volumeAdjustment.trigger == .fourFinger)
        #expect(model.errorMessage != nil)
    }

    @Test("Volume tuning updates the runtime and persists")
    func volumeTuningPersists() async {
        let store = MockConfigurationStore(configuration: .init())
        let dependencies = makeDependencies(store: store)
        let model = dependencies.model
        await model.startIfNeeded()

        model.setVolumeAdjustmentSpeed(2)
        model.setVolumeResponseMilliseconds(400)
        model.setVolumeStepPercentage(5)
        await eventually { await store.savedConfigurations().count == 3 }

        let preferences = model.gestureSettings.volumePreferences
        #expect(preferences.speedMultiplier == 2)
        #expect(preferences.responseMilliseconds == 400)
        #expect(preferences.stepPercentage == 5)
        #expect(dependencies.runtime.snapshots.last?.volumePreferences == preferences)
        #expect(await store.savedConfigurations().last?.gestureSettings.volumePreferences == preferences)
    }

    @Test("Discrete gesture triggers cannot be assigned to two enabled features")
    func gestureTriggerExclusivity() async {
        let dependencies = makeDependencies()
        let model = dependencies.model
        await model.startIfNeeded()

        model.setGestureFeatureEnabled(.playPause, enabled: true)
        model.setGestureFeatureEnabled(.screenshot, enabled: true)
        model.setGestureFeatureTrigger(.screenshot, trigger: .fourFingerTap)

        #expect(model.gestureSettings.screenshot.trigger == .threeFingerClick)
        #expect(model.errorMessage != nil)

        model.errorMessage = nil
        model.setGestureFeatureEnabled(.playPause, enabled: false)
        model.setGestureFeatureTrigger(.screenshot, trigger: .fourFingerTap)
        #expect(model.gestureSettings.screenshot.trigger == .fourFingerTap)
    }

    @Test("Window switcher customization applies live and persists")
    func windowSwitcherCustomization() async {
        let store = MockConfigurationStore(configuration: .init())
        let dependencies = makeDependencies(store: store)
        let model = dependencies.model
        await model.startIfNeeded()

        model.updateWindowSwitcherPreferences {
            $0.cardSize = .large
            $0.navigationSpeed = 2.25
            $0.windowScope = .standardApplications
            $0.appearance.accent = .purple
            $0.appearance.backgroundOpacity = 0.75
            $0.showWindowTitles = false
        }
        await eventually { await store.savedConfigurations().count == 1 }

        #expect(model.windowSwitcherPreferences.cardSize == .large)
        #expect(model.windowSwitcherPreferences.navigationSpeed == 2.25)
        #expect(dependencies.windowSwitcher.appearances.last?.accent == .purple)
        #expect(dependencies.windowSwitcher.appearances.last?.backgroundOpacity == 0.75)
        #expect(
            await store.savedConfigurations().last?.windowSwitcherPreferences.windowScope == .standardApplications
        )
        #expect(await store.savedConfigurations().last?.windowSwitcherPreferences.showWindowTitles == false)
    }

    @Test("Volume HUD appearance is independent, live, persisted, and resettable")
    func volumeHUDAppearanceCustomization() async {
        let store = MockConfigurationStore(configuration: .init())
        let dependencies = makeDependencies(store: store)
        let model = dependencies.model
        await model.startIfNeeded()

        model.updateVolumeHUDAppearance {
            $0.theme = .dark
            $0.surfaceStyle = .solid
            $0.backgroundColor = .midnight
            $0.accent = .green
            $0.customAccentColor = PersistedRGBAColor(red: 0.16, green: 0.72, blue: 0.48)
            $0.backgroundOpacity = 0.7
            $0.cornerRadius = 26
            $0.showsBorder = false
        }
        await eventually { await store.savedConfigurations().count == 1 }

        let appearance = model.gestureSettings.volumePreferences.hudAppearance
        #expect(appearance.theme == .dark)
        #expect(appearance.accent == .green)
        #expect(appearance.customAccentColor == .init(red: 0.16, green: 0.72, blue: 0.48))
        #expect(dependencies.actions.volumeHUDAppearances.last == appearance)
        #expect(await store.savedConfigurations().last?.gestureSettings.volumePreferences.hudAppearance == appearance)
        #expect(model.windowSwitcherPreferences.appearance == .default)

        model.setVolumeHUDPercentageAlignment(.center)
        await eventually { await store.savedConfigurations().count == 2 }
        #expect(model.gestureSettings.volumePreferences.percentageAlignment == .center)
        #expect(dependencies.actions.volumeHUDPercentageAlignments.last == .center)
        #expect(
            await store.savedConfigurations().last?.gestureSettings.volumePreferences.percentageAlignment == .center
        )

        model.previewVolumeHUD()
        #expect(dependencies.actions.volumeHUDPreviewCount == 1)

        model.resetVolumeHUDAppearance()
        await eventually { await store.savedConfigurations().count == 3 }
        #expect(model.gestureSettings.volumePreferences.hudAppearance == .default)
        #expect(model.gestureSettings.volumePreferences.percentageAlignment == .left)
        #expect(dependencies.actions.volumeHUDAppearances.last == .default)
        #expect(dependencies.actions.volumeHUDPercentageAlignments.last == .left)
    }

    @Test("Screenshot storage persists and is supplied to screenshot actions")
    func screenshotStoragePersistsAndExecutes() async throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let store = MockConfigurationStore(configuration: .init())
        let dependencies = makeDependencies(store: store)
        let model = dependencies.model
        await model.startIfNeeded()

        model.setAdditionalScreenshotCopyEnabled(true)
        model.setCustomScreenshotFolder(folder)
        await eventually { await store.savedConfigurations().count == 2 }
        let mapping = Mapping(
            name: "Capture",
            trigger: .init(kind: .fourFingerTap),
            action: .init(kind: .captureScreenshot, value: "")
        )
        model.testMapping(mapping)
        await eventually { dependencies.actions.executed.count == 1 }

        #expect(model.gestureSettings.screenshotStorage.mode == .customFolder)
        #expect(model.gestureSettings.screenshotStorage.saveAdditionalCopy)
        #expect(model.screenshotStorageStatusDescription.contains(folder.path))
        #expect(
            await store.savedConfigurations().last?.gestureSettings.screenshotStorage.customFolderPath == folder.path)
        #expect(dependencies.actions.screenshotStorages.last?.customFolderPath == folder.path)
    }

    @Test("macOS screenshot destination descriptions identify clipboard and folders")
    func screenshotDestinationDescriptions() {
        let home = URL(fileURLWithPath: "/Users/example", isDirectory: true)
        #expect(
            SystemScreenshotSettings.configuration(target: "clipboard", location: nil, homeDirectory: home)
                .description
                == "Clipboard — image remains ready to paste"
        )
        #expect(
            SystemScreenshotSettings.configuration(location: nil, homeDirectory: home).description
                == "Desktop — /Users/example/Desktop"
        )
        #expect(
            SystemScreenshotSettings.configuration(target: "file", location: "~/Pictures", homeDirectory: home)
                .description
                == "Pictures — /Users/example/Pictures"
        )
    }

    @Test("Recording and global pause are combined before reaching the runtime")
    func pauseStateIsCombined() async {
        let dependencies = makeDependencies()
        let model = dependencies.model
        await model.startIfNeeded()

        model.setRecording(true)
        model.setPaused(true)
        model.setRecording(false)
        model.setPaused(false)

        #expect(dependencies.runtime.pausedValues.suffix(4) == [true, true, true, false])
    }

    @Test("Valid test actions produce activity and invalid mappings are rejected")
    func testActionActivity() async {
        let dependencies = makeDependencies()
        let model = dependencies.model
        let valid = Mapping(
            name: "Volume",
            trigger: .init(kind: .fourFingerTap),
            action: .init(kind: .toggleMute, value: "")
        )

        model.testMapping(valid)
        await eventually { !model.activities.isEmpty }

        #expect(dependencies.actions.executed == [valid.action])
        #expect(model.activities.first?.mappingName == "Volume")

        model.testMapping(Mapping(name: " "))
        #expect(model.errorMessage == "Fix this mapping before testing it.")
        #expect(dependencies.actions.executed.count == 1)
    }

    @Test("Continuous gesture activity is coalesced instead of flooding the timeline")
    func continuousActivityCoalesces() async {
        let dependencies = makeDependencies()
        let model = dependencies.model
        let mapping = Mapping(
            name: "Volume up",
            trigger: .init(kind: .fourFingerSwipeUp),
            action: .init(kind: .volumeUp, value: "")
        )

        model.testMapping(mapping)
        model.testMapping(mapping)
        model.testMapping(mapping)
        try? await Task.sleep(for: .milliseconds(450))
        await eventually { model.activities.first?.occurrenceCount == 3 }

        #expect(model.activities.count == 1)
        #expect(model.activities.first?.occurrenceCount == 3)
    }

    @Test("Continuous volume uses its synchronous fast path and records once on release")
    func continuousVolumeFastPath() async {
        let dependencies = makeDependencies()
        let mapping = Mapping(
            name: "Gesture volume",
            trigger: .init(kind: .fourFingerSwipeUp),
            action: .init(kind: .volumeUp, value: "")
        )
        await dependencies.model.startIfNeeded()

        dependencies.runtime.onContinuousVolume?(mapping, 1)
        dependencies.runtime.onContinuousVolume?(mapping, 2)
        dependencies.runtime.onContinuousVolume?(mapping, 3)

        #expect(dependencies.actions.executed == [mapping.action, mapping.action, mapping.action])
        #expect(dependencies.model.activities.isEmpty)

        dependencies.runtime.onContinuousVolumeEnded?(mapping)
        #expect(dependencies.model.activities.count == 1)
        #expect(dependencies.model.activities.first?.mappingName == "Gesture volume")
    }

    @Test("Permission and login-item operations are delegated to their services")
    func systemOperationsAreDelegated() async {
        let dependencies = makeDependencies()
        let model = dependencies.model
        await model.startIfNeeded()

        dependencies.permissions.status = .init(
            accessibilityGranted: true,
            inputMonitoringGranted: true,
            postEventGranted: true,
            screenRecordingGranted: true
        )
        model.requestAccessibilityPermission()
        model.requestInputMonitoringPermission()
        model.setLaunchAtLogin(true)
        model.setHiddenFromDock(true)
        await eventually { await dependencies.store.savedConfigurations().count == 1 }

        #expect(dependencies.permissions.requested == [.accessibility, .inputMonitoring])
        #expect(model.accessibilityGranted)
        #expect(model.inputMonitoringGranted)
        #expect(model.postEventGranted)
        #expect(model.screenRecordingGranted)
        #expect(dependencies.loginItem.isEnabled)
        #expect(model.launchAtLoginEnabled)
        #expect(model.applicationPreferences.hideFromDock)
        #expect(model.dockVisibilityRequiresRelaunch)
        #expect(dependencies.applicationPresentation.preparedValues == [false, true])
        #expect(await dependencies.store.savedConfigurations().last?.applicationPreferences.hideFromDock == true)

        model.relaunchToApplyDockVisibility()
        await eventually { dependencies.applicationPresentation.relaunchCount == 1 }
    }

    @Test("An unchanged permission refresh does not invalidate the settings UI")
    func unchangedPermissionRefreshDoesNotPublish() {
        let dependencies = makeDependencies()
        var publicationCount = 0
        let observation = dependencies.model.objectWillChange.sink {
            publicationCount += 1
        }

        dependencies.model.refreshPermissions()

        #expect(publicationCount == 0)
        _ = observation
    }

    @Test("Action executor rejects malformed URLs without opening anything")
    func invalidURLAction() async {
        let executor = ActionExecutor(syntheticMarker: 42)
        await #expect(throws: ActionExecutionError.self) {
            try await executor.execute(.init(kind: .openURL, value: "file:///tmp/not-allowed"))
        }
    }

    @Test("Action executor rejects an unavailable custom screenshot folder")
    func invalidScreenshotFolder() async {
        let executor = ActionExecutor(syntheticMarker: 42)
        let storage = ScreenshotStorageSettings(
            saveAdditionalCopy: true,
            mode: .customFolder,
            customFolderPath: "/path/that/does/not/exist"
        )
        await #expect(throws: ActionExecutionError.self) {
            try await executor.execute(
                .init(kind: .captureScreenshot, value: ""),
                screenshotStorage: storage
            )
        }
    }

    @Test("Diagnostics report contains aggregate state but no mapping data")
    func diagnosticsAreRedacted() {
        let report = DiagnosticsReportBuilder.build(
            .init(
                appVersion: "1.0",
                appBuild: "10",
                configurationSchema: 2,
                configurationRevision: 7,
                mappingCount: 4,
                enabledMappingCount: 2,
                keyboardStatus: "running",
                multitouchStatus: "running",
                accessibilityGranted: true,
                inputMonitoringGranted: true,
                postEventGranted: true,
                screenRecordingGranted: true
            ))

        #expect(report.contains("Mappings: 4"))
        #expect(report.contains("Keyboard: running"))
        #expect(report.contains("Mapping names, triggers, action values, and typed text are intentionally excluded."))
    }

    @Test("Interactive window switcher follows runtime gesture phases")
    func interactiveWindowSwitcher() async {
        let dependencies = makeDependencies()
        let mapping = Mapping(
            name: "Switch windows",
            isEnabled: true,
            trigger: .init(kind: .fourFingerHorizontalSwipe),
            action: .init(kind: .windowSwitcher, value: "")
        )
        await dependencies.model.startIfNeeded()

        dependencies.runtime.onInteractiveWindowSwitcher?(
            mapping,
            .horizontalBegan(translationX: -0.06, translationY: 0)
        )
        dependencies.runtime.onInteractiveWindowSwitcher?(
            mapping,
            .horizontalChanged(translationX: -0.14, translationY: -0.1)
        )
        dependencies.runtime.onInteractiveWindowSwitcher?(
            mapping,
            .horizontalEnded(translationX: -0.14, translationY: -0.1)
        )

        #expect(dependencies.windowSwitcher.begins == [CGSize(width: -0.06, height: 0)])
        #expect(dependencies.windowSwitcher.updates == [CGSize(width: -0.14, height: -0.1)])
        #expect(dependencies.windowSwitcher.finishes == [CGSize(width: -0.14, height: -0.1)])
        #expect(dependencies.model.activities.first?.mappingName == "Switch windows")
    }

    private func makeDependencies(
        store: MockConfigurationStore = MockConfigurationStore(configuration: .init())
    ) -> TestDependencies {
        let permissions = MockPermissionService()
        let loginItem = MockLoginItemService()
        let actions = MockActionExecutor()
        let runtime = MockRuntimeController()
        let windowSwitcher = MockWindowSwitcher()
        let applicationPresentation = MockApplicationPresentationController()
        let model = AppModel(
            repository: store,
            permissionService: permissions,
            loginItemService: loginItem,
            actionExecutor: actions,
            runtime: runtime,
            windowSwitcher: windowSwitcher,
            applicationPresentation: applicationPresentation,
            syntheticMarker: 42
        )
        return TestDependencies(
            model: model,
            store: store,
            permissions: permissions,
            loginItem: loginItem,
            actions: actions,
            runtime: runtime,
            windowSwitcher: windowSwitcher,
            applicationPresentation: applicationPresentation
        )
    }

    private func eventually(_ condition: @escaping () async -> Bool) async {
        for _ in 0..<100 {
            if await condition() { return }
            await Task.yield()
        }
        Issue.record("Condition was not satisfied before the test deadline")
    }
}

@MainActor
private struct TestDependencies {
    let model: AppModel
    let store: MockConfigurationStore
    let permissions: MockPermissionService
    let loginItem: MockLoginItemService
    let actions: MockActionExecutor
    let runtime: MockRuntimeController
    let windowSwitcher: MockWindowSwitcher
    let applicationPresentation: MockApplicationPresentationController
}

private actor MockConfigurationStore: ConfigurationStoring {
    private let configuration: KeyFlowConfiguration
    private var saves: [KeyFlowConfiguration] = []

    init(configuration: KeyFlowConfiguration) {
        self.configuration = configuration
    }

    func load() async throws -> KeyFlowConfiguration { configuration }

    func save(_ configuration: KeyFlowConfiguration) async throws {
        saves.append(configuration)
    }

    func savedConfigurations() -> [KeyFlowConfiguration] { saves }
}

@MainActor
private final class MockPermissionService: PermissionServicing {
    var status = PermissionStatus(
        accessibilityGranted: false,
        inputMonitoringGranted: false,
        postEventGranted: false,
        screenRecordingGranted: false
    )
    var requested: [SystemPermission] = []
    var openedSettings: [SystemPermission] = []

    func currentStatus() -> PermissionStatus { status }
    func request(_ permission: SystemPermission) { requested.append(permission) }
    func resetRegistration(for permission: SystemPermission) async throws {}
    func openSettings(for permission: SystemPermission) { openedSettings.append(permission) }
    func revealApplicationInFinder() {}
}

@MainActor
private final class MockLoginItemService: LoginItemServicing {
    var isEnabled = false
    func setEnabled(_ enabled: Bool) throws { isEnabled = enabled }
}

@MainActor
private final class MockApplicationPresentationController: ApplicationPresentationControlling {
    var isHiddenFromDock = false
    var preparedValues: [Bool] = []
    var relaunchCount = 0

    func prepareHiddenFromDock(_ hidden: Bool) {
        preparedValues.append(hidden)
    }

    func relaunch() throws {
        relaunchCount += 1
    }
}

@MainActor
private final class MockActionExecutor: ActionExecuting {
    var executed: [ActionDefinition] = []
    var screenshotStorages: [ScreenshotStorageSettings] = []
    var volumeHUDAppearances: [OverlayAppearancePreferences] = []
    var volumeHUDPercentageAlignments: [SoundBarPercentageAlignment] = []
    var volumeHUDPreviewCount = 0
    func updateVolumeHUDAppearance(_ preferences: OverlayAppearancePreferences) {
        volumeHUDAppearances.append(preferences)
    }
    func updateVolumeHUDPercentageAlignment(_ alignment: SoundBarPercentageAlignment) {
        volumeHUDPercentageAlignments.append(alignment)
    }
    func previewVolumeHUD() { volumeHUDPreviewCount += 1 }
    func execute(_ action: ActionDefinition, screenshotStorage: ScreenshotStorageSettings) async throws {
        executed.append(action)
        screenshotStorages.append(screenshotStorage)
    }

    func executeContinuousVolume(
        _ action: ActionDefinition,
        stepCount: Int,
        stepPercentage: Int
    ) throws {
        guard stepCount > 0 else { return }
        executed.append(action)
    }
}

@MainActor
private final class MockRuntimeController: RuntimeControlling {
    var onMapping: ((Mapping) -> Void)?
    var onKeyboardStatus: ((KeyboardEngineStatus) -> Void)?
    var onMultitouchStatus: ((MultitouchProviderStatus) -> Void)?
    var onContactCountChanged: ((Int) -> Void)?
    var onContinuousVolume: ((Mapping, Int) -> Void)?
    var onContinuousVolumeEnded: ((Mapping) -> Void)?
    var onInteractiveWindowSwitcher: ((Mapping, GestureRecognitionEvent) -> Void)?
    var startCount = 0
    var stopCount = 0
    var snapshots: [RuntimeSnapshot] = []
    var pausedValues: [Bool] = []

    func start() { startCount += 1 }
    func stop() { stopCount += 1 }
    func update(snapshot: RuntimeSnapshot) { snapshots.append(snapshot) }
    func setPaused(_ paused: Bool) { pausedValues.append(paused) }
}

@MainActor
private final class MockWindowSwitcher: WindowSwitching {
    var enabledValues: [Bool] = []
    var preferences: [WindowSwitcherPreferences] = []
    var appearances: [OverlayAppearancePreferences] = []
    var begins: [CGSize] = []
    var updates: [CGSize] = []
    var finishes: [CGSize] = []
    var cancelCount = 0

    func setEnabled(_ enabled: Bool) { enabledValues.append(enabled) }
    func update(preferences: WindowSwitcherPreferences) { self.preferences.append(preferences) }
    func update(appearance: OverlayAppearancePreferences) { appearances.append(appearance) }
    func begin(translationX: Double, translationY: Double) throws {
        begins.append(CGSize(width: translationX, height: translationY))
    }

    func update(translationX: Double, translationY: Double) {
        updates.append(CGSize(width: translationX, height: translationY))
    }

    func finish(translationX: Double, translationY: Double) throws {
        finishes.append(CGSize(width: translationX, height: translationY))
    }
    func cancel() { cancelCount += 1 }
}
