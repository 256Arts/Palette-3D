import Foundation
import PaletteKit
import SwiftUI

/// One interpolation space's resolved bar: the `color-mix()` swatch, the gradient's stops, or — where
/// the width allows both — the two side by side.
private struct InterpolationBar: Identifiable {
    let space: String
    let mix: Color?
    let gradient: [Color]
    var id: String { space }
}

/// Compares two colors: their `color-mix()` result and gradient path through every CSS interpolation
/// space, plus the perceptual difference and contrast between them. A root tab, not a sheet.
///
/// At a regular width the page shows all of that at once — each space's swatch beside its gradient, with
/// the statistics as their own sections — so the mode picker only exists where a compact width forces the
/// three to take turns.
struct PairsView: View {

    /// Which one of the three the page shows when it can only show one. Regular widths show all three.
    private enum Mode: String, CaseIterable, Identifiable {
        case mix = "Mix"
        case gradient = "Gradient"
        case stats = "Stats"
        var id: Self { self }
    }

    @State private var firstColor = Color(.displayP3, red: 0.60, green: 0.20, blue: 0.85)
    @State private var secondColor = Color(.displayP3, red: 0.00, green: 0.70, blue: 0.85)
    /// Percentage of the first color in the `color-mix()`; the second color takes the remainder.
    @State private var mix: Double = 50
    @State private var mode: Mode = .mix

    #if os(macOS)
    /// macOS has no size classes, and a window here is never as narrow as a phone.
    private var isRegularWidth: Bool { true }
    #else
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    private var isRegularWidth: Bool { horizontalSizeClass == .regular }
    #endif

    /// A regular width shows every part at once; a compact one shows whichever the picker selects.
    private var showsMix: Bool { isRegularWidth || mode == .mix }
    private var showsGradient: Bool { isRegularWidth || mode == .gradient }
    private var showsStats: Bool { isRegularWidth || mode == .stats }

    /// The natively-drawable bars for the current inputs, one per interpolation space.
    @State private var bars: [InterpolationBar] = []

    /// A mix opened for inspection. It belongs to no palette, so it presents with no Add.
    @State private var inspected: InspectedColor?

    /// Mixes are read back into the same space the rest of the app imports into.
    private static let colorSpace = ColorSpace.okLch

    /// The CSS interpolation spaces used for the mix/gradient rows, perceptual-first.
    private static let interpolationSpaces = ["oklch", "oklab", "lch", "lab", "hsl", "hwb", "srgb", "srgb-linear", "xyz"]
    /// Stops sampled per gradient bar — enough for a smooth curve through the perceptual path.
    private static let gradientSampleCount = 24

