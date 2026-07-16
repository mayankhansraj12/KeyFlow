import AppKit
import KeyFlowCore
import SwiftUI

struct SoundBarSettingsView: View {
    @EnvironmentObject private var model: AppModel
    @State private var isHuePickerPresented = false

    private var appearance: OverlayAppearancePreferences {
        model.gestureSettings.volumePreferences.hudAppearance
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            previewStage
            Divider()
            settings
        }
        .frame(width: 700, height: 520)
        .background(Color(nsColor: .windowBackgroundColor))
        .sheet(isPresented: $isHuePickerPresented) {
            HueColorPickerSheet(
                initialColor: appearance.appKitAccentColor,
                appearance: appearance.appKitAppearance ?? NSApp.effectiveAppearance
            ) { color in
                model.updateVolumeHUDAppearance { $0.customAccentColor = color }
            }
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: "speaker.wave.2.fill")
                .font(.title2)
                .foregroundStyle(Color.accentColor)
                .frame(width: 34, height: 34)
                .background(Color.accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
            VStack(alignment: .leading, spacing: 2) {
                Text("Sound Bar")
                    .font(.title3.weight(.semibold))
                Text("Appearance for volume feedback only")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button("Show on Screen") { model.previewVolumeHUD() }
            Button("Restore Defaults") { model.resetVolumeHUDAppearance() }
                .disabled(appearance == .default)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 13)
    }

