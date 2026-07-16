import KeyFlowCore
import SwiftUI

struct WindowSwitcherSettingsView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                pageHeader
                SwitcherAppearancePreview(
                    preferences: model.windowSwitcherPreferences,
                    appearance: model.windowSwitcherPreferences.appearance
                )
                settingsPanel
            }
            .frame(maxWidth: 900, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.vertical, 18)
            .frame(maxWidth: .infinity)
        }
        .defaultScrollAnchor(.top)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var pageHeader: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 5) {
                Text("Window Switcher")
                    .font(.title2.weight(.semibold))
                Text("Shape the overlay that appears during your four-finger horizontal swipe.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Toggle("Enabled", isOn: windowSwitcherEnabledBinding)
                .toggleStyle(.switch)
            Button("Restore Defaults") {
                model.resetWindowSwitcherPreferences()
            }
            .disabled(model.windowSwitcherPreferences == .default)
        }
    }

    private var settingsPanel: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: 10) {
                layoutSettings
                previewSettings
                appearanceSettings
            }
            VStack(spacing: 10) {
                layoutSettings
                previewSettings
                appearanceSettings
            }
        }
    }

    private var layoutSettings: some View {
        settingsCard(title: "Layout", icon: "rectangle.resize") {
            settingLabel("Card size", detail: "Sets the overall scale of the switcher.")
            Picker("Card size", selection: cardSizeBinding) {
                ForEach(WindowSwitcherCardSize.allCases) { size in
                    Text(size.displayName).tag(size)
                }
            }
            .labelsHidden()
            .pickerStyle(.segmented)

            Divider()
                .padding(.vertical, 2)

            settingLabel("Switcher speed", detail: navigationSpeedHelp)
            HStack(spacing: 10) {
                Text("0.25×")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Slider(value: navigationSpeedBinding, in: 0.25...2.5, step: 0.05)
                Text("2.5×")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("\(model.windowSwitcherPreferences.navigationSpeed, specifier: "%.2f")×")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .frame(width: 48, alignment: .trailing)
            }

        }
    }

    private var previewSettings: some View {
        settingsCard(title: "Window Previews", icon: "macwindow") {
            settingLabel("Windows shown", detail: windowScopeHelp)
            Picker("Windows shown", selection: windowScopeBinding) {
                ForEach(WindowSwitcherWindowScope.allCases) { scope in
                    Text(scope.displayName).tag(scope)
                }
            }
            .labelsHidden()
            .pickerStyle(.segmented)

            Divider()
                .padding(.vertical, 2)

            settingLabel("Preview fit", detail: previewStyleHelp)
            Picker("Preview fit", selection: previewStyleBinding) {
                ForEach(WindowSwitcherPreviewStyle.allCases) { style in
                    Text(style.displayName).tag(style)
                }
            }
            .labelsHidden()
            .pickerStyle(.segmented)

            Divider()
                .padding(.vertical, 2)

            preferenceToggle(
                "Window titles",
                icon: "textformat",
                isOn: showTitlesBinding
            )
            preferenceToggle(
                "Application icons",
                icon: "app.dashed",
                isOn: showIconsBinding
            )
            preferenceToggle(
                "Preview backdrop",
                icon: "square.3.layers.3d",
                isOn: backdropBinding,
                isDisabled: model.windowSwitcherPreferences.previewStyle == .edgeToEdge
            )
        }
    }

    private var appearanceSettings: some View {
        settingsCard(title: "Appearance", icon: "paintpalette") {
            settingLabel("Theme", detail: "Applies only to this switcher.")
            Picker("Theme", selection: switcherThemeBinding) {
                ForEach(OverlayTheme.allCases) { theme in
                    Text(theme.displayName).tag(theme)
                }
            }
            .labelsHidden()
            .pickerStyle(.segmented)

            Picker("Surface", selection: switcherSurfaceBinding) {
                ForEach(OverlaySurfaceStyle.allCases) { style in
                    Text(style.displayName).tag(style)
                }
            }
            .labelsHidden()
            .pickerStyle(.segmented)

            HStack(spacing: 6) {
                Picker("Background", selection: switcherBackgroundBinding) {
                    ForEach(OverlayBackgroundColor.allCases) { color in
                        Text(color.displayName).tag(color)
                    }
                }
                .pickerStyle(.menu)
                Picker("Accent", selection: switcherAccentBinding) {
                    ForEach(WindowSwitcherAccent.allCases) { accent in
                        Text(accent.displayName).tag(accent)
                    }
                }
                .pickerStyle(.menu)
            }

            settingLabel("Opacity", detail: "Background only.")
            HStack(spacing: 8) {
                Slider(value: switcherOpacityBinding, in: 0.45...1, step: 0.05)
                Text("\(Int((switcherAppearance.backgroundOpacity * 100).rounded()))%")
                    .font(.caption.monospacedDigit())
                    .frame(width: 34, alignment: .trailing)
            }

            HStack {
                Toggle("Border", isOn: switcherBorderBinding)
                    .toggleStyle(.checkbox)
                Spacer()
                Text("Radius")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Stepper(
                    "\(Int(switcherAppearance.cornerRadius.rounded()))",
                    value: switcherCornerRadiusBinding,
                    in: 10...30,
                    step: 1
                )
                .fixedSize()
            }
        }
    }

    private func settingsCard<Content: View>(
        title: String,
        icon: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: icon)
                .font(.headline)
            Divider()
            content()
        }
        .padding(13)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.primary.opacity(0.07), lineWidth: 1)
        }
    }

    private func settingLabel(_ title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.callout.weight(.semibold))
            Text(detail)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func preferenceToggle(
        _ title: String,
        icon: String,
        isOn: Binding<Bool>,
        isDisabled: Bool = false
    ) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(.secondary)
                .frame(width: 18)
            Text(title)
                .font(.callout)
            Spacer()
            Toggle(title, isOn: isOn)
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.small)
        }
        .disabled(isDisabled)
    }

    private var previewStyleHelp: String {
        switch model.windowSwitcherPreferences.previewStyle {
        case .fullWindow: "Show the complete window without cropping."
        case .edgeToEdge: "Fill each card, cropping edges when necessary."
        }
    }

    private var navigationSpeedHelp: String {
        "Multiplier for finger travel sensitivity and selection-animation response."
    }

    private var windowScopeHelp: String {
        switch model.windowSwitcherPreferences.windowScope {
        case .standardApplications: "Only real windows belonging to regular Dock applications."
        case .allActiveWindows:
            "Real open windows from Dock, accessory, menu-bar, and background applications."
        }
    }

    private var cardSizeBinding: Binding<WindowSwitcherCardSize> {
        Binding(
            get: { model.windowSwitcherPreferences.cardSize },
            set: { value in model.updateWindowSwitcherPreferences { $0.cardSize = value } }
        )
    }

    private var navigationSpeedBinding: Binding<Double> {
        Binding(
            get: { model.windowSwitcherPreferences.navigationSpeed },
            set: { value in model.updateWindowSwitcherPreferences { $0.navigationSpeed = value } }
        )
    }

    private var windowScopeBinding: Binding<WindowSwitcherWindowScope> {
        Binding(
            get: { model.windowSwitcherPreferences.windowScope },
            set: { value in model.updateWindowSwitcherPreferences { $0.windowScope = value } }
        )
    }

    private var windowSwitcherEnabledBinding: Binding<Bool> {
        Binding(
            get: { model.gestureSettings.interactiveWindowSwitcherEnabled },
            set: { value in model.setInteractiveWindowSwitcherEnabled(value) }
        )
    }

    private var previewStyleBinding: Binding<WindowSwitcherPreviewStyle> {
        Binding(
            get: { model.windowSwitcherPreferences.previewStyle },
            set: { value in model.updateWindowSwitcherPreferences { $0.previewStyle = value } }
        )
    }

    private var showTitlesBinding: Binding<Bool> {
        Binding(
            get: { model.windowSwitcherPreferences.showWindowTitles },
            set: { value in model.updateWindowSwitcherPreferences { $0.showWindowTitles = value } }
        )
    }

    private var showIconsBinding: Binding<Bool> {
        Binding(
            get: { model.windowSwitcherPreferences.showApplicationIcons },
            set: { value in model.updateWindowSwitcherPreferences { $0.showApplicationIcons = value } }
        )
    }

    private var backdropBinding: Binding<Bool> {
        Binding(
            get: { model.windowSwitcherPreferences.usePreviewBackdrop },
            set: { value in model.updateWindowSwitcherPreferences { $0.usePreviewBackdrop = value } }
        )
    }

    private var switcherAppearance: OverlayAppearancePreferences {
        model.windowSwitcherPreferences.appearance
    }

    private var switcherThemeBinding: Binding<OverlayTheme> {
        switcherAppearanceBinding(\.theme)
    }

    private var switcherSurfaceBinding: Binding<OverlaySurfaceStyle> {
        switcherAppearanceBinding(\.surfaceStyle)
    }

    private var switcherBackgroundBinding: Binding<OverlayBackgroundColor> {
        Binding(
            get: { switcherAppearance.backgroundColor },
            set: { value in
                model.updateWindowSwitcherPreferences {
                    $0.appearance.backgroundColor = value
                    if value == .light { $0.appearance.theme = .light }
                    if value == .graphite || value == .midnight { $0.appearance.theme = .dark }
                }
            }
        )
    }

    private var switcherAccentBinding: Binding<WindowSwitcherAccent> {
        switcherAppearanceBinding(\.accent)
    }

    private var switcherOpacityBinding: Binding<Double> {
        switcherAppearanceBinding(\.backgroundOpacity)
    }

    private var switcherCornerRadiusBinding: Binding<Double> {
        switcherAppearanceBinding(\.cornerRadius)
    }

    private var switcherBorderBinding: Binding<Bool> {
        switcherAppearanceBinding(\.showsBorder)
    }

    private func switcherAppearanceBinding<Value>(
        _ keyPath: WritableKeyPath<OverlayAppearancePreferences, Value>
    ) -> Binding<Value> {
        Binding(
            get: { switcherAppearance[keyPath: keyPath] },
            set: { value in
                model.updateWindowSwitcherPreferences { $0.appearance[keyPath: keyPath] = value }
            }
        )
    }
}

