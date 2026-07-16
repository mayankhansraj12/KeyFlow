import KeyFlowCore
import SwiftUI

struct GestureSettingsView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                pageHeader

                gestureSection(
                    title: "Audio & Media",
                    detail: "Control sound and playback directly from the trackpad.",
                    icon: "speaker.wave.2.fill"
                ) {
                    volumeFeatureCard

                    ViewThatFits(in: .horizontal) {
                        HStack(alignment: .top, spacing: 14) {
                            discreteFeatureCard(
                                feature: .mute,
                                icon: "speaker.slash.fill",
                                description: "Mute or restore system audio."
                            )
                            discreteFeatureCard(
                                feature: .playPause,
                                icon: "playpause.fill",
                                description: "Play or pause the active media application."
                            )
                        }
                        VStack(spacing: 14) {
                            discreteFeatureCard(
                                feature: .mute,
                                icon: "speaker.slash.fill",
                                description: "Mute or restore system audio."
                            )
                            discreteFeatureCard(
                                feature: .playPause,
                                icon: "playpause.fill",
                                description: "Play or pause the active media application."
                            )
                        }
                    }
                }

                gestureSection(
                    title: "Screenshots",
                    detail: "Use macOS capture tools, with an optional additional file copy.",
                    icon: "camera.fill"
                ) {
                    ViewThatFits(in: .horizontal) {
                        HStack(alignment: .top, spacing: 14) {
                            discreteFeatureCard(
                                feature: .screenshot,
                                icon: "camera.viewfinder",
                                description: "Capture the complete screen."
                            )
                            discreteFeatureCard(
                                feature: .customScreenshot,
                                icon: "rectangle.dashed",
                                description: "Select an area or window using macOS capture."
                            )
                        }
                        VStack(spacing: 14) {
                            discreteFeatureCard(
                                feature: .screenshot,
                                icon: "camera.viewfinder",
                                description: "Capture the complete screen."
                            )
                            discreteFeatureCard(
                                feature: .customScreenshot,
                                icon: "rectangle.dashed",
                                description: "Select an area or window using macOS capture."
                            )
                        }
                    }

                    screenshotSavingCard
                }

                Label(
                    "The four-finger interactive window gesture is configured in Switcher.",
                    systemImage: "rectangle.3.group"
                )
                .font(.footnote)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 2)
            }
            .frame(maxWidth: 960, alignment: .leading)
            .padding(.horizontal, 28)
            .padding(.vertical, 26)
            .frame(maxWidth: .infinity)
        }
        .defaultScrollAnchor(.top)
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear { model.refreshSystemScreenshotDestination() }
    }

    private var pageHeader: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Gestures")
                .font(.title2.weight(.semibold))
            Text("Choose one purposeful trackpad gesture for each feature.")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
    }

    private func gestureSection<Content: View>(
        title: String,
        detail: String,
        icon: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 28, height: 28)
                    .background(Color.accentColor.opacity(0.1), in: RoundedRectangle(cornerRadius: 7))
                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.headline)
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            content()
        }
    }

    private var volumeFeatureCard: some View {
        featureSurface {
            featureHeader(
                title: "Volume Adjustment",
                icon: "speaker.wave.3.fill",
                description: "Move continuously to raise or lower the volume.",
                isEnabled: volumeEnabledBinding
            )

            Divider()

            settingRow(title: "Gesture", detail: "Vertical movement controls the direction.") {
                Picker("Gesture", selection: volumeTriggerBinding) {
                    ForEach(VerticalGestureTrigger.volumeAdjustmentCases) { trigger in
                        Text(trigger.displayName).tag(trigger)
                    }
                }
                .labelsHidden()
                .frame(width: 280)
            }

            Divider()

            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Adjustment Behavior")
                            .font(.callout.weight(.semibold))
                        Text("Tune continuous movement without changing the overlay style.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Configure Sound Bar…") {
                        openWindow(id: "sound-bar-settings")
                    }
                }

                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .top, spacing: 18) {
                        volumeSpeedControl
                            .frame(maxWidth: .infinity)
                        volumeResponseControl
                            .frame(width: 150)
                        volumeStepControl
                            .frame(width: 210)
                    }
                    VStack(spacing: 12) {
                        volumeSpeedControl
                        volumeResponseControl
                        volumeStepControl
                    }
                }
            }
            .disabled(!model.gestureSettings.volumeAdjustment.isEnabled)
            .opacity(model.gestureSettings.volumeAdjustment.isEnabled ? 1 : 0.48)
        }
    }

    private var volumeSpeedControl: some View {
        behaviorField("Speed") {
            HStack(spacing: 10) {
                Slider(value: volumeSpeedBinding, in: 0.5...2.5, step: 0.25)
                Text("\(model.gestureSettings.volumePreferences.speedMultiplier, specifier: "%.2f")×")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .frame(width: 42, alignment: .trailing)
            }
        }
    }

    private var volumeResponseControl: some View {
        behaviorField("Response") {
            Picker("Response", selection: volumeResponseBinding) {
                ForEach(VolumeAdjustmentPreferences.allowedResponseMilliseconds, id: \.self) { milliseconds in
                    Text("\(milliseconds) ms").tag(milliseconds)
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var volumeStepControl: some View {
        behaviorField("Change per step") {
            Picker("Change per step", selection: volumeStepPercentageBinding) {
                ForEach(VolumeAdjustmentPreferences.allowedStepPercentages, id: \.self) { percentage in
                    Text("\(percentage)%").tag(percentage)
                }
            }
            .labelsHidden()
            .pickerStyle(.segmented)
        }
    }

    private func behaviorField<Content: View>(
        _ title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func discreteFeatureCard(
        feature: GestureFeature,
        icon: String,
        description: String
    ) -> some View {
        featureSurface {
            featureHeader(
                title: feature.displayName,
                icon: icon,
                description: description,
                isEnabled: featureEnabledBinding(feature)
            )

            Divider()

            VStack(alignment: .leading, spacing: 7) {
                Text("Gesture")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
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
                .frame(maxWidth: .infinity)

                if model.gestureSettings.conflictingFeatures.contains(feature) {
                    Label(
                        "Choose an available gesture before enabling this feature.",
                        systemImage: "exclamationmark.triangle.fill"
                    )
                    .font(.caption)
                    .foregroundStyle(.orange)
                }
            }
        }
    }

    private var screenshotSavingCard: some View {
        featureSurface {
            HStack(alignment: .top, spacing: 12) {
                featureIcon("externaldrive.fill")
                VStack(alignment: .leading, spacing: 3) {
                    Text("Screenshot Saving")
                        .font(.headline)
                    Text("The normal macOS destination is always preserved.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            Divider()

            HStack(alignment: .top, spacing: 12) {
                Image(systemName: macOSScreenshotDestinationIcon)
                    .foregroundStyle(.secondary)
                    .frame(width: 22)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Current macOS destination")
                        .font(.callout.weight(.medium))
                    Text(model.macOSScreenshotDestinationDescription)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            Divider()

            HStack(alignment: .center, spacing: 16) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Additional file copy")
                        .font(.callout.weight(.medium))
                    Text("Also save a PNG to a folder you choose.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Toggle("Additional file copy", isOn: additionalCopyEnabledBinding)
                    .labelsHidden()
                    .toggleStyle(.switch)
            }

            if model.gestureSettings.screenshotStorage.saveAdditionalCopy {
                Divider()

                settingRow(title: "Save file copy to", detail: model.screenshotStorageStatusDescription) {
                    HStack(spacing: 10) {
                        Picker("Save file copy to", selection: screenshotStorageModeBinding) {
                            ForEach(ScreenshotStorageMode.allCases) { mode in
                                Text(mode.displayName).tag(mode)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.segmented)
                        .frame(width: 250)

                        if model.gestureSettings.screenshotStorage.mode == .customFolder {
                            Button("Choose Folder…") { model.chooseScreenshotFolder() }
                        }
                    }
                }
            }
        }
        .animation(.easeInOut(duration: 0.16), value: model.gestureSettings.screenshotStorage.saveAdditionalCopy)
    }

    private func featureSurface<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.72))
        .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .stroke(Color(nsColor: .separatorColor).opacity(0.65), lineWidth: 1)
        }
    }

    private func featureHeader(
        title: String,
        icon: String,
        description: String,
        isEnabled: Binding<Bool>
    ) -> some View {
        HStack(alignment: .center, spacing: 12) {
            featureIcon(icon)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.headline)
                Text(description)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 12)
            Toggle("Enabled", isOn: isEnabled)
                .labelsHidden()
                .toggleStyle(.switch)
        }
    }

    private func featureIcon(_ symbol: String) -> some View {
        Image(systemName: symbol)
            .font(.system(size: 17, weight: .semibold))
            .foregroundStyle(Color.accentColor)
            .frame(width: 36, height: 36)
            .background(Color.accentColor.opacity(0.1), in: RoundedRectangle(cornerRadius: 9))
    }

    private func settingRow<Content: View>(
        title: String,
        detail: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        HStack(alignment: .center, spacing: 20) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.callout.weight(.medium))
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 14)
            content()
        }
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