    var body: some View {
        NavigationStack {
            List {
                Section { colorControls }
                    #if !os(macOS)
                    .listSectionSpacing(.compact)
                    #endif
                if showsMix || showsGradient {
                    Section(heading) {
                        ForEach(bars) { bar in
                            interpolationRow(bar)
                        }
                    }
                }
                if showsStats {
                    statsSections
                }
            }
            #if os(macOS)
            .listStyle(.inset)
            #endif
            .task(id: inputKey) { await updateBars() }
            .navigationTitle("Pairs")
            #if !os(macOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                if !isRegularWidth {
                    ToolbarItem(placement: .principal) {
                        Picker("Mode", selection: $mode) {
                            ForEach(Mode.allCases) { Text($0.rawValue).tag($0) }
                        }
                        .pickerStyle(.segmented)
                    }
                }
            }
            .inspectingColor($inspected, colorSpace: Self.colorSpace)
        }
    }

    /// The pair itself — the same capsule in every mode, gaining a movable split only where a mix ratio
    /// means something. It's its own shape, so it drops the row's background and vertical padding rather
    /// than sitting inset inside a second container.
    private var colorControls: some View {
        ColorPairBar(firstColor: $firstColor,
                     secondColor: $secondColor,
                     mix: showsMix ? $mix : nil,
                     colorSpace: Self.colorSpace)
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
            .listRowInsets(.vertical, 0)
    }

    private var percent: Int { Int(mix.rounded()) }

    /// Perceptual difference (CIEDE2000) and WCAG relative-luminance contrast between the two colors.
    private var metrics: (deltaE: Double, contrast: Double)? {
        guard let first = ColorMetrics.sample(SystemColor(firstColor)),
              let second = ColorMetrics.sample(SystemColor(secondColor)) else { return nil }
        return (ColorMetrics.deltaE2000(first, second), ColorMetrics.wcagContrast(first, second))
    }

    @ViewBuilder private var statsSections: some View {
        if let metrics {
            Section("Perceptual Difference") {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(metrics.deltaE, format: .number.precision(.fractionLength(1)))
                        .font(.system(.largeTitle, design: .rounded).weight(.bold))
                        .monospacedDigit()
                    Text("ΔE₀₀")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Spacer(minLength: 8)
                    Text(deltaEDescription(metrics.deltaE))
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }
            ContrastSection(first: firstColor, second: secondColor, contrast: metrics.contrast)
        }
    }

    /// A picked color as a CSS `color(display-p3 ...)` literal, preserving wide-gamut values.
    private func cssColor(_ color: Color) -> String {
        guard let picked = PaletteColor(SystemColor(color), colorSpace: Self.colorSpace) else { return "black" }
        return picked.cssString(colorSpace: Self.colorSpace, convertedToP3: true)
    }

    /// The CSS that draws a gradient row. The stops on screen are sampled from `color-mix()` in the same
    /// space, taking the same default `shorter hue` path, so this reproduces the bar rather than
    /// approximating it. A gradient is the one thing here that isn't a color, so it's copied rather than
    /// inspected — and it carries no direction, which is the caller's to decide, not the bar's.
    private func cssGradient(_ space: String) -> String {
        "linear-gradient(in \(space), \(cssColor(firstColor)), \(cssColor(secondColor)))"
    }

    /// A space label beside its resolved swatch, its gradient, or both. Sharing a row is what lets the
    /// mode picker go: the swatch is the gradient's midpoint made tappable, and they measure the same path.
    private func interpolationRow(_ bar: InterpolationBar) -> some View {
        LabeledContent {
            HStack(spacing: 12) {
                if let mix = bar.mix {
                    // The swatch only narrows when it shares the row; alone it reads as the bar it replaces.
                    mixSwatch(mix, width: bar.gradient.isEmpty ? nil : Self.sharedMixSwatchWidth)
                }
                if !bar.gradient.isEmpty {
                    gradientBar(bar.gradient)
                    Button("Copy CSS Gradient", systemImage: "doc.on.doc") {
                        cssGradient(bar.space).copyToPasteboard()
                    }
                    .labelStyle(.iconOnly)
                    .buttonStyle(.borderless)
                }
            }
        } label: {
            Text(bar.space)
                .font(.headline)
                .foregroundStyle(.secondary)
        }
        .labeledContentStyle(.interpolation)
    }

    /// A single mixed swatch, which taps into its own details.
    private func mixSwatch(_ color: Color, width: CGFloat?) -> some View {
        Button {
            inspected = InspectedColor(color, colorSpace: Self.colorSpace)
        } label: {
            Self.barShape.fill(color)
                .frame(width: width, height: Self.barHeight)
                .overlay(Self.barShape.strokeBorder(.primary.opacity(0.12)))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Mixed color")
        .accessibilityAddTraits(.isButton)
    }

    /// A left-to-right gradient through the sampled stops. Its stops aren't tappable: every one of them is
    /// a mix ratio away on the slider, and 24 hit targets per row would bury the bar in VoiceOver.
    private func gradientBar(_ colors: [Color]) -> some View {
        Self.barShape.fill(LinearGradient(colors: colors, startPoint: .leading, endPoint: .trailing))
            .frame(height: Self.barHeight)
            .overlay(Self.barShape.strokeBorder(.primary.opacity(0.12)))
    }

    private static let barShape = RoundedRectangle(cornerRadius: 7)
    private static let barHeight: CGFloat = 30
    /// What the mix swatch shrinks to when the gradient shares its row — a color needs no width to read,
    /// where the gradient's whole point is the path across it.
    private static let sharedMixSwatchWidth: CGFloat = 60

    private var heading: String {
        if showsMix && showsGradient { return "Interpolation Spaces" }
        return showsGradient ? "Gradients by Interpolation Space" : "Mix by Interpolation Space"
    }

    /// A qualitative label for the ΔE₀₀ magnitude.
    private func deltaEDescription(_ deltaE: Double) -> LocalizedStringResource {
        switch deltaE {
        case ..<1: "Imperceptible"
        case ..<2: "Barely perceptible"
        case ..<10: "Perceptible"
        case ..<50: "Distinct"
        default: "Very distinct"
        }
    }

    /// A value that changes whenever the resolved bars need recomputing.
    private var inputKey: String {
        "\(cssColor(firstColor))|\(cssColor(secondColor))|\(percent)|\(showsMix)|\(showsGradient)"
    }

    /// Resolves every space's `color-mix()` swatch, its gradient stops, or both in one batched web call.
    private func updateBars() async {
        guard showsMix || showsGradient else {
            bars = []
            return
        }
        let first = cssColor(firstColor)
        let second = cssColor(secondColor)
        let gradientCount = showsGradient ? Self.gradientSampleCount : 0
        let perBar = (showsMix ? 1 : 0) + gradientCount

        let requests = Self.interpolationSpaces.flatMap { space -> [String] in
            var css: [String] = []
            if showsMix {
                css.append("color-mix(in \(space), \(first) \(percent)%, \(second))")
            }
            if showsGradient {
                // Sampling `color-mix(in S, second t%, first)` across t reproduces the gradient's path.
                css += (0..<Self.gradientSampleCount).map { step in
                    let t = Double(step) / Double(Self.gradientSampleCount - 1)
                    return "color-mix(in \(space), \(second) \(String(format: "%.2f", t * 100))%, \(first))"
                }
            }
            return css
        }

        let resolved = await WebColorRenderer.shared.resolve(requests)
        guard resolved.count == requests.count else { return }

        bars = Self.interpolationSpaces.enumerated().map { index, space in
            let stops = Array(resolved[(index * perBar)..<((index + 1) * perBar)])
            return InterpolationBar(space: space,
                                    mix: showsMix ? stops.first : nil,
                                    gradient: Array(stops.suffix(gradientCount)))
        }
    }
}

