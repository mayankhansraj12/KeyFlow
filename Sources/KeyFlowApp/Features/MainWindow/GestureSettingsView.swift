import KeyFlowCore
import SwiftUI

struct GestureSettingsView: View {
    private static let settingsControlWidth: CGFloat = 270

    @EnvironmentObject private var model: AppModel
    @State private var isVolumeAppearanceExpanded = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                pageHeader

                sectionCard(title: "Audio & Media", icon: "speaker.wave.2.fill") {
                    volumeFeatureRow
                    featureDivider
                    discreteFeatureRow(
                        feature: .mute,
                        icon: "speaker.slash.fill",
                        description: "Mute or restore system audio."
                    )
                    featureDivider
                    discreteFeatureRow(
                        feature: .playPause,
                        icon: "playpause.fill",
                        description: "Play or pause the active media application."
                    )
                }

                sectionCard(title: "Screenshots", icon: "camera.fill") {
                    discreteFeatureRow(
                        feature: .screenshot,
                        icon: "camera.viewfinder",
                        description: "Capture the complete screen."
                    )
                    featureDivider
                    discreteFeatureRow(
                        feature: .customScreenshot,
                        icon: "rectangle.dashed",
                        description: "Select an area or window with the native macOS interface."
                    )
                    featureDivider
                    macOSDestinationRow
                    additionalCopyPanel
                }

