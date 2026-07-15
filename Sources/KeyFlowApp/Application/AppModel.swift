import AppKit
import Combine
import Foundation
import KeyFlowCore
import UniformTypeIdentifiers

@MainActor
final class AppModel: ObservableObject {
    @Published private(set) var mappings: [Mapping] = []
    @Published private(set) var revision = 0
    @Published private(set) var engineStatus: KeyboardEngineStatus = .stopped
    @Published private(set) var activities: [ActivityRecord] = []
    @Published private(set) var multitouchStatus: MultitouchProviderStatus = .starting
    @Published private(set) var rawTouchContactCount = 0
    @Published private(set) var windowSwitcherPreferences: WindowSwitcherPreferences = .default
    @Published private(set) var gestureSettings: GestureSettings = .default
    @Published private(set) var applicationPreferences: ApplicationPreferences = .default
    @Published private(set) var dockVisibilityRequiresRelaunch = false
    @Published private(set) var macOSScreenshotDestinationDescription: String
    @Published private(set) var permissionStatus: PermissionStatus
    @Published private(set) var launchAtLoginEnabled: Bool
    @Published var isPaused = false
    @Published var isRecording = false
    @Published var selectedMappingID: UUID?
    @Published var errorMessage: String?

    private let repository: any ConfigurationStoring
    private let permissionService: any PermissionServicing
    private let loginItemService: any LoginItemServicing
    private let actionExecutor: any ActionExecuting
    private let runtime: any RuntimeControlling
    private let diagnosticsExporter: any DiagnosticsExporting
    private let windowSwitcher: any WindowSwitching
    private let applicationPresentation: any ApplicationPresentationControlling
    private var started = false
    private var interactiveStartedAt: Date?
    private var continuousVolumeStartedAt: Date?
    private var continuousVolumeFailure: String?
    private var pendingContinuousActivities: [UUID: ActivityRecord] = [:]
    private var continuousActivityFlushTasks: [UUID: Task<Void, Never>] = [:]

    init(
        repository: any ConfigurationStoring = ConfigurationRepository(),
        permissionService: any PermissionServicing = SystemPermissionService(),
        loginItemService: any LoginItemServicing = SystemLoginItemService(),
        actionExecutor: (any ActionExecuting)? = nil,
        runtime: (any RuntimeControlling)? = nil,
        diagnosticsExporter: (any DiagnosticsExporting)? = nil,
        windowSwitcher: (any WindowSwitching)? = nil,
        applicationPresentation: (any ApplicationPresentationControlling)? = nil,
        syntheticMarker: Int64 = Int64.random(in: 1...Int64.max)
    ) {
        self.repository = repository
        self.permissionService = permissionService
        self.loginItemService = loginItemService
        self.actionExecutor = actionExecutor ?? ActionExecutor(syntheticMarker: syntheticMarker)
        self.runtime = runtime ?? AppRuntimeController(syntheticMarker: syntheticMarker)
        self.diagnosticsExporter = diagnosticsExporter ?? SystemDiagnosticsExporter()
        self.windowSwitcher = windowSwitcher ?? WindowSwitcherController()
        self.applicationPresentation = applicationPresentation ?? SystemApplicationPresentationController()
        permissionStatus = permissionService.currentStatus()
        launchAtLoginEnabled = loginItemService.isEnabled
        macOSScreenshotDestinationDescription = SystemScreenshotSettings.destinationDescription()
        configureRuntimeCallbacks()
    }