    private var previewStage: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(nsColor: .underPageBackgroundColor),
                    Color(nsColor: .controlBackgroundColor),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            // Keep the preview at the widest percentage so clipping regressions are visible here.
            SoundBarPreview(
                level: 1,
                appearance: appearance,
                percentageAlignment: model.gestureSettings.volumePreferences.percentageAlignment
            )
            .frame(
                width: SystemVolumeHUDLayout.preferredSize.width,
                height: SystemVolumeHUDLayout.preferredSize.height
            )
        }
        .frame(height: 112)
        .overlay(alignment: .bottomTrailing) {
            Text("Exact live renderer")
                .font(.caption2.weight(.medium))
                .foregroundStyle(.secondary)
                .padding(9)
        }
    }

    private var settings: some View {
        VStack(spacing: 0) {
            HStack(spacing: 28) {
                settingsColumnHeading("Style", detail: "Color and material")
                settingsColumnHeading("Surface", detail: "Shape and visibility")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Divider()

            VStack(spacing: 14) {
                pairedSettingsRow {
                    settingCell("Theme", detail: "Color contrast") {
                        Picker("Theme", selection: themeBinding) {
                            ForEach(OverlayTheme.allCases) { theme in
                                Text(theme.displayName).tag(theme)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.segmented)
                        .frame(maxWidth: .infinity)
                    }
                } trailing: {
                    settingCell("Opacity", detail: "Background only") {
                        HStack(spacing: 9) {
                            Slider(value: opacityBinding, in: 0.45...1, step: 0.05)
                            Text("\(Int((appearance.backgroundOpacity * 100).rounded()))%")
                                .font(.caption.monospacedDigit())
                                .frame(width: 38, alignment: .trailing)
                        }
                    }
                }

                pairedSettingsRow {
                    settingCell("Surface", detail: "Translucent or opaque") {
                        Picker("Surface", selection: surfaceBinding) {
                            ForEach(OverlaySurfaceStyle.allCases) { style in
                                Text(style == .frosted ? "Translucent" : "Solid").tag(style)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.segmented)
                        .frame(maxWidth: .infinity)
                    }
                } trailing: {
                    settingCell("Corner radius", detail: "10–30 points") {
                        HStack(spacing: 9) {
                            Slider(value: cornerRadiusBinding, in: 10...30, step: 1)
                            Text("\(Int(appearance.cornerRadius.rounded()))")
                                .font(.caption.monospacedDigit())
                                .frame(width: 38, alignment: .trailing)
                        }
                    }
                }

                pairedSettingsRow {
                    settingCell("Background", detail: "Sound Bar surface") {
                        HStack(spacing: 10) {
                            ForEach(OverlayBackgroundColor.allCases) { color in
                                backgroundButton(color)
                            }
                        }
                    }
                } trailing: {
                    settingCell("Outline", detail: "Edge definition") {
                        Toggle("Show subtle outline", isOn: borderBinding)
                    }
                }

                pairedSettingsRow {
                    settingCell("Progress color", detail: "Volume level") {
                        HStack(spacing: 6) {
                            ForEach(WindowSwitcherAccent.allCases) { accent in
                                soundBarAccentButton(accent)
                            }
                            hueButton
                        }
                    }
                } trailing: {
                    settingCell("Percentage alignment", detail: "Number column") {
                        Picker("Percentage alignment", selection: percentageAlignmentBinding) {
                            ForEach(SoundBarPercentageAlignment.allCases) { alignment in
                                Text(alignment.displayName).tag(alignment)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.segmented)
                        .frame(maxWidth: .infinity)
                    }
                }
            }
            .padding(16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        }
        .padding(14)
        .frame(maxHeight: .infinity, alignment: .top)
    }

    private func settingsColumnHeading(_ title: String, detail: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(title).font(.headline)
            Spacer()
            Text(detail)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func pairedSettingsRow<Leading: View, Trailing: View>(
        @ViewBuilder leading: () -> Leading,
        @ViewBuilder trailing: () -> Trailing
    ) -> some View {
        HStack(alignment: .top, spacing: 28) {
            leading()
                .frame(maxWidth: .infinity, alignment: .topLeading)
            trailing()
                .frame(maxWidth: .infinity, alignment: .topLeading)
        }
    }

    private func settingCell<Content: View>(
        _ title: String,
        detail: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(title).font(.callout.weight(.medium))
                Spacer()
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            content()
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(minHeight: 50, alignment: .topLeading)
    }

    private func soundBarAccentButton(_ accent: WindowSwitcherAccent) -> some View {
        Button {
            model.updateVolumeHUDAppearance {
                $0.accent = accent
                $0.customAccentColor = nil
            }
        } label: {
            ZStack {
                Circle().fill(Color(accent))
                if appearance.customAccentColor == nil, appearance.accent == accent {
                    Image(systemName: "checkmark")
                        .font(.caption2.bold())
                        .foregroundStyle(.white)
                }
            }
            .frame(width: 22, height: 22)
            .padding(2)
            .overlay {
                Circle()
                    .stroke(
                        appearance.customAccentColor == nil && appearance.accent == accent
                            ? Color.primary.opacity(0.8) : .clear,
                        lineWidth: 2
                    )
            }
        }
        .buttonStyle(.plain)
        .help(accent.displayName)
    }

    private var hueButton: some View {
        Button {
            isHuePickerPresented = true
        } label: {
            ZStack {
                Circle()
                    .fill(
                        AngularGradient(
                            colors: [.red, .yellow, .green, .cyan, .blue, .purple, .red],
                            center: .center
                        )
                    )
                if appearance.customAccentColor != nil {
                    Circle()
                        .fill(appearance.swiftUIAccentColor)
                        .padding(5)
                    Image(systemName: "checkmark")
                        .font(.caption2.bold())
                        .foregroundStyle(.white)
                }
            }
            .frame(width: 22, height: 22)
            .padding(2)
            .overlay {
                Circle()
                    .stroke(
                        appearance.customAccentColor != nil ? Color.primary.opacity(0.8) : .clear,
                        lineWidth: 2
                    )
            }
        }
        .buttonStyle(.plain)
        .help("Custom Hue…")
        .accessibilityLabel("Choose a custom Sound Bar hue")
        .accessibilityAddTraits(appearance.customAccentColor != nil ? .isSelected : [])
    }

    private func backgroundButton(_ background: OverlayBackgroundColor) -> some View {
        Button {
            var updatedTheme: OverlayTheme?
            if background == .light { updatedTheme = .light }
            if background == .graphite || background == .midnight { updatedTheme = .dark }
            model.updateVolumeHUDAppearance {
                $0.backgroundColor = background
                if let updatedTheme { $0.theme = updatedTheme }
            }
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(backgroundColor(background))
                if appearance.backgroundColor == background {
                    Image(systemName: "checkmark")
                        .font(.caption.bold())
                        .foregroundStyle(background == .light ? Color.black : Color.white)
                }
            }
            .frame(width: 38, height: 28)
            .padding(3)
            .overlay {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .stroke(
                        appearance.backgroundColor == background ? Color.primary.opacity(0.85) : .clear,
                        lineWidth: 2
                    )
            }
        }
        .buttonStyle(.plain)
        .help(background.displayName)
        .accessibilityLabel("\(background.displayName) Sound Bar background")
        .accessibilityAddTraits(appearance.backgroundColor == background ? .isSelected : [])
    }

    private func backgroundColor(_ background: OverlayBackgroundColor) -> Color {
        var candidate = appearance
        candidate.backgroundColor = background
        return candidate.swiftUIBackgroundColor
    }

    private var themeBinding: Binding<OverlayTheme> {
        binding(\.theme)
    }

    private var surfaceBinding: Binding<OverlaySurfaceStyle> {
        binding(\.surfaceStyle)
    }

    private var opacityBinding: Binding<Double> {
        binding(\.backgroundOpacity)
    }

    private var cornerRadiusBinding: Binding<Double> {
        binding(\.cornerRadius)
    }

    private var borderBinding: Binding<Bool> {
        binding(\.showsBorder)
    }

    private var percentageAlignmentBinding: Binding<SoundBarPercentageAlignment> {
        Binding(
            get: { model.gestureSettings.volumePreferences.percentageAlignment },
            set: { model.setVolumeHUDPercentageAlignment($0) }
        )
    }

    private func binding<Value>(
        _ keyPath: WritableKeyPath<OverlayAppearancePreferences, Value>
    ) -> Binding<Value> {
        Binding(
            get: { appearance[keyPath: keyPath] },
            set: { value in model.updateVolumeHUDAppearance { $0[keyPath: keyPath] = value } }
        )
    }
}
