import AppKit
import KeyFlowCore
import SwiftUI

struct HueColorPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var hue: Double
    @State private var saturation: Double
    @State private var brightness: Double

    let onApply: (PersistedRGBAColor) -> Void

    init(
        initialColor: NSColor,
        appearance: NSAppearance,
        onApply: @escaping (PersistedRGBAColor) -> Void
    ) {
        var resolvedColor = NSColor.systemBlue
        appearance.performAsCurrentDrawingAppearance {
            resolvedColor = initialColor.usingColorSpace(.sRGB) ?? NSColor.systemBlue
        }
        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 1
        var alpha: CGFloat = 1
        resolvedColor.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)
        _hue = State(initialValue: hue)
        _saturation = State(initialValue: saturation)
        _brightness = State(initialValue: brightness)
        self.onApply = onApply
    }

    private var selectedColor: Color {
        Color(hue: hue, saturation: saturation, brightness: brightness)
    }

    var body: some View {
        VStack(spacing: 16) {
            VStack(spacing: 3) {
                Text("Custom Sound Bar Hue")
                    .font(.headline)
                Text("Choose a hue and saturation, then adjust brightness.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HueSaturationWheel(hue: $hue, saturation: $saturation, brightness: brightness)
                .frame(width: 230, height: 230)

            HStack(spacing: 10) {
                Image(systemName: "sun.min")
                    .foregroundStyle(.secondary)
                Slider(value: $brightness, in: 0.15...1)
                Image(systemName: "sun.max.fill")
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 10) {
                RoundedRectangle(cornerRadius: 7)
                    .fill(selectedColor)
                    .frame(width: 42, height: 28)
                    .overlay {
                        RoundedRectangle(cornerRadius: 7)
                            .stroke(Color.primary.opacity(0.15), lineWidth: 1)
                    }
                Text(hexValue)
                    .font(.callout.monospaced())
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("OK") {
                    onApply(persistedColor)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 340)
    }

    private var persistedColor: PersistedRGBAColor {
        let color =
            NSColor(calibratedHue: hue, saturation: saturation, brightness: brightness, alpha: 1)
            .usingColorSpace(.sRGB) ?? .systemBlue
        return PersistedRGBAColor(
            red: color.redComponent,
            green: color.greenComponent,
            blue: color.blueComponent
        )
    }

    private var hexValue: String {
        let color = persistedColor
        return String(
            format: "#%02X%02X%02X",
            Int((color.red * 255).rounded()),
            Int((color.green * 255).rounded()),
            Int((color.blue * 255).rounded())
        )
    }
}

private struct HueSaturationWheel: View {
    @Binding var hue: Double
    @Binding var saturation: Double
    let brightness: Double

    var body: some View {
        GeometryReader { proxy in
            let diameter = min(proxy.size.width, proxy.size.height)
            let radius = diameter / 2
            let markerRadius = radius * saturation
            let angle = hue * .pi * 2

            ZStack {
                Circle()
                    .fill(
                        AngularGradient(
                            colors: [.red, .yellow, .green, .cyan, .blue, .purple, .red],
                            center: .center,
                            startAngle: .degrees(0),
                            endAngle: .degrees(360)
                        )
                    )
                    .overlay {
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [.white, .white.opacity(0)],
                                    center: .center,
                                    startRadius: 0,
                                    endRadius: radius
                                )
                            )
                    }
                    .brightness(brightness - 1)

                Circle()
                    .fill(Color(hue: hue, saturation: saturation, brightness: brightness))
                    .frame(width: 16, height: 16)
                    .overlay(Circle().stroke(.white, lineWidth: 2))
                    .shadow(color: .black.opacity(0.45), radius: 2)
                    .position(
                        x: radius + cos(angle) * markerRadius,
                        y: radius + sin(angle) * markerRadius
                    )
            }
            .frame(width: diameter, height: diameter)
            .contentShape(Circle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let deltaX = value.location.x - radius
                        let deltaY = value.location.y - radius
                        saturation = min(1, hypot(deltaX, deltaY) / radius)
                        var resolvedHue = atan2(deltaY, deltaX) / (.pi * 2)
                        if resolvedHue < 0 { resolvedHue += 1 }
                        hue = resolvedHue
                    }
            )
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Hue and saturation wheel")
        .accessibilityValue("Hue \(Int(hue * 360)) degrees, saturation \(Int(saturation * 100)) percent")
    }
}