    func startIfNeeded() async {
        guard !started else { return }
        started = true
        do {
            let configuration = try await repository.load()
            mappings = configuration.mappings
            revision = configuration.revision
            windowSwitcherPreferences = configuration.windowSwitcherPreferences
            gestureSettings = configuration.gestureSettings
            applicationPreferences = configuration.applicationPreferences
            applicationPresentation.prepareHiddenFromDock(configuration.applicationPreferences.hideFromDock)
            dockVisibilityRequiresRelaunch =
                applicationPresentation.isHiddenFromDock != configuration.applicationPreferences.hideFromDock
            windowSwitcher.update(preferences: configuration.windowSwitcherPreferences)
            windowSwitcher.update(appearance: configuration.windowSwitcherPreferences.appearance)
            actionExecutor.updateVolumeHUDAppearance(configuration.gestureSettings.volumePreferences.hudAppearance)
            actionExecutor.updateVolumeHUDPercentageAlignment(
                configuration.gestureSettings.volumePreferences.percentageAlignment
            )
            windowSwitcher.setEnabled(configuration.gestureSettings.interactiveWindowSwitcherEnabled)
            selectedMappingID = mappings.first(where: { $0.trigger.kind == .keyboard })?.id
        } catch {
            KeyFlowLog.configuration.error("Configuration load failed: \(error.localizedDescription, privacy: .public)")
            errorMessage = "Could not load configuration: \(error.localizedDescription)"
        }
        refreshSystemScreenshotDestination()
        publishRuntimeSnapshot()
        refreshPermissions(restartRuntime: false)
        runtime.start()
    }

    func addMapping() {
        addKeyboardMapping()
    }

    func addKeyboardMapping() {
        let mapping = Mapping.newMapping()
        mappings.append(mapping)
        selectedMappingID = mapping.id
        commitChanges()
    }

    func chooseApplication(forMappingID mappingID: UUID) {
        let panel = NSOpenPanel()
        panel.title = "Choose an Application"
        panel.prompt = "Choose Application"
        panel.message = "Select the application this keyboard shortcut should open."
        panel.directoryURL = URL(fileURLWithPath: "/Applications", isDirectory: true)
        panel.allowedContentTypes = [.applicationBundle]
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.treatsFilePackagesAsDirectories = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        setApplication(url, forMappingID: mappingID)
    }

    func setApplication(_ url: URL, forMappingID mappingID: UUID) {
        guard let selection = ApplicationSelection.selection(for: url) else {
            errorMessage = "Choose a valid macOS application."
            return
        }
        updateMapping(id: mappingID) { mapping in
            mapping.action = .init(
                kind: .launchApplication,
                value: selection.bundleIdentifier ?? selection.url.path
            )
            if mapping.name == "Open Application" || mapping.name == "New Shortcut" {
                mapping.name = "Open \(selection.name)"
            }
        }
    }

    func setVolumeAdjustmentEnabled(_ enabled: Bool) {
        if enabled, !gestureSettings.volumeAdjustment.trigger.isAvailableForVolumeAdjustment {
            gestureSettings.volumeAdjustment.trigger = .fourFinger
        }
        gestureSettings.volumeAdjustment.isEnabled = enabled
        commitChanges()
    }

    func setVolumeAdjustmentTrigger(_ trigger: VerticalGestureTrigger) {
        guard trigger.isAvailableForVolumeAdjustment else {
            errorMessage = "Volume Adjustment supports four- or five-finger swipes."
            return
        }
        gestureSettings.volumeAdjustment.trigger = trigger
        commitChanges()
    }

    func setVolumeAdjustmentSpeed(_ speedMultiplier: Double) {
        gestureSettings.volumePreferences.speedMultiplier = min(max(speedMultiplier, 0.5), 2.5)
        commitChanges()
    }

    func setVolumeResponseMilliseconds(_ milliseconds: Int) {
        gestureSettings.volumePreferences = VolumeAdjustmentPreferences(
            speedMultiplier: gestureSettings.volumePreferences.speedMultiplier,
            responseMilliseconds: milliseconds,
            stepPercentage: gestureSettings.volumePreferences.stepPercentage,
            hudAppearance: gestureSettings.volumePreferences.hudAppearance,
            percentageAlignment: gestureSettings.volumePreferences.percentageAlignment
        )
        commitChanges()
    }

