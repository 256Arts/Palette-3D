import PaletteKit
import SwiftUI

/// A capsule split between two colors, each half a button into that color's details.
///
/// With a `mix` binding the split is also the user's to move: a grabber sits on it, and each side carries
/// its share as a percentage. Without one the capsule divides evenly — Gradient and Stats compare a pair
/// rather than mixing it — but the pair is presented identically either way, so changing mode doesn't
/// rearrange the page.
struct ColorPairBar: View {

    @Binding var firstColor: Color
    @Binding var secondColor: Color
    /// The first color's share, `0...100`, when the split moves. `nil` fixes it at half, and takes the
    /// grabber and the percentage labels with it.
    var mix: Binding<Double>?
    let colorSpace: ColorSpace

    private static let height: CGFloat = 64
    private static let indicatorWidth: CGFloat = 6
    /// Inset from the track's ends, so the indicator reads as a grabber rather than a hard split.
    private static let indicatorInset: CGFloat = 14
    /// A 6pt line is too thin to grab, so an invisible strip this wide carries the gesture.
    private static let grabWidth: CGFloat = 44
    /// A side narrower than this can't legibly hold its percentage label.
    private static let minimumLabelShare: Double = 16
    private static let space = "ColorPairBar"

    private var share: Double { mix?.wrappedValue ?? 50 }

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            HStack(spacing: 0) {
                half($firstColor, title: "First Color")
                    .frame(width: split(in: width))
                half($secondColor, title: "Second Color")
            }
            .overlay(alignment: .leading) { indicator(in: width) }
            .clipShape(.capsule)
            .overlay { Capsule().strokeBorder(.primary.opacity(0.12)).allowsHitTesting(false) }
            .overlay(labels)
            .overlay(alignment: .leading) { grabber(in: width) }
            .coordinateSpace(.named(Self.space))
        }
        .frame(height: Self.height)
    }

    /// One side of the capsule: the color itself, tapping into its own details.
    private func half(_ color: Binding<Color>, title: LocalizedStringKey) -> some View {
        ColorDetailsButton(title: title, color: color, colorSpace: colorSpace) {
            color.wrappedValue
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    /// The divider's distance from the leading edge for a given track width.
    private func split(in width: CGFloat) -> CGFloat {
        width * CGFloat(share) / 100
    }

    /// The grab handle sitting on the split — a capsule inset from the track's ends, so it reads as
    /// something to drag rather than as a seam between the two colors. The strip that actually carries the
    /// drag is `grabber`, above it.
    @ViewBuilder private func indicator(in width: CGFloat) -> some View {
        if mix != nil {
            Capsule()
                .fill(.background)
                .frame(width: Self.indicatorWidth)
                .padding(.vertical, Self.indicatorInset)
                .shadow(color: .black.opacity(0.25), radius: 3)
                .offset(x: split(in: width) - Self.indicatorWidth / 2)
                .allowsHitTesting(false)
        }
    }

    /// The split's drag target, invisible and sitting above the halves — which is what keeps a drag on the
    /// divider from also reading as a tap into a color's details. It's the slider, so it carries the
    /// accessibility representation too; the halves stay buttons.
    @ViewBuilder private func grabber(in width: CGFloat) -> some View {
        if let mix {
            Color.clear
                .frame(width: Self.grabWidth)
                .contentShape(.rect)
                .offset(x: split(in: width) - Self.grabWidth / 2)
                .gesture(
                    DragGesture(minimumDistance: 0, coordinateSpace: .named(Self.space))
                        .onChanged { mix.wrappedValue = min(max(Double($0.location.x / width) * 100, 0), 100) }
                )
                .accessibilityRepresentation {
                    Slider(value: mix, in: 0...100) { Text("Mix") }
                }
        }
    }

    /// Each side's share of the mix. Never hit-tested, so it can't shadow the buttons underneath.
    @ViewBuilder private var labels: some View {
        if let mix {
            HStack(spacing: 0) {
                label(mix.wrappedValue, over: firstColor)
                Spacer(minLength: 0)
                label(100 - mix.wrappedValue, over: secondColor)
            }
            .padding(.horizontal, 14)
            .allowsHitTesting(false)
        }
    }

    /// One side's percentage, drawn in whichever of black or white contrasts better with that side, and
    /// hidden once the side is too narrow to sit behind it.
    @ViewBuilder private func label(_ percent: Double, over color: Color) -> some View {
        if percent >= Self.minimumLabelShare {
            Text(percent / 100, format: .percent.precision(.fractionLength(0)))
                .font(.callout.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(legibleColor(over: color))
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
    VStack(spacing: 20) {
        ColorPairBar(firstColor: $first, secondColor: $second, mix: $mix, colorSpace: .okLch)
        ColorPairBar(firstColor: $first, secondColor: $second, colorSpace: .okLch)
    }
    .padding()
}
