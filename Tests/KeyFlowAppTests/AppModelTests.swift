import AppKit
import ApplicationServices
import Combine
import CoreAudio
import CoreGraphics
import Foundation
import KeyFlowCore
import SwiftUI
import Testing

@testable import KeyFlowApp

@Suite("KeyFlow application model", .serialized)
@MainActor
struct AppModelTests {
    @Test("Every menu-bar icon choice resolves to a native template symbol")
    func menuBarIconSymbolsResolve() {
        #expect(
            MenuBarIconStyle.selectableCases
                == [.touch, .pointer, .pointUp, .cursorClick, .cursorRays]
        )
        for style in MenuBarIconStyle.selectableCases {
            let image = NSImage(
                systemSymbolName: style.systemSymbolName,
                accessibilityDescription: style.displayName
            )
            #expect(image != nil, "Missing symbol for \(style.rawValue)")
        }
    }

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

    @Test("Primary configuration views render at production and minimum sizes")
    func primaryConfigurationViewsRender() async {
        let dependencies = makeDependencies()
        await dependencies.model.startIfNeeded()

        let productionSize = NSSize(width: 1_280, height: 820)
        let minimumSize = NSSize(width: 860, height: 560)
        let views: [AnyView] = [
            AnyView(GestureSettingsView().environmentObject(dependencies.model)),
            AnyView(WindowSwitcherSettingsView().environmentObject(dependencies.model)),
            AnyView(MappingsView().environmentObject(dependencies.model)),
        ]

        for view in views {
            for size in [productionSize, minimumSize] {
                let host = NSHostingView(rootView: view)
                host.frame = NSRect(origin: .zero, size: size)
                host.layoutSubtreeIfNeeded()

                #expect(host.fittingSize.width > 0)
                #expect(host.fittingSize.height > 0)
            }
        }
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

    @Test("Raw multitouch compatibility policy fails closed without disabling the app")
    func rawMultitouchCompatibilityPolicy() {
        let supported = MultitouchCompatibilityContext(
            operatingSystemVersion: .init(majorVersion: 15, minorVersion: 0, patchVersion: 0),
            operatingSystemBuild: "24A100",
            forceDisabled: false
        )
        #expect(MultitouchCompatibilityPolicy.evaluate(supported) == .allowed)

        let unsupported = MultitouchCompatibilityContext(
            operatingSystemVersion: .init(majorVersion: 14, minorVersion: 7, patchVersion: 0),
            operatingSystemBuild: "23H100",
            forceDisabled: false
        )
        #expect(
            MultitouchCompatibilityPolicy.evaluate(unsupported)
                == .disabled("macOS 15 or later is required")
        )

        let forcedOff = MultitouchCompatibilityContext(
            operatingSystemVersion: .init(majorVersion: 15, minorVersion: 0, patchVersion: 0),
            operatingSystemBuild: "24A100",
            forceDisabled: true
        )
        #expect(
            MultitouchCompatibilityPolicy.evaluate(forcedOff)
                == .disabled("disabled by KEYFLOW_DISABLE_RAW_MULTITOUCH")
        )
        #expect(
            MultitouchCompatibilityPolicy.evaluate(supported, blockedBuildPrefixes: ["24A"])
                == .disabled("macOS build 24A100 is blocked")
        )
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

    @Test("Window thumbnail cache expires without a later cache read")
    @MainActor
    func windowThumbnailCacheExpiresOnDeadline() async throws {
        let provider = WindowThumbnailProvider(maximumCacheAge: .milliseconds(25))
        provider.cacheThumbnail(
            NSImage(size: NSSize(width: 4, height: 4)),
            byteCost: 64,
            windowID: 41,
            processID: 12,
            title: "Private window",
            bounds: CGRect(x: 0, y: 0, width: 100, height: 80)
        )

        #expect(provider.cacheEntryCount == 1)
        let deadline = ContinuousClock.now + .seconds(2)
        while provider.cacheEntryCount != 0, ContinuousClock.now < deadline {
            try await Task.sleep(for: .milliseconds(10))
        }
        #expect(provider.cacheEntryCount == 0)
        #expect(provider.cacheMemoryCost == 0)
    }

    @Test("Window thumbnail cache enforces its memory budget")
    @MainActor
    func windowThumbnailCacheEnforcesMemoryBudget() async throws {
        let provider = WindowThumbnailProvider(maximumCacheBytes: 100)
        let image = NSImage(size: NSSize(width: 4, height: 4))
        provider.cacheThumbnail(
            image,
            byteCost: 60,
            windowID: 51,
            processID: 12,
            title: "First",
            bounds: CGRect(x: 0, y: 0, width: 100, height: 80)
        )
        try await Task.sleep(for: .milliseconds(2))
        provider.cacheThumbnail(
            image,
            byteCost: 60,
            windowID: 52,
            processID: 12,
            title: "Second",
            bounds: CGRect(x: 0, y: 0, width: 100, height: 80)
        )

        #expect(provider.cachedWindowIDs == [52])
        #expect(provider.cacheMemoryCost == 60)
    }

    @Test("Window thumbnail cache removes windows absent from the current catalog")
    @MainActor
    func windowThumbnailCacheRemovesClosedWindows() {
        let provider = WindowThumbnailProvider()
        provider.cacheThumbnail(
            NSImage(size: NSSize(width: 4, height: 4)),
            byteCost: 64,
            windowID: 61,
            processID: 12,
            title: "Closed",
            bounds: CGRect(x: 0, y: 0, width: 100, height: 80)
        )

        #expect(provider.cacheEntryCount == 1)
        #expect(provider.cachedThumbnails(for: []).isEmpty)
        #expect(provider.cacheEntryCount == 0)
        #expect(provider.cacheMemoryCost == 0)
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

    @Test("Choosing an application always replaces legacy shortcut names")
    func applicationSelectionOwnsShortcutName() async {
        let mapping = Mapping(name: "My custom label")
        let store = MockConfigurationStore(configuration: .init(mappings: [mapping]))
        let dependencies = makeDependencies(store: store)
        let model = dependencies.model
        await model.startIfNeeded()

        let calculatorURL = URL(fileURLWithPath: "/System/Applications/Calculator.app")
        model.setApplication(calculatorURL, forMappingID: mapping.id)

        #expect(model.mappings[0].name == "Open Calculator")
        await eventually {
            await store.savedConfigurations().last?.mappings[0].name == "Open Calculator"
        }
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

        model.setMenuBarIconStyle(.pointer)
        await eventually { await dependencies.store.savedConfigurations().count == 2 }
        #expect(model.applicationPreferences.menuBarIconStyle == .pointer)
        #expect(
            await dependencies.store.savedConfigurations().last?.applicationPreferences.menuBarIconStyle
                == .pointer
        )

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

    @Test("Permission service aggregates native grant state and routes requests")
    func permissionServiceRoutesNativeOperations() {
        let system = MockPermissionSystemAccess()
        system.accessibility = true
        system.inputMonitoring = true
        system.postEvent = true
        system.screenRecording = false
        system.requestInputResult = true
        system.requestScreenResult = false
        let service = SystemPermissionService(system: system)

        #expect(
            service.currentStatus()
                == PermissionStatus(
                    accessibilityGranted: true,
                    inputMonitoringGranted: true,
                    postEventGranted: true,
                    screenRecordingGranted: false
                ))

        service.request(.accessibility)
        service.request(.inputMonitoring)
        service.request(.screenRecording)

        #expect(system.accessibilityRequestCount == 1)
        #expect(system.postEventRequestCount == 1)
        #expect(system.inputRequestCount == 1)
        #expect(system.screenRequestCount == 1)
        #expect(system.openedURLs.count == 1)
        #expect(system.openedURLs.first?.absoluteString.contains("Privacy_ScreenCapture") == true)
    }

    @Test("Permission settings fall back to the general privacy pane")
    func permissionSettingsUseFallbackURL() {
        let system = MockPermissionSystemAccess()
        system.openResults = [false, true]
        let service = SystemPermissionService(system: system)

        service.openSettings(for: .inputMonitoring)

        #expect(system.openedURLs.count == 2)
        #expect(system.openedURLs[0].absoluteString.contains("Privacy_ListenEvent"))
        #expect(system.openedURLs[1].absoluteString.contains("PrivacySecurity"))
    }

    @Test("Permission reset is scoped to the app and surfaces tccutil failure")
    func permissionResetSurfacesFailure() async {
        let system = MockPermissionSystemAccess()
        system.resetResult = (1, "not authorized")
        let service = SystemPermissionService(system: system)

        await #expect(throws: PermissionServiceError.self) {
            try await service.resetRegistration(for: .accessibility)
        }
        #expect(system.resetRequests.count == 1)
        #expect(system.resetRequests.first?.service == "Accessibility")
        #expect(system.resetRequests.first?.bundleIdentifier == "app.keyflow.tests")
    }

    @Test("Permission service reveals the exact running application bundle")
    func permissionServiceRevealsApplication() {
        let system = MockPermissionSystemAccess()
        let service = SystemPermissionService(system: system)

        service.revealApplicationInFinder()

        #expect(system.revealedURLs == [system.applicationURL])
    }

    @Test("Login item service delegates registration and unregistration")
    func loginItemServiceDelegatesStateChanges() throws {
        let registration = MockLoginItemRegistration()
        let service = SystemLoginItemService(registration: registration)

        #expect(!service.isEnabled)
        try service.setEnabled(true)
        #expect(service.isEnabled)
        try service.setEnabled(false)
        #expect(!service.isEnabled)
        #expect(registration.registerCount == 1)
        #expect(registration.unregisterCount == 1)
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

    @Test("Screenshot directory waiting is event-driven and cancellable")
    func screenshotDirectoryMonitorReceivesOneChange() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("KeyFlow-DirectoryMonitor-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let monitor = DirectoryChangeMonitor()
        let waiter = Task {
            try await monitor.waitForChange(in: directory, timeout: .seconds(2))
        }

        try await Task.sleep(for: .milliseconds(30))
        let file = directory.appendingPathComponent("capture.png")
        let created = FileManager.default.createFile(atPath: file.path, contents: Data([0x01]))
        #expect(created)
        try await waiter.value
    }

    @Test("Screenshot directory waiting times out without polling")
    func screenshotDirectoryMonitorTimesOut() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("KeyFlow-DirectoryTimeout-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        await #expect(throws: DirectoryChangeMonitorError.self) {
            try await DirectoryChangeMonitor().waitForChange(
                in: directory,
                timeout: .milliseconds(25)
            )
        }
    }

    @Test("Input and switcher policies stay within a deterministic hot-path budget")
    func hotPathPolicyBudget() {
        let iterations = 50_000
        var gate = RawTouchFrameGate()
        var accumulator = VerticalVolumeAccumulator()
        var navigation = WindowSwitcherNavigationResolver()
        var checksum = 0
        let start = ContinuousClock.now

        for index in 0..<iterations {
            if gate.shouldForward(activeContactCount: index.isMultiple(of: 2) ? 4 : 0) {
                checksum += 1
            }
            checksum +=
                accumulator.process(
                    .verticalChanged(fingerCount: 4, deltaY: index.isMultiple(of: 2) ? 0.01 : -0.01)
                ).count
            checksum += navigation.index(
                translationX: Double(index % 20) / 100,
                translationY: Double(index % 15) / 100,
                itemCount: 25,
                initialIndex: 12,
                speed: 1.25
            )
        }

        let elapsed = ContinuousClock.now - start
        #expect(checksum > 0)
        #expect(elapsed < .seconds(2))
    }

    @Test("Continuous audio fast path does not rediscover hardware")
    func continuousAudioFastPathBudget() throws {
        let hardware = MockCoreAudioAccess(volume: 0.5, isMuted: false)
        let instant = ContinuousClock.now
        let controller = SystemAudioController(hardware: hardware, now: { instant })
        let start = ContinuousClock.now

        for index in 0..<10_000 {
            _ = try controller.adjustVolume(
                up: index.isMultiple(of: 2),
                stepCount: 1,
                stepPercentage: 1
            )
        }

        #expect(hardware.defaultDeviceReads == 1)
        #expect(hardware.volumeReads == 1)
        #expect(ContinuousClock.now - start < .seconds(2))
    }

    @Test("Audio controller reuses its hot session and unmutes on volume up")
    func audioControllerReusesSessionAndUnmutes() throws {
        let hardware = MockCoreAudioAccess(volume: 0.94, isMuted: true)
        let controller = SystemAudioController(hardware: hardware)

        let first = try controller.adjustVolume(up: true, stepCount: 2, stepPercentage: 5)
        let second = try controller.adjustVolume(up: false, stepCount: 1, stepPercentage: 2)

        #expect(first == 1)
        #expect(abs(second - 0.98) < 0.0001)
        #expect(hardware.defaultDeviceReads == 1)
        #expect(hardware.volumeReads == 1)
        #expect(hardware.volumeWrites == [1, 0.98])
        #expect(hardware.muteWrites == [false])
    }

    @Test("Audio controller starts a new session after its latency cache expires")
    func audioControllerExpiresSession() throws {
        let hardware = MockCoreAudioAccess(volume: 0.5, isMuted: false)
        var instant = ContinuousClock.now
        let controller = SystemAudioController(
            hardware: hardware,
            sessionTimeout: .milliseconds(250),
            now: { instant }
        )

        _ = try controller.adjustVolume(up: true, stepCount: 1, stepPercentage: 2)
        instant += .milliseconds(300)
        hardware.volume = 0.25
        _ = try controller.adjustVolume(up: true, stepCount: 1, stepPercentage: 2)

        #expect(hardware.defaultDeviceReads == 2)
        #expect(hardware.volumeReads == 2)
        #expect(hardware.volumeWrites == [0.52, 0.27])
    }

    @Test("Audio controller reports unsupported mute instead of guessing")
    func audioControllerRejectsMissingMuteControl() {
        let hardware = MockCoreAudioAccess(volume: 0.5, isMuted: nil)
        let controller = SystemAudioController(hardware: hardware)

        #expect(throws: SystemAudioError.self) {
            try controller.toggleMute()
        }
        #expect(hardware.muteWrites.isEmpty)
    }

    @Test("Action executor publishes injected audio and media results exactly once")
    func actionExecutorRoutesAudioAndMedia() async throws {
        let audio = MockAudioController()
        let media = MockMediaKeyController()
        let hud = MockVolumeHUDController()
        let executor = ActionExecutor(
            syntheticMarker: 42,
            audioController: audio,
            mediaKeyController: media,
            volumeHUD: hud
        )

        try executor.executeContinuousVolume(
            .init(kind: .volumeUp, value: ""),
            stepCount: 3,
            stepPercentage: 5
        )
        try await executor.execute(.init(kind: .toggleMute, value: ""))
        try await executor.execute(.init(kind: .playPause, value: ""))

        #expect(audio.adjustments.count == 1)
        #expect(audio.adjustments.first?.up == true)
        #expect(audio.adjustments.first?.stepCount == 3)
        #expect(audio.adjustments.first?.stepPercentage == 5)
        #expect(audio.toggleCount == 1)
        #expect(media.pressCount == 1)
        #expect(hud.prepareCount == 1)
        #expect(hud.levels.count == 2)
        #expect(abs((hud.levels.first ?? 0) - 0.72) < 0.0001)
        #expect(hud.levels.last == 0)
    }

    @Test("Action executor surfaces media-key posting failure")
    func actionExecutorReportsMediaFailure() async {
        let media = MockMediaKeyController()
        media.succeeds = false
        let executor = ActionExecutor(
            syntheticMarker: 42,
            audioController: MockAudioController(),
            mediaKeyController: media,
            volumeHUD: MockVolumeHUDController()
        )

        await #expect(throws: ActionExecutionError.self) {
            try await executor.execute(.init(kind: .playPause, value: ""))
        }
        #expect(media.pressCount == 1)
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

    @Test("Runtime routes discrete and continuous gestures exactly once")
    func runtimeRoutesGestureActions() {
        let runtime = AppRuntimeController(syntheticMarker: 77)
        let gestureSettings = GestureSettings(
            volumeAdjustment: .init(isEnabled: true, trigger: .fourFinger),
            mute: .init(isEnabled: true, trigger: .fiveFingerTap),
            interactiveWindowSwitcherEnabled: true
        )
        runtime.update(snapshot: RuntimeSnapshot(configuration: .init(gestureSettings: gestureSettings)))
        var discrete: [ActionKind] = []
        var volumeSteps: [Int] = []
        var volumeEndCount = 0
        runtime.onMapping = { discrete.append($0.action.kind) }
        runtime.onContinuousVolume = { _, steps in volumeSteps.append(steps) }
        runtime.onContinuousVolumeEnded = { _ in volumeEndCount += 1 }

        runtime.receiveGesture(.fiveFingerTap)
        runtime.receiveVerticalGesture(.verticalChanged(fingerCount: 4, deltaY: 0.3))
        runtime.receiveVerticalGesture(.verticalEnded)
        runtime.receiveVerticalGesture(.verticalEnded)

        #expect(discrete == [.toggleMute])
        #expect(volumeSteps.count == 1)
        #expect((volumeSteps.first ?? 0) > 0)
        #expect(volumeEndCount == 1)
    }

    @Test("Pausing cancels one active switcher session and blocks later input")
    func runtimePauseCancelsInteractiveGesture() {
        let runtime = AppRuntimeController(syntheticMarker: 78)
        let settings = GestureSettings(interactiveWindowSwitcherEnabled: true)
        runtime.update(snapshot: RuntimeSnapshot(configuration: .init(gestureSettings: settings)))
        var events: [GestureRecognitionEvent] = []
        runtime.onInteractiveWindowSwitcher = { _, event in events.append(event) }

        runtime.receiveHorizontalGesture(.horizontalBegan(translationX: 0.06, translationY: 0))
        runtime.receiveHorizontalGesture(.horizontalChanged(translationX: 0.12, translationY: 0.05))
        runtime.setPaused(true)
        runtime.receiveHorizontalGesture(.horizontalEnded(translationX: 0.12, translationY: 0.05))
        runtime.receiveGesture(.fourFingerTap)

        #expect(events.count == 3)
        #expect(events[0] == .horizontalBegan(translationX: 0.06, translationY: 0))
        #expect(events[1] == .horizontalChanged(translationX: 0.12, translationY: 0.05))
        #expect(events[2] == .horizontalCancelled)
    }

    @Test("Window switcher controller presents, navigates, activates once, and closes")
    func windowSwitcherControllerLifecycle() async throws {
        let windows = (1...7).map { makeTestWindow(id: CGWindowID($0)) }
        let catalog = MockWindowCatalog(windows: windows)
        let thumbnails = MockWindowThumbnailProvider()
        let presenter = MockWindowSwitcherPresenter()
        let controller = WindowSwitcherController(
            catalog: catalog,
            thumbnails: thumbnails,
            presenter: presenter
        )
        var preferences = WindowSwitcherPreferences.default
        preferences.cardSize = .large
        preferences.navigationSpeed = 2.5
        controller.update(preferences: preferences)
        controller.setEnabled(true)

        try controller.begin(translationX: 0.02, translationY: 0)
        await eventually { !thumbnails.captureRequests.isEmpty }
        controller.update(translationX: -0.3, translationY: 0.15)
        try controller.finish(translationX: -0.3, translationY: 0.15)

        #expect(catalog.requestedScopes == [preferences.windowScope])
        #expect(presenter.shows.count == 1)
        #expect(presenter.shows.first?.windowCount == windows.count)
        #expect(presenter.shows.first?.cardSize == .large)
        #expect(presenter.hideCount == 1)
        #expect(catalog.activated.count == 1)
        #expect(Set(thumbnails.captureRequests[0]) == Set(windows.map(\.windowID)))
        #expect(thumbnails.captureRequests[0].count == windows.count)
    }

    @Test("Disabled or cancelled switcher never activates a window")
    func windowSwitcherControllerDisabledAndCancelled() throws {
        let catalog = MockWindowCatalog(windows: [makeTestWindow(id: 70)])
        let presenter = MockWindowSwitcherPresenter()
        let controller = WindowSwitcherController(
            catalog: catalog,
            thumbnails: MockWindowThumbnailProvider(),
            presenter: presenter
        )

        try controller.begin(translationX: 0, translationY: 0)
        #expect(catalog.requestedScopes.isEmpty)
        #expect(presenter.shows.isEmpty)

        controller.setEnabled(true)
        try controller.begin(translationX: 0, translationY: 0)
        controller.cancel()

        #expect(presenter.hideCount == 1)
        #expect(catalog.activated.isEmpty)
    }

    @Test("Window switcher reports an empty catalog without showing an overlay")
    func windowSwitcherControllerRejectsEmptyCatalog() {
        let presenter = MockWindowSwitcherPresenter()
        let controller = WindowSwitcherController(
            catalog: MockWindowCatalog(windows: []),
            thumbnails: MockWindowThumbnailProvider(),
            presenter: presenter
        )
        controller.setEnabled(true)

        #expect(throws: WindowCatalogError.self) {
            try controller.begin(translationX: 0, translationY: 0)
        }
        #expect(presenter.shows.isEmpty)
        #expect(presenter.hideCount == 0)
    }

    private func makeTestWindow(id: CGWindowID) -> SwitchableWindow {
        let application = AXUIElementCreateApplication(getpid())
        return SwitchableWindow(
            id: id,
            windowID: id,
            processID: getpid(),
            title: "Window \(id)",
            applicationName: "Tests",
            bounds: CGRect(x: 0, y: 0, width: 800, height: 600),
            applicationIcon: NSImage(size: NSSize(width: 32, height: 32)),
            applicationElement: application,
            windowElement: application,
            thumbnail: nil
        )
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
private final class MockCoreAudioAccess: CoreAudioAccessing {
    let device: AudioObjectID = 7
    var volume: Float32
    var isMuted: Bool?
    var defaultDeviceReads = 0
    var volumeReads = 0
    var volumeWrites: [Float32] = []
    var muteWrites: [Bool] = []

    init(volume: Float32, isMuted: Bool?) {
        self.volume = volume
        self.isMuted = isMuted
    }

    func defaultOutputDevice() throws -> AudioObjectID {
        defaultDeviceReads += 1
        return device
    }

    func validateVolumeControl(on _: AudioObjectID) throws {}

    func setVolume(_ volume: Float32, on _: AudioObjectID) throws {
        self.volume = volume
        volumeWrites.append(volume)
    }

    func currentVolume(on _: AudioObjectID) throws -> Float32 {
        volumeReads += 1
        return volume
    }

    func currentMuteState(on _: AudioObjectID) throws -> Bool? { isMuted }

    func setMuted(_ muted: Bool, on _: AudioObjectID) throws {
        isMuted = muted
        muteWrites.append(muted)
    }
}

@MainActor
private final class MockAudioController: AudioControlling {
    struct Adjustment {
        let up: Bool
        let stepCount: Int
        let stepPercentage: Int
    }

    var adjustments: [Adjustment] = []
    var toggleCount = 0

    func adjustVolume(up: Bool, stepCount: Int, stepPercentage: Int) throws -> Float32 {
        adjustments.append(.init(up: up, stepCount: stepCount, stepPercentage: stepPercentage))
        return 0.72
    }

    func toggleMute() throws -> (isMuted: Bool, volume: Float32) {
        toggleCount += 1
        return (true, 0.72)
    }
}

@MainActor
private final class MockMediaKeyController: MediaKeyControlling {
    var succeeds = true
    var pressCount = 0

    func pressPlayPause() -> Bool {
        pressCount += 1
        return succeeds
    }
}

@MainActor
private final class MockVolumeHUDController: VolumeHUDControlling {
    var prepareCount = 0
    var levels: [Double] = []

    func prepare() { prepareCount += 1 }
    func updateAppearance(_: OverlayAppearancePreferences) {}
    func updatePercentageAlignment(_: SoundBarPercentageAlignment) {}
    func show(level: Double) { levels.append(level) }
}

@MainActor
private final class MockPermissionSystemAccess: PermissionSystemAccessing {
    var bundleIdentifier = "app.keyflow.tests"
    var applicationURL = URL(fileURLWithPath: "/Applications/KeyFlow.app")
    var accessibility = false
    var inputMonitoring = false
    var postEvent = false
    var screenRecording = false
    var requestInputResult = false
    var requestPostResult = false
    var requestScreenResult = false
    var accessibilityRequestCount = 0
    var inputRequestCount = 0
    var postEventRequestCount = 0
    var screenRequestCount = 0
    var openResults: [Bool] = []
    var openedURLs: [URL] = []
    var revealedURLs: [URL] = []
    var resetResult: (status: Int32, error: String) = (0, "")
    var resetRequests: [(service: String, bundleIdentifier: String)] = []

    func accessibilityGranted() -> Bool { accessibility }
    func inputMonitoringGranted() -> Bool { inputMonitoring }
    func postEventGranted() -> Bool { postEvent }
    func screenRecordingGranted() -> Bool { screenRecording }
    func requestAccessibility() { accessibilityRequestCount += 1 }
    func requestInputMonitoring() -> Bool {
        inputRequestCount += 1
        return requestInputResult
    }
    func requestPostEvent() -> Bool {
        postEventRequestCount += 1
        return requestPostResult
    }
    func requestScreenRecording() -> Bool {
        screenRequestCount += 1
        return requestScreenResult
    }
    func reset(service: String, bundleIdentifier: String) async -> (status: Int32, error: String) {
        resetRequests.append((service, bundleIdentifier))
        return resetResult
    }
    func open(_ url: URL) -> Bool {
        openedURLs.append(url)
        return openResults.isEmpty ? true : openResults.removeFirst()
    }
    func revealInFinder(_ url: URL) { revealedURLs.append(url) }
}

@MainActor
private final class MockLoginItemRegistration: LoginItemRegistration {
    var isEnabled = false
    var registerCount = 0
    var unregisterCount = 0

    func register() throws {
        registerCount += 1
        isEnabled = true
    }

    func unregister() throws {
        unregisterCount += 1
        isEnabled = false
    }
}

@MainActor
private final class MockWindowCatalog: WindowCataloging {
    let windows: [SwitchableWindow]
    var requestedScopes: [WindowSwitcherWindowScope] = []
    var activated: [CGWindowID] = []

    init(windows: [SwitchableWindow]) {
        self.windows = windows
    }

    func availableWindows(scope: WindowSwitcherWindowScope) -> [SwitchableWindow] {
        requestedScopes.append(scope)
        return windows
    }

    func activate(_ window: SwitchableWindow) throws {
        activated.append(window.windowID)
    }
}

@MainActor
private final class MockWindowThumbnailProvider: WindowThumbnailProviding {
    var cached: [CGWindowID: NSImage] = [:]
    var captureRequests: [[CGWindowID]] = []
    var captured: [CGWindowID: NSImage] = [:]

    func cachedThumbnails(for _: [SwitchableWindow]) -> [CGWindowID: NSImage] { cached }

    func thumbnails(
        for windows: [SwitchableWindow],
        onUpdate: (([CGWindowID: NSImage]) -> Void)?
    ) async -> [CGWindowID: NSImage] {
        captureRequests.append(windows.map(\.windowID))
        onUpdate?(captured)
        return captured
    }
}

@MainActor
private final class MockWindowSwitcherPresenter: WindowSwitcherPresenting {
    struct Presentation {
        let windowCount: Int
        let cardSize: WindowSwitcherCardSize
    }

    var shows: [Presentation] = []
    var hideCount = 0

    func show(windowCount: Int, cardSize: WindowSwitcherCardSize) {
        shows.append(.init(windowCount: windowCount, cardSize: cardSize))
    }

    func hide() { hideCount += 1 }
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
