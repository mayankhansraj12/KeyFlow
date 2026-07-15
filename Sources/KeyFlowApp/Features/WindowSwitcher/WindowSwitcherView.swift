import AppKit
import KeyFlowCore
import SwiftUI

struct WindowSwitcherLayoutMetrics {
    let maximumCardWidth: CGFloat
    let maximumCardHeight: CGFloat
    let minimumPanelWidth: CGFloat
    let outerPadding: CGFloat
    let spacing: CGFloat

    init(_ size: WindowSwitcherCardSize) {
        switch size {
        case .compact:
            maximumCardWidth = 190
            maximumCardHeight = 150
            minimumPanelWidth = 210
            outerPadding = 10
            spacing = 6
        case .balanced:
            maximumCardWidth = 240
            maximumCardHeight = 186
            minimumPanelWidth = 264
            outerPadding = 12
            spacing = 8
        case .large:
            maximumCardWidth = 290
            maximumCardHeight = 218
            minimumPanelWidth = 318
            outerPadding = 14
            spacing = 10
        }
    }

    func preferredPanelSize(for grid: WindowSwitcherGridLayout) -> CGSize {
        let content = grid.contentSize(
            cardWidth: maximumCardWidth,
            cardHeight: maximumCardHeight,
            spacing: spacing
        )
        return CGSize(
            width: max(minimumPanelWidth, content.width + outerPadding * 2),
            height: content.height + outerPadding * 2
        )
    }
}

struct WindowSwitcherResolvedLayout {
    let grid: WindowSwitcherGridLayout
    let cardWidth: CGFloat
    let cardHeight: CGFloat
    let spacing: CGFloat
    let contentSize: CGSize
    let scale: CGFloat

    init(itemCount: Int, metrics: WindowSwitcherLayoutMetrics, availableSize: CGSize) {
        let grid = WindowSwitcherGridLayout(itemCount: itemCount)
        let preferredContent = grid.contentSize(
            cardWidth: metrics.maximumCardWidth,
            cardHeight: metrics.maximumCardHeight,
            spacing: metrics.spacing
        )
        let availableContentWidth = max(1, availableSize.width - metrics.outerPadding * 2)
        let availableContentHeight = max(1, availableSize.height - metrics.outerPadding * 2)
        let widthScale = availableContentWidth / max(1, preferredContent.width)
        let heightScale = availableContentHeight / max(1, preferredContent.height)
        let scale = min(1, widthScale, heightScale)
        let cardWidth = max(1, metrics.maximumCardWidth * scale)
        let cardHeight = max(1, metrics.maximumCardHeight * scale)
        let spacing = max(1, metrics.spacing * scale)

        self.grid = grid
        self.cardWidth = cardWidth
        self.cardHeight = cardHeight
        self.spacing = spacing
        self.contentSize = grid.contentSize(
            cardWidth: cardWidth,
            cardHeight: cardHeight,
            spacing: spacing
        )
        self.scale = scale
    }
}

enum WindowPreviewGeometry {
    static func imageSize(
        sourceSize: CGSize,
        containerSize: CGSize,
        style: WindowSwitcherPreviewStyle
    ) -> CGSize {
        guard
            sourceSize.width > 0,
            sourceSize.height > 0,
            containerSize.width > 0,
            containerSize.height > 0
        else { return .zero }

        let horizontalScale = containerSize.width / sourceSize.width
        let verticalScale = containerSize.height / sourceSize.height
        let scale: CGFloat
        switch style {
        case .fullWindow:
            scale = min(horizontalScale, verticalScale)
        case .edgeToEdge:
            scale = max(horizontalScale, verticalScale)
        }
        return CGSize(width: sourceSize.width * scale, height: sourceSize.height * scale)
    }
}

struct WindowSwitcherGridPosition: Equatable {
    let row: Int
    let column: Int
}

struct WindowSwitcherGridLayout: Equatable {
    static let maximumColumns = 5

    let itemCount: Int
    let maximumColumns: Int

    init(itemCount: Int, maximumColumns: Int = Self.maximumColumns) {
        self.itemCount = max(0, itemCount)
        self.maximumColumns = max(1, maximumColumns)
    }

    var columnCount: Int {
        max(1, min(itemCount, maximumColumns))
    }

    var rowCount: Int {
        max(1, Int(ceil(Double(itemCount) / Double(columnCount))))
    }