    func setVolumeStepPercentage(_ percentage: Int) {
        gestureSettings.volumePreferences = VolumeAdjustmentPreferences(
            speedMultiplier: gestureSettings.volumePreferences.speedMultiplier,
            responseMilliseconds: gestureSettings.volumePreferences.responseMilliseconds,
            stepPercentage: percentage,
            hudAppearance: gestureSettings.volumePreferences.hudAppearance,
            percentageAlignment: gestureSettings.volumePreferences.percentageAlignment
        )
        commitChanges()
    }

    func updateVolumeHUDAppearance(_ mutation: (inout OverlayAppearancePreferences) -> Void) {
        mutation(&gestureSettings.volumePreferences.hudAppearance)
        let appearance = gestureSettings.volumePreferences.hudAppearance
        gestureSettings.volumePreferences.hudAppearance = OverlayAppearancePreferences(
            theme: appearance.theme,
            surfaceStyle: appearance.surfaceStyle,
            backgroundColor: appearance.backgroundColor,
            accent: appearance.accent,
            customAccentColor: appearance.customAccentColor,
            backgroundOpacity: appearance.backgroundOpacity,
            cornerRadius: appearance.cornerRadius,
            showsBorder: appearance.showsBorder
        )
        actionExecutor.updateVolumeHUDAppearance(gestureSettings.volumePreferences.hudAppearance)
        commitChanges()
    }

    func setVolumeHUDPercentageAlignment(_ alignment: SoundBarPercentageAlignment) {
        gestureSettings.volumePreferences.percentageAlignment = alignment
        actionExecutor.updateVolumeHUDPercentageAlignment(alignment)
        commitChanges()
    }

    func resetVolumeHUDAppearance() {
        gestureSettings.volumePreferences.hudAppearance = .default
        gestureSettings.volumePreferences.percentageAlignment = .left
        actionExecutor.updateVolumeHUDAppearance(.default)
        actionExecutor.updateVolumeHUDPercentageAlignment(.left)
        commitChanges()
    }

    func previewVolumeHUD() {
        actionExecutor.previewVolumeHUD()
    }

    func setGestureFeatureEnabled(_ feature: GestureFeature, enabled: Bool) {
        if enabled {
            let trigger = discreteSetting(for: feature).trigger
            if let owner = gestureSettings.owner(of: trigger, excluding: feature) {
                errorMessage = "\(trigger.displayName) is already used by \(owner.displayName)."
                return
            }
        }
        mutateDiscreteSetting(for: feature) { $0.isEnabled = enabled }
        commitChanges()
    }

    func setGestureFeatureTrigger(_ feature: GestureFeature, trigger: DiscreteGestureTrigger) {
        if let owner = gestureSettings.owner(of: trigger, excluding: feature) {
            errorMessage = "\(trigger.displayName) is already used by \(owner.displayName)."
            return
        }
        mutateDiscreteSetting(for: feature) { $0.trigger = trigger }
        commitChanges()
    }

    func setInteractiveWindowSwitcherEnabled(_ enabled: Bool) {
        gestureSettings.interactiveWindowSwitcherEnabled = enabled
        windowSwitcher.setEnabled(enabled)
        commitChanges()
    }

    func setScreenshotStorageMode(_ mode: ScreenshotStorageMode) {
        if mode == .customFolder,
            gestureSettings.screenshotStorage.customFolderPath?.isEmpty != false
        {
            chooseScreenshotFolder()
            return
        }
        gestureSettings.screenshotStorage.mode = mode
        commitChanges()
    }

    func setAdditionalScreenshotCopyEnabled(_ enabled: Bool) {
        gestureSettings.screenshotStorage.saveAdditionalCopy = enabled
        commitChanges()
    }

    func chooseScreenshotFolder() {
        let panel = NSOpenPanel()
        panel.title = "Choose Screenshot Folder"
        panel.prompt = "Choose"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        if let path = gestureSettings.screenshotStorage.customFolderPath {
            panel.directoryURL = URL(fileURLWithPath: path, isDirectory: true)
        }
        guard panel.runModal() == .OK, let url = panel.url else { return }
        setCustomScreenshotFolder(url)
    }

