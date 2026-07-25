import SwiftUI

/// One interpolation space's ramp from lightest to darkest, with the base color in the middle.
private struct ShadeRamp: Identifiable {
    let space: String
    let shades: [Color]
    var id: String { space }
}

/// Tints and shades of one color, produced by mixing it toward white and black in several CSS color
/// spaces — the same ramp reads very differently in `oklch` than in `srgb`. Swatches are draggable,
/// so a shade can be dropped straight into a palette.
struct ShadesView: View {

    /// The base color as a CSS literal, e.g. `oklch(...)` or `color(display-p3 ...)`.
    let css: String

    @State private var ramps: [ShadeRamp] = []

    /// Interpolation spaces worth comparing: perceptual, then the classic web spaces.
    private static let spaces = ["oklch", "oklab", "lch", "hsl", "srgb"]
    /// Mix amount at each step: negative mixes toward white, positive toward black, zero is the base.
    private static let steps: [Double] = [-80, -60, -40, -20, 0, 20, 40, 60, 80]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Shades")
                .font(.headline)
            VStack(spacing: 10) {
                ForEach(ramps) { ramp in
                    HStack(spacing: 12) {
                        Text(ramp.space)
                            .font(.system(.footnote, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .frame(width: 52, alignment: .leading)
                        strip(ramp.shades)
                    }
                }
                legend
            }
            .padding(12)
            .background(.quaternary.opacity(0.5), in: .rect(cornerRadius: 12))
        }
        .task(id: css) { await load() }
    }

    /// The ramp as one continuous bar, each step draggable as its own color.
    private func strip(_ shades: [Color]) -> some View {
        let shape = RoundedRectangle(cornerRadius: 7)
        return HStack(spacing: 0) {
            ForEach(Array(shades.enumerated()), id: \.offset) { _, shade in
                shade
                    .frame(maxWidth: .infinity)
                    .draggable(shade)
            }
        }
        .frame(height: 32)
        .clipShape(shape)
        .overlay(shape.strokeBorder(.primary.opacity(0.12)))
    }

    private var legend: some View {
        HStack {
            Text("Lighter")
            Spacer()
            Text("Base")
            Spacer()
            Text("Darker")
        }
        .font(.caption2)
        .foregroundStyle(.secondary)
        .padding(.leading, 64)
    }

    /// Resolves every space's full ramp in one batched web call.
    private func load() async {
        let requests = Self.spaces.flatMap { space in
            Self.steps.map { request(space: space, amount: $0) }
        }
        let resolved = await WebColorRenderer.shared.resolve(requests)
        guard resolved.count == requests.count else { return }

        ramps = Self.spaces.enumerated().map { index, space in
            let shades = resolved[(index * Self.steps.count)..<((index + 1) * Self.steps.count)]
            return ShadeRamp(space: space, shades: Array(shades))
        }
    }

    private func request(space: String, amount: Double) -> String {
        guard amount != 0 else { return css }
        let toward = amount < 0 ? "white" : "black"
        return "color-mix(in \(space), \(toward) \(abs(amount).formatted())%, \(css))"
    }
}

#Preview {
    ShadesView(css: "oklch(0.7 0.15 30)")
        .padding()
}
