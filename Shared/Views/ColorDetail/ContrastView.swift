import PaletteKit
import SwiftUI

/// How the color fares against the two it will always end up beside: white and black.
///
/// Each row samples text both ways — the color on the neutral and the neutral on the color — because the
/// WCAG ratio is symmetric while legibility isn't obviously so, and a designer is choosing between those
/// two arrangements, not computing a number.
struct ContrastView: View {

    let color: PaletteColor
    let colorSpace: ColorSpace

    private var swatch: Color { color.color(colorSpace: colorSpace) }
    private var luminance: Double { color.relativeLuminance(colorSpace: colorSpace) }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Contrast")
                .font(.headline)
            VStack(spacing: 0) {
                // White and black are the endpoints of relative luminance, so their ratios need no sampling.
                row(against: .white, luminance: 1, name: "White")
                Divider()
                row(against: .black, luminance: 0, name: "Black")
            }
            .padding(12)
            .background(Color.groupedContent, in: .rect(cornerRadius: 12))
        }
    }

    private func row(against neutral: Color, luminance neutralLuminance: Double, name: LocalizedStringKey) -> some View {
        let ratio = ColorMetrics.wcagContrast(luminance, neutralLuminance)
        return HStack(spacing: 12) {
            Text(name)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .frame(width: 52, alignment: .leading)
            sample(text: swatch, on: neutral)
            sample(text: neutral, on: swatch)
            Spacer(minLength: 0)
            VStack(alignment: .trailing, spacing: 1) {
                Text(verbatim: "\(ratio.formatted(.number.precision(.fractionLength(2)))):1")
                    .font(.system(.body, design: .rounded).weight(.bold))
                    .monospacedDigit()
                    .accessibilityLabel("\(ratio.formatted(.number.precision(.fractionLength(2)))) to 1")
                Text(ColorMetrics.wcagGrade(ratio))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 8)
        // Four elements that only mean anything together: which neutral, how far apart, and what that grades.
        .accessibilityElement(children: .combine)
    }

    /// A live preview of one color's text on the other. Bordered, since a white tile on a white card is
    /// otherwise only its letters.
    private func sample(text textColor: Color, on background: Color) -> some View {
        let shape = RoundedRectangle(cornerRadius: 8)
        return Text("Aa")
            .font(.system(.subheadline, design: .rounded).weight(.semibold))
            .foregroundStyle(textColor)
            .frame(width: 44, height: 34)
            .background(background, in: shape)
            .overlay(shape.strokeBorder(.primary.opacity(0.12)))
            .accessibilityHidden(true)
    }
}

#Preview {
    ContrastView(
        color: PaletteColor(lightnessFraction: 0.6, chromaFraction: 0.5, hueAngle: .degrees(30)),
        colorSpace: .okLch)
        .padding()
}