    var preferredInitialIndex: Int {
        guard itemCount > 0 else { return 0 }
        let row = (rowCount - 1) / 2
        let column = max(0, (itemCount(inRow: row) - 1) / 2)
        return min(itemCount - 1, row * columnCount + column)
    }

    func itemCount(inRow row: Int) -> Int {
        guard row >= 0, row < rowCount, itemCount > 0 else { return 0 }
        return min(columnCount, itemCount - row * columnCount)
    }

    func position(for index: Int) -> WindowSwitcherGridPosition? {
        guard index >= 0, index < itemCount else { return nil }
        return WindowSwitcherGridPosition(
            row: index / columnCount,
            column: index % columnCount
        )
    }

    func contentSize(cardWidth: CGFloat, cardHeight: CGFloat, spacing: CGFloat) -> CGSize {
        CGSize(
            width: CGFloat(columnCount) * cardWidth + CGFloat(columnCount - 1) * spacing,
            height: CGFloat(rowCount) * cardHeight + CGFloat(rowCount - 1) * spacing
        )
    }

    func center(
        for index: Int,
        cardWidth: CGFloat,
        cardHeight: CGFloat,
        spacing: CGFloat
    ) -> CGPoint? {
        guard let position = position(for: index) else { return nil }
        let fullWidth = contentSize(cardWidth: cardWidth, cardHeight: cardHeight, spacing: spacing).width
        let rowItems = itemCount(inRow: position.row)
        let rowWidth = CGFloat(rowItems) * cardWidth + CGFloat(max(rowItems - 1, 0)) * spacing
        let rowOriginX = (fullWidth - rowWidth) / 2

        return CGPoint(
            x: rowOriginX + cardWidth / 2 + CGFloat(position.column) * (cardWidth + spacing),
            y: cardHeight / 2 + CGFloat(position.row) * (cardHeight + spacing)
        )
    }
}

struct WindowSwitcherView: View {
    @ObservedObject var model: WindowSwitcherModel
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        GeometryReader { proxy in
            let metrics = WindowSwitcherLayoutMetrics(model.preferences.cardSize)
            let layout = WindowSwitcherResolvedLayout(
                itemCount: model.windows.count,
                metrics: metrics,
                availableSize: proxy.size
            )

            ZStack(alignment: .topLeading) {
                ForEach(model.windows.indices, id: \.self) { index in
                    if let center = layout.grid.center(
                        for: index,
                        cardWidth: layout.cardWidth,
                        cardHeight: layout.cardHeight,
                        spacing: layout.spacing
                    ) {
                        WindowSwitcherCardView(
                            window: model.windows[index],
                            preferences: model.preferences,
                            appearance: model.appearance,
                            width: layout.cardWidth,
                            height: layout.cardHeight
                        )
                        .equatable()
                        .position(center)
                    }
                }

                if !model.windows.isEmpty,
                    let selectionCenter = layout.grid.center(
                        for: model.selectedIndex,
                        cardWidth: layout.cardWidth,
                        cardHeight: layout.cardHeight,
                        spacing: layout.spacing
                    )
                {
                    RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous)
                        .stroke(selectionColor, lineWidth: min(5, max(2, layout.cardWidth * 0.022)))
                        .frame(width: layout.cardWidth, height: layout.cardHeight)
                        .position(selectionCenter)
                        .allowsHitTesting(false)
                }
            }
            .frame(width: layout.contentSize.width, height: layout.contentSize.height, alignment: .topLeading)
            .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
        }
        .background(panelBackground)
        .overlay {
            if model.appearance.showsBorder {
                RoundedRectangle(cornerRadius: model.appearance.cornerRadius, style: .continuous)
                    .stroke(Color.primary.opacity(0.14), lineWidth: 1)
            }
        }
        .clipShape(
            RoundedRectangle(cornerRadius: model.appearance.cornerRadius, style: .continuous)
        )
        .preferredColorScheme(model.appearance.preferredColorScheme)
    }

    @ViewBuilder
    private var panelBackground: some View {
        let shape = RoundedRectangle(cornerRadius: model.appearance.cornerRadius, style: .continuous)
        ZStack {
            if model.appearance.surfaceStyle == .frosted, !reduceTransparency {
                shape.fill(.ultraThickMaterial)
                    .opacity(model.appearance.backgroundOpacity)
                shape.fill(
                    model.appearance.swiftUIBackgroundColor.opacity(
                        model.appearance.backgroundOpacity * 0.34
                    )
                )
            } else {
                shape.fill(
                    model.appearance.swiftUIBackgroundColor.opacity(
                        reduceTransparency ? 1 : model.appearance.backgroundOpacity
                    )
                )
            }
        }
    }

    private var selectionColor: Color {
        model.appearance.swiftUIAccentColor
    }

    private var cardCornerRadius: CGFloat {
        min(20, max(8, model.appearance.cornerRadius * 0.75))
    }
}