                Label(
                    "Configure the interactive window switcher from the Switcher tab.",
                    systemImage: "rectangle.3.group"
                )
                .font(.footnote)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 4)
            }
            .frame(maxWidth: 880, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.vertical, 18)
            .frame(maxWidth: .infinity)
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear { model.refreshSystemScreenshotDestination() }
    }

    private var pageHeader: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("Gestures")
                .font(.title2.weight(.semibold))
            Text("Assign one gesture to each feature. Gestures already in use are marked unavailable.")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
    }

    private func sectionCard<Content: View>(
        title: String,
        icon: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Label(title, systemImage: icon)
                .font(.headline)
                .padding(.horizontal, 14)
                .padding(.vertical, 11)
            Divider()
            VStack(alignment: .leading, spacing: 0) {
                content()
            }
            .padding(14)
        }
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 14))
        .overlay {
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        }
    }

    private var volumeFeatureRow: some View {
        VStack(alignment: .leading, spacing: 9) {
            featureHeader(
                title: "Volume Adjustment",
                icon: "speaker.wave.3.fill",
                description: "Swipe continuously to raise or lower volume.",
                isEnabled: volumeEnabledBinding
            )
            settingsLine(title: "Gesture") {
                Picker("Gesture", selection: volumeTriggerBinding) {
                    ForEach(VerticalGestureTrigger.volumeAdjustmentCases) { trigger in
                        Text(trigger.displayName).tag(trigger)
                    }
                }
                .labelsHidden()
                .frame(width: Self.settingsControlWidth, alignment: .trailing)
            }
            volumeBehaviorPanel
        }
    }

    private var volumeBehaviorPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Adjustment Behavior", systemImage: "slider.horizontal.3")
                .font(.callout.weight(.semibold))

            settingsLine(title: "Speed") {
                HStack(spacing: 10) {
                    Slider(value: volumeSpeedBinding, in: 0.5...2.5, step: 0.25)
                    Text(
                        model.gestureSettings.volumePreferences.speedMultiplier,
                        format: .number.precision(.fractionLength(2))
                    )
                    .monospacedDigit()
                    .frame(width: 38, alignment: .trailing)
                    Text("×")
                        .foregroundStyle(.secondary)
                }
                .frame(width: Self.settingsControlWidth)
            }

            settingsLine(title: "Response time") {
                Picker("Response time", selection: volumeResponseBinding) {
                    ForEach(VolumeAdjustmentPreferences.allowedResponseMilliseconds, id: \.self) { milliseconds in
                        Text("\(milliseconds) ms").tag(milliseconds)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .frame(width: Self.settingsControlWidth, alignment: .trailing)
            }

            settingsLine(title: "Change per step") {
                Picker("Change per step", selection: volumeStepPercentageBinding) {
                    ForEach(VolumeAdjustmentPreferences.allowedStepPercentages, id: \.self) { percentage in
                        Text("\(percentage)%").tag(percentage)
                    }
                }
                .labelsHidden()
                .pickerStyle(.segmented)
                .frame(width: Self.settingsControlWidth)
            }

            Text(
                "Speed controls how quickly continued movement repeats. Response time delays the first change; choose 0 ms for immediate response."
            )
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.leading, 40)

            Divider()
                .padding(.vertical, 1)

            DisclosureGroup(isExpanded: $isVolumeAppearanceExpanded) {
                volumeAppearanceControls
                    .padding(.top, 10)
            } label: {
                HStack {
                    Label("Configure Appearance", systemImage: "paintpalette")
                        .font(.callout.weight(.semibold))
                    Spacer()
                    if model.gestureSettings.volumePreferences.hudAppearance != .default {
                        Button("Default") { model.resetVolumeHUDAppearance() }
                            .buttonStyle(.borderless)
                            .font(.caption)
                    }
                }
            }
        }
        .padding(12)
        .background(Color.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 10))
        .disabled(!model.gestureSettings.volumeAdjustment.isEnabled)
        .opacity(model.gestureSettings.volumeAdjustment.isEnabled ? 1 : 0.55)
    }

    private var volumeAppearanceControls: some View {
        VStack(alignment: .leading, spacing: 9) {
            volumeHUDPreview

            settingsLine(title: "Theme") {
                Picker("Theme", selection: volumeHUDThemeBinding) {
                    ForEach(OverlayTheme.allCases) { theme in
                        Text(theme.displayName).tag(theme)
                    }
                }
                .labelsHidden()
                .pickerStyle(.segmented)
                .frame(width: Self.settingsControlWidth)
            }

            settingsLine(title: "Background") {
                HStack(spacing: 8) {
                    Picker("Surface", selection: volumeHUDSurfaceBinding) {
                        ForEach(OverlaySurfaceStyle.allCases) { style in
                            Text(style.displayName).tag(style)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.segmented)

                    Picker("Color", selection: volumeHUDBackgroundBinding) {
                        ForEach(OverlayBackgroundColor.allCases) { color in
                            Text(color.displayName).tag(color)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .frame(width: 105)
                }
                .frame(width: Self.settingsControlWidth)
            }

            settingsLine(title: "Accent") {
                Picker("Accent", selection: volumeHUDAccentBinding) {
                    ForEach(WindowSwitcherAccent.allCases) { accent in
                        Text(accent.displayName).tag(accent)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .frame(width: Self.settingsControlWidth, alignment: .trailing)
            }

            settingsLine(title: "Opacity") {
                HStack(spacing: 8) {
                    Slider(value: volumeHUDOpacityBinding, in: 0.45...1, step: 0.05)
                    Text("\(Int((volumeHUDAppearance.backgroundOpacity * 100).rounded()))%")
                        .font(.caption.monospacedDigit())
                        .frame(width: 34, alignment: .trailing)
                }
                .frame(width: Self.settingsControlWidth)
            }

            settingsLine(title: "Shape") {
                HStack(spacing: 8) {
                    Slider(value: volumeHUDCornerRadiusBinding, in: 10...30, step: 1)
                    Text("\(Int(volumeHUDAppearance.cornerRadius.rounded()))")
                        .font(.caption.monospacedDigit())
                        .frame(width: 20, alignment: .trailing)
                    Toggle("Border", isOn: volumeHUDBorderBinding)
                        .toggleStyle(.checkbox)
                        .font(.caption)
                }
                .frame(width: Self.settingsControlWidth)
            }
        }
    }

    private var volumeHUDPreview: some View {
        HStack(spacing: 11) {
            Image(systemName: "speaker.wave.2.fill")
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.secondary.opacity(0.22))
                    Capsule()
                        .fill(volumeHUDAppearance.swiftUIAccentColor)
                        .frame(width: proxy.size.width * 0.64)
                }
            }
            .frame(height: 7)
            Text("64%")
                .font(.caption.monospacedDigit().weight(.semibold))
        }
        .padding(.horizontal, 14)
        .frame(width: 250, height: 48)
        .background(volumeHUDPreviewBackground)
        .clipShape(
            RoundedRectangle(
                cornerRadius: volumeHUDAppearance.cornerRadius * 0.8,
                style: .continuous
            )
        )
        .overlay {
            if volumeHUDAppearance.showsBorder {
                RoundedRectangle(
                    cornerRadius: volumeHUDAppearance.cornerRadius * 0.8,
                    style: .continuous
                )
                .stroke(Color.primary.opacity(0.14), lineWidth: 1)
            }
        }
        .preferredColorScheme(volumeHUDAppearance.preferredColorScheme)
        .frame(maxWidth: .infinity, alignment: .center)
    }

    @ViewBuilder
    private var volumeHUDPreviewBackground: some View {
        let shape = RoundedRectangle(
            cornerRadius: volumeHUDAppearance.cornerRadius * 0.8,
            style: .continuous
        )
        if volumeHUDAppearance.surfaceStyle == .frosted {
            ZStack {
                shape.fill(.ultraThickMaterial)
                shape.fill(
                    volumeHUDAppearance.swiftUIBackgroundColor.opacity(
                        volumeHUDAppearance.backgroundOpacity * 0.34
                    )
                )
            }
        } else {
            shape.fill(
                volumeHUDAppearance.swiftUIBackgroundColor.opacity(
                    volumeHUDAppearance.backgroundOpacity
                )
            )
        }
    }

    private func discreteFeatureRow(
        feature: GestureFeature,
        icon: String,
        description: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            featureHeader(
                title: feature.displayName,
                icon: icon,
                description: description,
                isEnabled: featureEnabledBinding(feature)
            )
            settingsLine(title: "Gesture") {
                Picker("Gesture", selection: featureTriggerBinding(feature)) {
                    ForEach(DiscreteGestureTrigger.allCases) { trigger in
                        if let owner = model.gestureSettings.owner(of: trigger, excluding: feature) {
                            Text("\(trigger.displayName) — Used by \(owner.displayName)")
                                .tag(trigger)
                                .disabled(true)
                        } else {
                            Text(trigger.displayName).tag(trigger)
                        }
                    }
                }
                .labelsHidden()
                .frame(width: Self.settingsControlWidth, alignment: .trailing)
            }
            if model.gestureSettings.conflictingFeatures.contains(feature) {
                Label(
                    "Resolve this duplicate gesture before enabling the feature.",
                    systemImage: "exclamationmark.triangle.fill"
                )
                .font(.caption)
                .foregroundStyle(.orange)
            }
        }
    }

    private func featureHeader(
        title: String,
        icon: String,
        description: String,
        isEnabled: Binding<Bool>
    ) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(Color.accentColor)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                Text(description)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 16)
            Toggle("Enabled", isOn: isEnabled)
                .labelsHidden()
                .toggleStyle(.switch)
        }
    }

    private func settingsLine<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        HStack(spacing: 16) {
            Text(title)
                .font(.callout.weight(.medium))
                .foregroundStyle(.secondary)
            Spacer()
            content()
        }
        .padding(.leading, 40)
    }

    private var macOSDestinationRow: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: macOSScreenshotDestinationIcon)
                .foregroundStyle(.secondary)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 3) {
                Text("macOS screenshot destination")
                    .font(.callout.weight(.medium))
                Text(model.macOSScreenshotDestinationDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
        }
        .padding(.bottom, 14)
    }

    private var additionalCopyPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle("Save an additional file copy", isOn: additionalCopyEnabledBinding)
                .font(.callout.weight(.semibold))

            if model.gestureSettings.screenshotStorage.saveAdditionalCopy {
                Divider()
                settingsLine(title: "Save to") {
                    Picker("Save to", selection: screenshotStorageModeBinding) {
                        ForEach(ScreenshotStorageMode.allCases) { mode in
                            Text(mode.displayName).tag(mode)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.segmented)
                    .frame(width: Self.settingsControlWidth)
                }

                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "folder.fill")
                        .foregroundStyle(.secondary)
                    Text(model.screenshotStorageStatusDescription)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                    Spacer()
                }
                .padding(.leading, 40)

                if model.gestureSettings.screenshotStorage.mode == .customFolder {
                    HStack {
                        Spacer()
                        Button("Choose Folder…") { model.chooseScreenshotFolder() }
                    }
                }
            } else {
                Text("Off — screenshots only follow the macOS destination above.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .background(Color.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 10))
        .animation(.easeInOut(duration: 0.16), value: model.gestureSettings.screenshotStorage.saveAdditionalCopy)
    }

    private var featureDivider: some View {
        Divider()
            .padding(.vertical, 12)
    }

    private var volumeEnabledBinding: Binding<Bool> {
        Binding(
            get: { model.gestureSettings.volumeAdjustment.isEnabled },
            set: { model.setVolumeAdjustmentEnabled($0) }
        )
    }

    private var volumeTriggerBinding: Binding<VerticalGestureTrigger> {
        Binding(
            get: { model.gestureSettings.volumeAdjustment.trigger },
            set: { model.setVolumeAdjustmentTrigger($0) }
        )
    }

    private var volumeSpeedBinding: Binding<Double> {
        Binding(
            get: { model.gestureSettings.volumePreferences.speedMultiplier },
            set: { model.setVolumeAdjustmentSpeed($0) }
        )
    }

    private var volumeResponseBinding: Binding<Int> {
        Binding(
            get: { model.gestureSettings.volumePreferences.responseMilliseconds },
            set: { model.setVolumeResponseMilliseconds($0) }
        )
    }

    private var volumeStepPercentageBinding: Binding<Int> {
        Binding(
            get: { model.gestureSettings.volumePreferences.stepPercentage },
            set: { model.setVolumeStepPercentage($0) }
        )
    }

    private var volumeHUDAppearance: OverlayAppearancePreferences {
        model.gestureSettings.volumePreferences.hudAppearance
    }

    private var volumeHUDThemeBinding: Binding<OverlayTheme> {
        Binding(
            get: { volumeHUDAppearance.theme },
            set: { value in model.updateVolumeHUDAppearance { $0.theme = value } }
        )
    }

    private var volumeHUDSurfaceBinding: Binding<OverlaySurfaceStyle> {
        Binding(
            get: { volumeHUDAppearance.surfaceStyle },
            set: { value in model.updateVolumeHUDAppearance { $0.surfaceStyle = value } }
        )
    }

    private var volumeHUDBackgroundBinding: Binding<OverlayBackgroundColor> {
        Binding(
            get: { volumeHUDAppearance.backgroundColor },
            set: { value in
                model.updateVolumeHUDAppearance {
                    $0.backgroundColor = value
                    if value == .light { $0.theme = .light }
                    if value == .graphite || value == .midnight { $0.theme = .dark }
                }
            }
        )
    }

    private var volumeHUDAccentBinding: Binding<WindowSwitcherAccent> {
        Binding(
            get: { volumeHUDAppearance.accent },
            set: { value in model.updateVolumeHUDAppearance { $0.accent = value } }
        )
    }

    private var volumeHUDOpacityBinding: Binding<Double> {
        Binding(
            get: { volumeHUDAppearance.backgroundOpacity },
            set: { value in model.updateVolumeHUDAppearance { $0.backgroundOpacity = value } }
        )
    }

    private var volumeHUDCornerRadiusBinding: Binding<Double> {
        Binding(
            get: { volumeHUDAppearance.cornerRadius },
            set: { value in model.updateVolumeHUDAppearance { $0.cornerRadius = value } }
        )
    }

    private var volumeHUDBorderBinding: Binding<Bool> {
        Binding(
            get: { volumeHUDAppearance.showsBorder },
            set: { value in model.updateVolumeHUDAppearance { $0.showsBorder = value } }
        )
    }

    private var additionalCopyEnabledBinding: Binding<Bool> {
        Binding(
            get: { model.gestureSettings.screenshotStorage.saveAdditionalCopy },
            set: { model.setAdditionalScreenshotCopyEnabled($0) }
        )
    }

    private var screenshotStorageModeBinding: Binding<ScreenshotStorageMode> {
        Binding(
            get: { model.gestureSettings.screenshotStorage.mode },
            set: { model.setScreenshotStorageMode($0) }
        )
    }

    private var macOSScreenshotDestinationIcon: String {
        model.macOSScreenshotDestinationDescription.hasPrefix("Clipboard") ? "doc.on.clipboard" : "macwindow"
    }

    private func featureEnabledBinding(_ feature: GestureFeature) -> Binding<Bool> {
        Binding(
            get: { model.discreteSetting(for: feature).isEnabled },
            set: { model.setGestureFeatureEnabled(feature, enabled: $0) }
        )
    }

    private func featureTriggerBinding(_ feature: GestureFeature) -> Binding<DiscreteGestureTrigger> {
        Binding(
            get: { model.discreteSetting(for: feature).trigger },
            set: { model.setGestureFeatureTrigger(feature, trigger: $0) }
        )
    }
}