private struct SwitcherAppearancePreview: View {
    let preferences: WindowSwitcherPreferences
    let appearance: OverlayAppearancePreferences

    private var cardSize: CGSize {
        switch preferences.cardSize {
        case .compact: CGSize(width: 160, height: 106)
        case .balanced: CGSize(width: 180, height: 116)
        case .large: CGSize(width: 200, height: 126)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Label("Overlay Preview", systemImage: "sparkles.rectangle.stack")
                    .font(.callout.weight(.semibold))
                Spacer()
                Text("Move in any direction  •  Lift to open")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 13)
            .padding(.vertical, 9)

            Divider()

            GeometryReader { proxy in
                let horizontalPadding: CGFloat = 12
                let spacing: CGFloat = 8
                let availableCardWidth = max(
                    80,
                    (proxy.size.width - horizontalPadding * 2 - spacing * 2) / 3
                )
                let resolvedCardSize = CGSize(
                    width: min(cardSize.width, availableCardWidth),
                    height: cardSize.height
                )

                ZStack {
                    LinearGradient(
                        colors: [Color.primary.opacity(0.035), Color.clear],
                        startPoint: .top,
                        endPoint: .bottom
                    )

                    HStack(spacing: spacing) {
                        previewCard(.notes, size: resolvedCardSize)
                        previewCard(.browser, size: resolvedCardSize, selected: true)
                        previewCard(.editor, size: resolvedCardSize)
                    }
                    .padding(.horizontal, horizontalPadding)
                }
            }
            .frame(height: 142)
        }
        .background {
            let shape = RoundedRectangle(cornerRadius: appearance.cornerRadius, style: .continuous)
            ZStack {
                if appearance.surfaceStyle == .frosted {
                    shape.fill(.ultraThickMaterial)
                        .opacity(appearance.backgroundOpacity)
                    shape.fill(
                        appearance.swiftUIBackgroundColor.opacity(
                            appearance.backgroundOpacity * 0.34
                        )
                    )
                } else {
                    shape.fill(
                        appearance.swiftUIBackgroundColor.opacity(appearance.backgroundOpacity)
                    )
                }
            }
        }
        .overlay {
            if appearance.showsBorder {
                RoundedRectangle(cornerRadius: appearance.cornerRadius, style: .continuous)
                    .stroke(Color.primary.opacity(0.14), lineWidth: 1)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: appearance.cornerRadius, style: .continuous))
        .shadow(color: .black.opacity(0.1), radius: 10, y: 4)
        .preferredColorScheme(appearance.preferredColorScheme)
        .animation(.easeInOut(duration: 0.18), value: preferences)
    }

    private func previewCard(_ kind: MockWindowKind, size: CGSize, selected: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if preferences.showApplicationIcons || preferences.showWindowTitles {
                HStack(spacing: 7) {
                    if preferences.showApplicationIcons {
                        Image(systemName: kind.symbol)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white)
                            .frame(width: 20, height: 20)
                            .background(kind.tint, in: RoundedRectangle(cornerRadius: 5))
                    }
                    if preferences.showWindowTitles {
                        Text(kind.title)
                            .font(.caption.weight(.semibold))
                            .lineLimit(1)
                    }
                }
                .frame(height: 20)
            }

            previewContent(kind)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
        }
        .padding(9)
        .frame(width: size.width, height: size.height, alignment: .topLeading)
        .background(
            appearance.swiftUIBackgroundColor.opacity(0.34),
            in: RoundedRectangle(cornerRadius: min(16, appearance.cornerRadius * 0.75), style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: min(16, appearance.cornerRadius * 0.75), style: .continuous)
                .stroke(selected ? appearance.swiftUIAccentColor : .clear, lineWidth: 4)
        }
        .shadow(color: selected ? appearance.swiftUIAccentColor.opacity(0.22) : .clear, radius: 8)
    }

    @ViewBuilder
    private func previewContent(_ kind: MockWindowKind) -> some View {
        switch preferences.previewStyle {
        case .fullWindow:
            ZStack {
                if preferences.usePreviewBackdrop {
                    kind.tint.opacity(0.12)
                } else {
                    Color.black.opacity(0.22)
                }
                MockWindowContent(kind: kind)
                    .aspectRatio(1.65, contentMode: .fit)
                    .padding(7)
                    .shadow(color: .black.opacity(0.22), radius: 3, y: 2)
            }
        case .edgeToEdge:
            MockWindowContent(kind: kind)
        }
    }
}