private struct WindowSwitcherCardView: View, Equatable {
    private struct RenderIdentity: Equatable, Sendable {
        let windowID: CGWindowID
        let processID: pid_t
        let title: String
        let thumbnailID: ObjectIdentifier?
        let applicationIconID: ObjectIdentifier
        let preferences: WindowSwitcherPreferences
        let appearance: OverlayAppearancePreferences
        let width: CGFloat
        let height: CGFloat
    }

    let window: SwitchableWindow
    let preferences: WindowSwitcherPreferences
    let appearance: OverlayAppearancePreferences
    let width: CGFloat
    let height: CGFloat
    private let renderIdentity: RenderIdentity

    init(
        window: SwitchableWindow,
        preferences: WindowSwitcherPreferences,
        appearance: OverlayAppearancePreferences,
        width: CGFloat,
        height: CGFloat
    ) {
        self.window = window
        self.preferences = preferences
        self.appearance = appearance
        self.width = width
        self.height = height
        renderIdentity = RenderIdentity(
            windowID: window.windowID,
            processID: window.processID,
            title: window.title,
            thumbnailID: window.thumbnail.map(ObjectIdentifier.init),
            applicationIconID: ObjectIdentifier(window.applicationIcon),
            preferences: preferences,
            appearance: appearance,
            width: width,
            height: height
        )
    }

    nonisolated static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.renderIdentity == rhs.renderIdentity
    }

    var body: some View {
        let showTitle = preferences.showWindowTitles && width >= 120
        let showIcon = preferences.showApplicationIcons && width >= 60
        let showHeader = showTitle || showIcon

        VStack(alignment: .leading, spacing: showHeader ? 7 : 0) {
            if showHeader {
                HStack(spacing: 8) {
                    if showIcon {
                        Image(nsImage: window.applicationIcon)
                            .resizable()
                            .interpolation(.high)
                            .frame(width: 22, height: 22)
                    }
                    if showTitle {
                        Text(window.title)
                            .font(.callout.weight(.semibold))
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                }
                .frame(height: 22)
            }

            preview(for: window, width: max(1, width - 16))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
        }
        .padding(8)
        .frame(width: width, height: height, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous)
                .fill(appearance.swiftUIBackgroundColor.opacity(0.34))
        )
        .clipShape(RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous))
    }

    private var cardCornerRadius: CGFloat {
        min(20, max(8, appearance.cornerRadius * 0.75))
    }

    @ViewBuilder
    private func preview(for window: SwitchableWindow, width: CGFloat) -> some View {
        if let thumbnail = window.thumbnail {
            switch preferences.previewStyle {
            case .fullWindow:
                ZStack {
                    Rectangle().fill(
                        preferences.usePreviewBackdrop
                            ? Color(nsColor: .underPageBackgroundColor)
                            : Color.black.opacity(0.34)
                    )
                    Image(nsImage: thumbnail)
                        .resizable()
                        .interpolation(.high)
                        .scaledToFit()
                        .padding(4)
                }
            case .edgeToEdge:
                Image(nsImage: thumbnail)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFill()
                    .clipped()
            }
        } else {
            ZStack {
                Rectangle().fill(Color(nsColor: .underPageBackgroundColor))
                Image(nsImage: window.applicationIcon)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                    .frame(width: min(76, width * 0.32), height: min(76, width * 0.32))
            }
        }
    }
}

extension Color {
    init(_ accent: WindowSwitcherAccent) {
        switch accent {
        case .system: self = .accentColor
        case .blue: self = .blue
        case .indigo: self = .indigo
        case .purple: self = .purple
        case .green: self = .green
        case .orange: self = .orange
        case .pink: self = .pink
        }
    }
}
