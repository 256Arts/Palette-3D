import PaletteKit
import SwiftUI

/// A capsule split between two colors by a draggable divider, with each side's picker and share overlaid.
/// The whole track is draggable, so the divider stays reachable even when it sits under an end picker.
struct MixSlider: View {

    @Binding var firstColor: Color
    @Binding var secondColor: Color
    /// Percentage of the first color, `0...100`; the second color takes the remainder.
    @Binding var mix: Double

    private static let height: CGFloat = 64
    private static let dividerWidth: CGFloat = 6
    /// A side narrower than this can't legibly hold its percentage label.
    private static let minimumLabelShare: Double = 16
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
            .contentShape(.capsule)
            .gesture(drag(in: width))
            .overlay { Capsule().strokeBorder(.primary.opacity(0.12)).allowsHitTesting(false) }
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

    /// Dragging anywhere on the track sends the divider to the touch. The pickers overlay this gesture,
    /// so they keep their own taps.
    private func drag(in width: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .named(Self.space))
            .onChanged { mix = min(max(Double($0.location.x / width) * 100, 0), 100) }
    }

    private func divider(in width: CGFloat) -> some View {
        Rectangle()
            .fill(.background)
            .frame(width: Self.dividerWidth)
            .shadow(color: .black.opacity(0.2), radius: 2)
            .offset(x: split(in: width) - Self.dividerWidth / 2)
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
        .padding(.horizontal, 10)
    }

    private func picker(_ title: LocalizedStringKey, selection: Binding<Color>) -> some View {
        ColorPicker(title, selection: selection, supportsOpacity: false)
            .labelsHidden()
    }

    /// One side's percentage, drawn in whichever of black or white contrasts better with that side.
    /// Hidden once the side is too narrow to sit behind the label, and never hit-tested so it can't
    /// shadow the track's drag.
    @ViewBuilder private func share(_ percent: Double, over color: Color) -> some View {
        if percent >= Self.minimumLabelShare {
            Text(percent / 100, format: .percent.precision(.fractionLength(0)))
                .font(.callout.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(legibleColor(over: color))
                .allowsHitTesting(false)
                .transition(.opacity)
        }
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
