import PaletteKit
import SwiftUI

/// A capsule split between two colors by a draggable divider, with each side's picker and share overlaid.
struct MixSlider: View {

    @Binding var firstColor: Color
    @Binding var secondColor: Color
    /// Percentage of the first color, `0...100`; the second color takes the remainder.
    @Binding var mix: Double

    private static let height: CGFloat = 44
    private static let dividerWidth: CGFloat = 8
    /// Widened invisible hit area so the divider stays grabbable at a comfortable touch size.
    private static let dividerHitWidth: CGFloat = 44
    private static let space = "MixSlider"

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            ZStack(alignment: .leading) {
                HStack(spacing: 0) {
                    firstColor.frame(width: split(in: width))
                    secondColor
                }
                divider(in: width)
            }
            .clipShape(.capsule)
            .overlay(Capsule().strokeBorder(.primary.opacity(0.12)))
            .overlay(controls)
            .coordinateSpace(.named(Self.space))
        }
        .frame(height: Self.height)
        .accessibilityRepresentation {
            Slider(value: $mix, in: 0...100) { Text("Mix") }
        }
    }

    /// The divider's distance from the leading edge for a given track width.
    private func split(in width: CGFloat) -> CGFloat {
        width * CGFloat(mix) / 100
    }

    private func divider(in width: CGFloat) -> some View {
        Rectangle()
            .fill(.background)
            .frame(width: Self.dividerWidth)
            .frame(width: Self.dividerHitWidth)
            .contentShape(.rect)
            .offset(x: split(in: width) - Self.dividerHitWidth / 2)
            .gesture(
                DragGesture(minimumDistance: 0, coordinateSpace: .named(Self.space))
                    .onChanged { mix = min(max(Double($0.location.x / width) * 100, 0), 100) }
            )
            #if os(iOS)
            .hoverEffect(.highlight)
            #endif
    }

    private var controls: some View {
        HStack(spacing: 8) {
            picker("First Color", selection: $firstColor)
            share(mix, over: firstColor)
            Spacer(minLength: 0)
            share(100 - mix, over: secondColor)
            picker("Second Color", selection: $secondColor)
        }
        .padding(.horizontal, 6)
    }

    private func picker(_ title: LocalizedStringKey, selection: Binding<Color>) -> some View {
        ColorPicker(title, selection: selection, supportsOpacity: false)
            .labelsHidden()
    }

    /// One side's percentage, drawn in whichever of black or white contrasts better with that side.
    private func share(_ percent: Double, over color: Color) -> some View {
        Text(percent / 100, format: .percent.precision(.fractionLength(0)))
            .font(.subheadline.weight(.semibold))
            .monospacedDigit()
            .foregroundStyle(legibleColor(over: color))
    }

    private func legibleColor(over color: Color) -> Color {
        guard let luminance = ColorMetrics.sample(SystemColor(color))?.luminance else { return .primary }
        return ColorMetrics.wcagContrast(luminance, 1) >= ColorMetrics.wcagContrast(luminance, 0) ? .white : .black
    }
}

#Preview {
    @Previewable @State var first = Color.purple
    @Previewable @State var second = Color.teal
    @Previewable @State var mix: Double = 60
    MixSlider(firstColor: $first, secondColor: $second, mix: $mix)
        .padding()
}