/// Lays an interpolation row out as a fixed label column beside a bar that takes the remaining width.
private struct InterpolationLabeledContentStyle: LabeledContentStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 12) {
            configuration.label
                .frame(width: 100, alignment: .leading)
            configuration.content
        }
    }
}

private extension LabeledContentStyle where Self == InterpolationLabeledContentStyle {
    static var interpolation: Self { Self() }
}

/// The WCAG readout: the measured ratio, live text samples, and each threshold's required ratio.
private struct ContrastSection: View {

    let first: Color
    let second: Color
    let contrast: Double

    var body: some View {
        Section("Contrast") {
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(contrast, format: .number.precision(.fractionLength(2)))
                    .font(.system(.largeTitle, design: .rounded).weight(.bold))
                    .monospacedDigit()
                Text(verbatim: ":1")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer(minLength: 8)
                Text(ColorMetrics.wcagGrade(contrast))
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            // The leading sample keeps the first color as its background, so the two read in the same order
            // as the capsule's halves above them.
            HStack(spacing: 12) {
                sample(text: second, on: first)
                sample(text: first, on: second)
            }
            .listRowSeparator(.hidden)
            requirements
        }
    }

    /// A live preview of one color's text on the other as its background.
    private func sample(text textColor: Color, on background: Color) -> some View {
        Text("Aa")
            .font(.system(.title3, design: .rounded).weight(.semibold))
            .foregroundStyle(textColor)
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background(background, in: .rect(cornerRadius: 10))
    }

    private var requirements: some View {
        Grid(horizontalSpacing: 16, verticalSpacing: 10) {
            GridRow {
                Color.clear.frame(height: 0).gridColumnAlignment(.leading)
                Text("AA").gridColumnAlignment(.trailing)
                Text("AAA").gridColumnAlignment(.trailing)
            }
            .font(.caption.weight(.bold))
            .foregroundStyle(.secondary)
            requirement("Normal text", aa: 4.5, aaa: 7)
            requirement("Large text", aa: 3, aaa: 4.5)
            requirement("UI & graphics", aa: 3, aaa: nil)
        }
    }

    private func requirement(_ label: LocalizedStringKey, aa: Double, aaa: Double?) -> some View {
        GridRow {
            Text(label).font(.callout)
            target(aa, label: label, grade: "AA")
            if let aaa {
                target(aaa, label: label, grade: "AAA")
            } else {
                Text(verbatim: "—").foregroundStyle(.tertiary)
            }
        }
    }

    /// One threshold: its required ratio, marked pass or fail against the measured contrast.
    private func target(_ ratio: Double, label: LocalizedStringKey, grade: String) -> some View {
        let passes = contrast >= ratio
        return HStack(spacing: 4) {
            Image(systemName: passes ? "checkmark.circle.fill" : "xmark.circle.fill")
            Text(ratio, format: .number.precision(.fractionLength(1)))
                .monospacedDigit()
        }
        .font(.subheadline.weight(.medium))
        .foregroundStyle(passes ? Color.green : Color.red.opacity(0.8))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("\(Text(label)), \(grade), needs \(ratio.formatted()) to 1"))
        .accessibilityValue(passes ? "Pass" : "Fail")
    }
}

#Preview {
    PairsView()
}
