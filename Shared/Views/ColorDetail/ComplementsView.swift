import SwiftUI

/// A CSS color space with a hue channel, and where that channel sits in its channel list.
///
/// Only these three are offered: `oklab`/`lab`/`srgb` have no hue channel to rotate, and `hwb` shares
/// sRGB's hue definition with `hsl`, so rotating in it lands on exactly the same colors.
private struct HueSpace: Identifiable {

    let name: String
    /// The space's channels in relative-color-syntax order, `h` marking the hue slot.
    let channels: [String]

    var id: String { name }

    /// `css` rotated to step `index` of `total` evenly spaced hues, as relative color syntax.
    ///
    /// The rotation stays an exact CSS expression rather than a formatted number: `360 / 7` has no short
    /// decimal, and `formatted()` would put a locale's comma separator into what has to parse as CSS.
    func rotation(of css: String, step index: Int, of total: Int) -> String {
        let rotated = channels.map { $0 == "h" ? "calc(h + 360 * \(index) / \(total))" : $0 }
        return "\(name)(from \(css) \(rotated.joined(separator: " ")))"
    }
}

/// One rotation of the base color, in one space.
private struct Complement: Identifiable {
    let id: Int
    let degrees: Double
    let color: Color
}

/// One space's wheel: the base color followed by every rotation of it.
private struct ComplementWheel: Identifiable {
    let space: String
    let complements: [Complement]
    var id: String { space }
}

/// Colors evenly spaced around the hue wheel from one base color, rotated in several CSS color spaces —
/// the same rotation lands somewhere quite different in `oklch` than in `hsl`. Swatches are draggable,
/// so a complement can be dropped straight into a palette.
struct ComplementsView: View {

    /// The base color as a CSS literal, e.g. `oklch(...)` or `color(display-p3 ...)`.
    let css: String

    /// Opens a complement's own details.
    let onSelect: (Color) -> Void

    /// How many colors to rotate to, beside the original. Persisted because it's a working preference:
    /// someone who designs in triads wants triads every time they open a color.
    @AppStorage("complementCount") private var count = 1

    @State private var wheels: [ComplementWheel] = []

    private static let spaces = [
        HueSpace(name: "oklch", channels: ["l", "c", "h"]),
        HueSpace(name: "lch", channels: ["l", "c", "h"]),
        HueSpace(name: "hsl", channels: ["h", "s", "l"]),
    ]

    /// The base plus `count` rotations, so the colors divide the wheel evenly between them.
    private var total: Int { count + 1 }

    /// Every swatch's CSS, space-major. Also the `.task` id: it changes on exactly the edits that
    /// invalidate a swatch, and nothing else.
    private var requests: [String] {
        Self.spaces.flatMap { space in
            (0..<total).map { space.rotation(of: css, step: $0, of: total) }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            VStack(spacing: 10) {
                ForEach(wheels) { wheel in
                    HStack(spacing: 12) {
                        Text(wheel.space)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .frame(width: 52, alignment: .leading)
                        strip(wheel.complements)
                    }
                }
                legend
            }
            .padding(12)
            .background(Color.groupedContent, in: .rect(cornerRadius: 12))
        }
        .task(id: requests) { await load() }
    }

    private var header: some View {
        HStack {
            Text("Complements")
                .font(.headline)
            Spacer()
            Stepper(value: $count, in: 1...15) {
                Text(harmonyName ?? "\(total) Colors")
                    .font(.subheadline)
                    .monospacedDigit()
            }
            .fixedSize()
            .accessibilityLabel("Number of colors")
            .accessibilityValue("\(total)")
        }
    }

    /// The classic name for an evenly spaced wheel of this size, where one exists — these are the sizes
    /// a designer already thinks in, so the stepper names them rather than making them be counted out.
    private var harmonyName: LocalizedStringResource? {
        switch total {
        case 2: "Complementary"
        case 3: "Triadic"
        case 4: "Square"
        default: nil
        }
    }

    /// The wheel as one continuous bar, each rotation draggable as its own color and tappable for details.
    private func strip(_ complements: [Complement]) -> some View {
        let shape = RoundedRectangle(cornerRadius: 7)
        return HStack(spacing: 0) {
            ForEach(complements) { complement in
                swatch(complement)
                    .draggable(complement.color)
            }
        }
        .frame(height: 32)
        .clipShape(shape)
        .overlay(shape.strokeBorder(.primary.opacity(0.12)))
    }

    /// One rotation, a button into its own details. `.plain` because a tinted style would paint over the
    /// very thing on show.
    private func swatch(_ complement: Complement) -> some View {
        Button {
            onSelect(complement.color)
        } label: {
            complement.color.frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(name(of: complement))
    }

    /// The wheel is otherwise a row of unnamed swatches, indistinguishable to VoiceOver.
    private func name(of complement: Complement) -> LocalizedStringKey {
        complement.id == 0 ? "Original" : "\(degrees(complement.degrees)) degree hue rotation"
    }

    private var legend: some View {
        Text("Each step rotates the hue \(degrees(360 / Double(total)))°.")
            .font(.caption2)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, 64)
    }

    /// Localized, and trimmed to the one decimal the odd divisions actually need — 360 / 16 is 22.5°,
    /// while most counts come out whole and shouldn't read "120.0".
    private func degrees(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(0...1)))
    }

    /// Resolves every space's full wheel in one batched web call.
    private func load() async {
        let requests = self.requests
        let resolved = await WebColorRenderer.shared.resolve(requests)
        // The Stepper auto-repeats, so loads overlap; a cancelled one must not land on top of a newer.
        guard !Task.isCancelled, resolved.count == requests.count else { return }

        let degreesPerStep = 360 / Double(total)
        wheels = Self.spaces.enumerated().map { index, space in
            let colors = resolved[(index * total)..<((index + 1) * total)]
            let complements = colors.enumerated().map { step, color in
                Complement(id: step, degrees: Double(step) * degreesPerStep, color: color)
            }
            return ComplementWheel(space: space.name, complements: complements)
        }
    }
}

#Preview {
    ComplementsView(css: "oklch(0.7 0.15 30)", onSelect: { _ in })
        .padding()
}