    func setCustomScreenshotFolder(_ url: URL) {
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory), isDirectory.boolValue else {
            errorMessage = "Choose an existing folder for screenshots."
            return
        }
        gestureSettings.screenshotStorage.customFolderPath = url.standardizedFileURL.path
        gestureSettings.screenshotStorage.mode = .customFolder
        commitChanges()
    }

    func refreshSystemScreenshotDestination() {
        macOSScreenshotDestinationDescription = SystemScreenshotSettings.destinationDescription()
    }

    var screenshotStorageStatusDescription: String {
        switch gestureSettings.screenshotStorage.mode {
        case .systemDefault:
            let directory = SystemScreenshotSettings.current().fileDirectory
            let name = directory.lastPathComponent.isEmpty ? directory.path : directory.lastPathComponent
            return "File copy: \(name) — \(directory.path)"
        case .customFolder:
            if let path = gestureSettings.screenshotStorage.customFolderPath, !path.isEmpty {
                return "File copy: \(path)"
            } else {
                return "File copy: No folder selected"
            }
        }
    }

    func deleteMapping(id: UUID) {
        mappings.removeAll { $0.id == id }
        selectedMappingID = mappings.first(where: { $0.trigger.kind == .keyboard })?.id
        commitChanges()
    }

    func updateMapping(id: UUID, mutation: (inout Mapping) -> Void) {
        guard let index = mappings.firstIndex(where: { $0.id == id }) else { return }
        mutation(&mappings[index])
        mappings[index].updatedAt = .now
        commitChanges()
    }

    func updateWindowSwitcherPreferences(_ mutation: (inout WindowSwitcherPreferences) -> Void) {
        mutation(&windowSwitcherPreferences)
        windowSwitcher.update(preferences: windowSwitcherPreferences)
        windowSwitcher.update(appearance: windowSwitcherPreferences.appearance)
        commitChanges()
    }

    func resetWindowSwitcherPreferences() {
        windowSwitcherPreferences = .default
        windowSwitcher.update(preferences: windowSwitcherPreferences)
        windowSwitcher.update(appearance: windowSwitcherPreferences.appearance)
        commitChanges()
    }

    func setPaused(_ paused: Bool) {
        isPaused = paused
        runtime.setPaused(paused || isRecording)
    }

    func setRecording(_ recording: Bool) {
        isRecording = recording
        runtime.setPaused(recording || isPaused)
    }

    func testMapping(_ mapping: Mapping) {
        guard MappingValidator.validate(mapping).isEmpty else {
            errorMessage = "Fix this mapping before testing it."
            return
        }
        guard mapping.action.kind != .windowSwitcher else {
            errorMessage = "Use the four-finger horizontal gesture to test the interactive window switcher."
            return
        }
        Task { await execute(mapping) }
    }

    func clearActivity() {
        for task in continuousActivityFlushTasks.values { task.cancel() }
        continuousActivityFlushTasks.removeAll()
        pendingContinuousActivities.removeAll()
        activities.removeAll()
    }

    func requestAccessibilityPermission() {
        permissionService.request(.accessibility)
        refreshPermissions()
    }

    func requestInputMonitoringPermission() {
        permissionService.request(.inputMonitoring)
        refreshPermissions()
    }

    func requestScreenRecordingPermission() {
        permissionService.request(.screenRecording)
        refreshPermissions()
    }

    func refreshPermissions() {
        refreshPermissions(restartRuntime: true)
    }

    func resetAccessibilityRegistration() {
        resetRegistration(for: .accessibility)
    }

    func resetInputMonitoringRegistration() {
        resetRegistration(for: .inputMonitoring)
    }

    func resetScreenRecordingRegistration() {
        resetRegistration(for: .screenRecording)
    }

    func revealApplicationInFinder() {
        permissionService.revealApplicationInFinder()
    }

    func exportDiagnostics() {
        let snapshot = DiagnosticsSnapshot(
            appVersion: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
                ?? "development",
            appBuild: Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "development",
            configurationSchema: KeyFlowConfiguration.currentSchemaVersion,
            configurationRevision: revision,
            mappingCount: mappings.count(where: { $0.trigger.kind == .keyboard }),
            enabledMappingCount: mappings.count(where: { $0.trigger.kind == .keyboard && $0.isEnabled }),
            keyboardStatus: keyboardStatusDescription,
            multitouchStatus: multitouchStatusDescription,
            accessibilityGranted: accessibilityGranted,
            inputMonitoringGranted: inputMonitoringGranted,
            postEventGranted: postEventGranted,
            screenRecordingGranted: screenRecordingGranted
        )
        do {
            if let url = try diagnosticsExporter.export(snapshot) {
                KeyFlowLog.application.notice("Diagnostics exported to \(url.path, privacy: .private)")
            }
        } catch {
            KeyFlowLog.application.error("Diagnostics export failed: \(error.localizedDescription, privacy: .public)")
            errorMessage = "Could not export diagnostics: \(error.localizedDescription)"
        }
    }

    var accessibilityGranted: Bool { permissionStatus.accessibilityGranted }
    var inputMonitoringGranted: Bool { permissionStatus.inputMonitoringGranted }
    var postEventGranted: Bool { permissionStatus.postEventGranted }
    var screenRecordingGranted: Bool { permissionStatus.screenRecordingGranted }
    var conflictingMappingIDs: Set<UUID> {
        MappingCollectionValidator.conflictingMappingIDs(in: mappings)
    }

    func discreteSetting(for feature: GestureFeature) -> GestureFeatureSetting<DiscreteGestureTrigger> {
        switch feature {
        case .mute: gestureSettings.mute
        case .playPause: gestureSettings.playPause
        case .screenshot: gestureSettings.screenshot
        case .customScreenshot: gestureSettings.customScreenshot
        }
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            try loginItemService.setEnabled(enabled)
            launchAtLoginEnabled = loginItemService.isEnabled
        } catch {
            errorMessage = "Could not change launch-at-login: \(error.localizedDescription)"
        }
    }

    func setHiddenFromDock(_ hidden: Bool) {
        applicationPreferences.hideFromDock = hidden
        applicationPresentation.prepareHiddenFromDock(hidden)
        dockVisibilityRequiresRelaunch = applicationPresentation.isHiddenFromDock != hidden
        commitChanges()
    }

    func relaunchToApplyDockVisibility() {
        let configuration = currentConfiguration()
        Task { [weak self] in
            guard let self else { return }
            do {
                try await repository.save(configuration)
                try applicationPresentation.relaunch()
            } catch {
                errorMessage = "Could not relaunch KeyFlow: \(error.localizedDescription)"
            }
        }
    }

    private func configureRuntimeCallbacks() {
        runtime.onMapping = { [weak self] mapping in
            Task { @MainActor in await self?.execute(mapping) }
        }
        runtime.onKeyboardStatus = { [weak self] status in self?.engineStatus = status }
        runtime.onMultitouchStatus = { [weak self] status in self?.multitouchStatus = status }
        runtime.onContactCountChanged = { [weak self] count in self?.rawTouchContactCount = count }
        runtime.onContinuousVolume = { [weak self] mapping, stepCount in
            self?.executeContinuousVolume(mapping, stepCount: stepCount)
        }
        runtime.onContinuousVolumeEnded = { [weak self] mapping in
            self?.finishContinuousVolume(mapping)
        }
        runtime.onInteractiveWindowSwitcher = { [weak self] mapping, event in
            self?.handleInteractiveWindowSwitcher(mapping: mapping, event: event)
        }
    }

    private func refreshPermissions(restartRuntime: Bool) {
        let currentPermissionStatus = permissionService.currentStatus()
        if permissionStatus != currentPermissionStatus {
            permissionStatus = currentPermissionStatus
        }
        if restartRuntime, engineStatus == .stopped || isPermissionRequired {
            runtime.start()
        }
    }

    private var isPermissionRequired: Bool {
        if case .permissionRequired = engineStatus { return true }
        return false
    }

    private func resetRegistration(for permission: SystemPermission) {
        Task { [weak self] in
            guard let self else { return }
            do {
                try await permissionService.resetRegistration(for: permission)
                permissionStatus = permissionService.currentStatus()
                permissionService.openSettings(for: permission)
            } catch {
                KeyFlowLog.application.error("Permission reset failed: \(error.localizedDescription, privacy: .public)")
                errorMessage = error.localizedDescription
            }
        }
    }

    private func mutateDiscreteSetting(
        for feature: GestureFeature,
        mutation: (inout GestureFeatureSetting<DiscreteGestureTrigger>) -> Void
    ) {
        switch feature {
        case .mute: mutation(&gestureSettings.mute)
        case .playPause: mutation(&gestureSettings.playPause)
        case .screenshot: mutation(&gestureSettings.screenshot)
        case .customScreenshot: mutation(&gestureSettings.customScreenshot)
        }
    }

    private func commitChanges() {
        revision += 1
        publishRuntimeSnapshot()
        let configuration = currentConfiguration()
        Task { [weak self] in
            do {
                try await self?.repository.save(configuration)
            } catch {
                KeyFlowLog.configuration.error(
                    "Configuration save failed: \(error.localizedDescription, privacy: .public)")
                self?.errorMessage = "Could not save configuration: \(error.localizedDescription)"
            }
        }
    }

    private func publishRuntimeSnapshot() {
        runtime.update(snapshot: RuntimeSnapshot(configuration: currentConfiguration()))
    }

    private func currentConfiguration() -> KeyFlowConfiguration {
        KeyFlowConfiguration(
            revision: revision,
            mappings: mappings,
            windowSwitcherPreferences: windowSwitcherPreferences,
            gestureSettings: gestureSettings,
            applicationPreferences: applicationPreferences
        )
    }

    private func execute(_ mapping: Mapping) async {
        let startedAt = Date()
        do {
            try await actionExecutor.execute(
                mapping.action,
                screenshotStorage: gestureSettings.screenshotStorage
            )
            let activity = ActivityRecord(
                timestamp: startedAt,
                mappingName: mapping.name,
                trigger: mapping.trigger.displayName,
                action: mapping.action.kind.displayName,
                outcome: .succeeded
            )
            if mapping.action.kind == .volumeUp || mapping.action.kind == .volumeDown {
                enqueueContinuousActivity(activity, mappingID: mapping.id)
            } else {
                appendActivity(activity)
            }
        } catch {
            KeyFlowLog.actions.error("Action failed: \(error.localizedDescription, privacy: .public)")
            appendActivity(
                .init(
                    timestamp: startedAt,
                    mappingName: mapping.name,
                    trigger: mapping.trigger.displayName,
                    action: mapping.action.kind.displayName,
                    outcome: .failed(error.localizedDescription)
                ))
        }
    }

    private func executeContinuousVolume(_ mapping: Mapping, stepCount: Int) {
        if continuousVolumeStartedAt == nil {
            continuousVolumeStartedAt = .now
            continuousVolumeFailure = nil
        }
        do {
            try actionExecutor.executeContinuousVolume(
                mapping.action,
                stepCount: stepCount,
                stepPercentage: gestureSettings.volumePreferences.stepPercentage
            )
        } catch {
            if continuousVolumeFailure == nil {
                continuousVolumeFailure = error.localizedDescription
                KeyFlowLog.actions.error(
                    "Continuous volume failed: \(error.localizedDescription, privacy: .public)"
                )
            }
        }
    }

    private func finishContinuousVolume(_ mapping: Mapping) {
        guard let startedAt = continuousVolumeStartedAt else { return }
        let outcome: ActivityRecord.Outcome = continuousVolumeFailure.map(ActivityRecord.Outcome.failed) ?? .succeeded
        appendActivity(for: mapping, startedAt: startedAt, outcome: outcome)
        continuousVolumeStartedAt = nil
        continuousVolumeFailure = nil
    }

    private func handleInteractiveWindowSwitcher(mapping: Mapping, event: GestureRecognitionEvent) {
        do {
            switch event {
            case let .horizontalBegan(translationX, translationY):
                interactiveStartedAt = .now
                try windowSwitcher.begin(translationX: translationX, translationY: translationY)
            case let .horizontalChanged(translationX, translationY):
                windowSwitcher.update(translationX: translationX, translationY: translationY)
            case let .horizontalEnded(translationX, translationY):
                try windowSwitcher.finish(translationX: translationX, translationY: translationY)
                appendActivity(for: mapping, startedAt: interactiveStartedAt ?? .now, outcome: .succeeded)
                interactiveStartedAt = nil
            case .horizontalCancelled:
                windowSwitcher.cancel()
                interactiveStartedAt = nil
            case .discrete, .verticalChanged, .verticalEnded, .verticalCancelled:
                break
            }
        } catch {
            windowSwitcher.cancel()
            appendActivity(
                for: mapping, startedAt: interactiveStartedAt ?? .now, outcome: .failed(error.localizedDescription))
            interactiveStartedAt = nil
            KeyFlowLog.actions.error("Window switcher failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func appendActivity(for mapping: Mapping, startedAt: Date, outcome: ActivityRecord.Outcome) {
        appendActivity(
            .init(
                timestamp: startedAt,
                mappingName: mapping.name,
                trigger: mapping.trigger.displayName,
                action: mapping.action.kind.displayName,
                outcome: outcome
            )
        )
    }

    private func enqueueContinuousActivity(_ activity: ActivityRecord, mappingID: UUID) {
        if let pending = pendingContinuousActivities[mappingID] {
            pendingContinuousActivities[mappingID] = ActivityRecord(
                id: pending.id,
                timestamp: activity.timestamp,
                mappingName: pending.mappingName,
                trigger: pending.trigger,
                action: pending.action,
                outcome: pending.outcome,
                occurrenceCount: pending.occurrenceCount + activity.occurrenceCount
            )
        } else {
            pendingContinuousActivities[mappingID] = activity
        }
        guard continuousActivityFlushTasks[mappingID] == nil else { return }
        continuousActivityFlushTasks[mappingID] = Task { [weak self] in
            do {
                try await Task.sleep(for: .milliseconds(400))
            } catch {
                return
            }
            guard let self else { return }
            continuousActivityFlushTasks[mappingID] = nil
            guard let pending = pendingContinuousActivities.removeValue(forKey: mappingID) else { return }
            appendActivity(pending)
        }
    }

    private func appendActivity(_ activity: ActivityRecord) {
        if let latest = activities.first,
            activity.timestamp.timeIntervalSince(latest.timestamp) <= 0.6,
            latest.mappingName == activity.mappingName,
            latest.trigger == activity.trigger,
            latest.action == activity.action,
            latest.outcome == activity.outcome
        {
            activities[0] = ActivityRecord(
                id: latest.id,
                timestamp: activity.timestamp,
                mappingName: latest.mappingName,
                trigger: latest.trigger,
                action: latest.action,
                outcome: latest.outcome,
                occurrenceCount: latest.occurrenceCount + activity.occurrenceCount
            )
            return
        }
        activities.insert(activity, at: 0)
        if activities.count > 100 { activities.removeLast(activities.count - 100) }
    }

    private var keyboardStatusDescription: String {
        switch engineStatus {
        case .stopped: "stopped"
        case .starting: "starting"
        case .running: "running"
        case let .permissionRequired(permission): "permission required: \(permission)"
        case let .failed(message): "failed: \(message)"
        }
    }

    private var multitouchStatusDescription: String {
        switch multitouchStatus {
        case .starting: "starting"
        case .running: "running"
        case .unavailable: "unavailable"
        case .failed: "failed"
        }
    }
}