private enum MockWindowKind {
    case notes
    case browser
    case editor

    var title: String {
        switch self {
        case .notes: "Notes"
        case .browser: "Browser"
        case .editor: "Editor"
        }
    }

    var symbol: String {
        switch self {
        case .notes: "note.text"
        case .browser: "safari.fill"
        case .editor: "chevron.left.forwardslash.chevron.right"
        }
    }

    var tint: Color {
        switch self {
        case .notes: .orange
        case .browser: .blue
        case .editor: .indigo
        }
    }
}

private struct MockWindowContent: View {
    let kind: MockWindowKind

    var body: some View {
        GeometryReader { proxy in
            switch kind {
            case .notes:
                notesWindow(size: proxy.size)
            case .browser:
                browserWindow(size: proxy.size)
            case .editor:
                editorWindow(size: proxy.size)
            }
        }
        .background(Color(nsColor: .textBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
    }

    private func notesWindow(size: CGSize) -> some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: max(2, size.height * 0.05)) {
                mockLine(width: 0.65, color: .orange.opacity(0.65))
                mockLine(width: 0.8)
                mockLine(width: 0.56)
                Spacer()
            }
            .padding(size.width * 0.045)
            .frame(width: size.width * 0.3)
            .background(Color.orange.opacity(0.13))

            VStack(alignment: .leading, spacing: max(2, size.height * 0.065)) {
                mockLine(width: 0.48, color: .primary.opacity(0.55), height: 5)
                mockLine(width: 0.94)
                mockLine(width: 0.82)
                mockLine(width: 0.9)
                mockLine(width: 0.62)
                Spacer()
            }
            .padding(size.width * 0.055)
        }
    }

    private func browserWindow(size: CGSize) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 4) {
                Circle().fill(.red.opacity(0.7)).frame(width: 4, height: 4)
                Circle().fill(.yellow.opacity(0.7)).frame(width: 4, height: 4)
                Circle().fill(.green.opacity(0.7)).frame(width: 4, height: 4)
                Capsule()
                    .fill(Color.primary.opacity(0.1))
                    .frame(maxWidth: .infinity, maxHeight: 9)
                    .padding(.leading, 4)
            }
            .padding(.horizontal, 7)
            .frame(height: max(16, size.height * 0.19))
            .background(Color.primary.opacity(0.06))

            HStack(alignment: .top, spacing: size.width * 0.04) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.blue.opacity(0.65))
                    .frame(width: size.width * 0.36)
                VStack(alignment: .leading, spacing: max(2, size.height * 0.06)) {
                    mockLine(width: 0.72, color: .blue.opacity(0.65), height: 5)
                    mockLine(width: 0.95)
                    mockLine(width: 0.78)
                    mockLine(width: 0.88)
                }
            }
            .padding(size.width * 0.06)
        }
    }

    private func editorWindow(size: CGSize) -> some View {
        HStack(spacing: 0) {
            VStack(spacing: max(3, size.height * 0.055)) {
                ForEach(0..<5, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 1)
                        .fill(index == 1 ? Color.indigo.opacity(0.75) : Color.primary.opacity(0.14))
                        .frame(width: size.width * 0.12, height: 3)
                }
                Spacer()
            }
            .padding(.top, size.height * 0.1)
            .frame(width: size.width * 0.22)
            .background(Color.primary.opacity(0.06))

            VStack(alignment: .leading, spacing: max(2, size.height * 0.05)) {
                mockLine(width: 0.58, color: .purple.opacity(0.75))
                mockLine(width: 0.86, color: .blue.opacity(0.65))
                mockLine(width: 0.68)
                mockLine(width: 0.78, color: .green.opacity(0.6))
                mockLine(width: 0.52)
                Spacer()
            }
            .padding(size.width * 0.055)
        }
    }

    private func mockLine(
        width: CGFloat,
        color: Color = .secondary.opacity(0.32),
        height: CGFloat = 3
    ) -> some View {
        GeometryReader { proxy in
            Capsule()
                .fill(color)
                .frame(width: proxy.size.width * width, height: height)
        }
        .frame(height: height)
    }
}
