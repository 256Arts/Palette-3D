import Foundation
import PaletteKit
import SwiftUI

/// One interpolation space's resolved bar: a single swatch color in mix mode, or gradient stops.
private struct InterpolationBar: Identifiable {
    let space: String
    let colors: [Color]
    var id: String { space }
}

struct DuoView: View {

    /// Whether the page shows single-swatch `color-mix()` results or full gradients between the two colors.
    private enum Mode: String, CaseIterable, Identifiable {
        case mix = "Mix"
        case gradient = "Gradient"
        case stats = "Stats"
        var id: Self { self }
    }

    @Environment(\.dismiss) private var dismiss

    @State private var firstColor = Color(.displayP3, red: 0.60, green: 0.20, blue: 0.85)
    @State private var secondColor = Color(.displayP3, red: 0.00, green: 0.70, blue: 0.85)
    /// Percentage of the first color in the `color-mix()`; the second color takes the remainder.
    @State private var mix: Double = 50
    @State private var mode: Mode = .mix

    /// The natively-drawable bars for the current inputs, one per interpolation space.
    @State private var bars: [InterpolationBar] = []

    /// The CSS interpolation spaces used for the mix/gradient rows, perceptual-first.
    private static let interpolationSpaces = ["oklch", "oklab", "lch", "lab", "hsl", "hwb", "srgb", "srgb-linear", "xyz"]
    /// Stops sampled per gradient bar — enough for a smooth curve through the perceptual path.
    private static let gradientSampleCount = 24

    var body: some View {
        NavigationStack {
            List {
                Section { colorControls }
                if mode == .stats {
                    statsSections
                } else {
                    Section(heading) {
                        ForEach(bars) { bar in
                            interpolationRow(bar)
                        }
                    }
                }
            }
            #if os(macOS)
            .listStyle(.inset)
            #endif
            .task(id: inputKey) { await updateBars() }
            .navigationTitle("Color Duo")
            #if !os(macOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Picker("Mode", selection: $mode) {
                        ForEach(Mode.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                }
                ToolbarItem(placement: .navigation) {
                    Button("Close", systemImage: "xmark", role: .close) { dismiss() }
                }
            }
        }
        #if os(macOS)
        .frame(minWidth: 620, minHeight: 700)
        #else
        .presentationSizing(.page)
        #endif
    }

    /// The mix capsule, or a plain pair of picker rows when the mix ratio doesn't apply.
    @ViewBuilder private var colorControls: some View {
        if mode == .mix {
            MixSlider(firstColor: $firstColor, secondColor: $secondColor, mix: $mix)
                .padding(.vertical, 4)
                .listRowSeparator(.hidden)
        } else {
            ColorPicker("First Color", selection: $firstColor, supportsOpacity: false)
            ColorPicker("Second Color", selection: $secondColor, supportsOpacity: false)
        }
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
        guard let picked = PaletteColor(SystemColor(color), colorSpace: .okLch) else { return "black" }
        return picked.cssString(colorSpace: .okLch, convertedToP3: true)
    }

    /// A monospaced space label beside its resolved swatch or gradient.
    private func interpolationRow(_ bar: InterpolationBar) -> some View {
        LabeledContent {
            barShape(bar.colors)
        } label: {
            Text(bar.space)
                .font(.system(.footnote, design: .monospaced))
                .foregroundStyle(.secondary)
        }
        .labeledContentStyle(.interpolation)
    }

    /// A single swatch (mix mode) or a left-to-right gradient (gradient mode) through the sampled stops.
    private func barShape(_ colors: [Color]) -> some View {
        let shape = RoundedRectangle(cornerRadius: 7)
        return Group {
            if colors.count == 1 {
                shape.fill(colors.first ?? .clear)
            } else {
                shape.fill(LinearGradient(colors: colors, startPoint: .leading, endPoint: .trailing))
            }
        }
        .frame(height: 30)
        .overlay(shape.strokeBorder(.primary.opacity(0.12)))
    }

    private var heading: String {
        switch mode {
        case .stats: ""
        case .mix: "\(percent)% / \(100 - percent)% by interpolation space"
        case .gradient: "Gradients by interpolation space"
        }
    }

    /// A qualitative label for the ΔE₀₀ magnitude.
    private func deltaEDescription(_ deltaE: Double) -> String {
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
        "\(cssColor(firstColor))|\(cssColor(secondColor))|\(percent)|\(mode.rawValue)"
    }

    /// Resolves every space's `color-mix()` (mix mode) or gradient stops in one batched web call.
    private func updateBars() async {
        guard mode != .stats else { return }
        let first = cssColor(firstColor)
        let second = cssColor(secondColor)
        let perBar = mode == .mix ? 1 : Self.gradientSampleCount

        let requests = Self.interpolationSpaces.flatMap { space -> [String] in
            switch mode {
            case .stats:
                return []
            case .mix:
                return ["color-mix(in \(space), \(first) \(percent)%, \(second))"]
            case .gradient:
                // Sampling `color-mix(in S, second t%, first)` across t reproduces the gradient's path.
                return (0..<Self.gradientSampleCount).map { step in
                    let t = Double(step) / Double(Self.gradientSampleCount - 1)
                    return "color-mix(in \(space), \(second) \(String(format: "%.2f", t * 100))%, \(first))"
                }
            }
        }

        let resolved = await WebColorRenderer.shared.resolve(requests)
        guard resolved.count == requests.count else { return }

        bars = Self.interpolationSpaces.enumerated().map { index, space in
            let stops = resolved[(index * perBar)..<((index + 1) * perBar)]
            return InterpolationBar(space: space, colors: Array(stops))
        }
    }
}

/// Lays an interpolation row out as a fixed label column beside a bar that takes the remaining width.
private struct InterpolationLabeledContentStyle: LabeledContentStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 12) {
            configuration.label
                .frame(width: 74, alignment: .leading)
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
                Text(highestGrade)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            HStack(spacing: 12) {
                sample(text: first, on: second)
                sample(text: second, on: first)
            }
            .listRowSeparator(.hidden)
            requirements
        }
    }

    /// The strongest WCAG 2.1 grade the ratio reaches, so the headline number has a plain-language peer.
    private var highestGrade: String {
        switch contrast {
        case 7...: "AAA for all text"
        case 4.5...: "AA for all text"
        case 3...: "AA for large text"
        default: "Below AA"
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

    private func requirement(_ label: String, aa: Double, aaa: Double?) -> some View {
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
    private func target(_ ratio: Double, label: String, grade: String) -> some View {
        let passes = contrast >= ratio
        return HStack(spacing: 4) {
            Image(systemName: passes ? "checkmark.circle.fill" : "xmark.circle.fill")
            Text(ratio, format: .number.precision(.fractionLength(1)))
                .monospacedDigit()
        }
        .font(.subheadline.weight(.medium))
        .foregroundStyle(passes ? Color.green : Color.red.opacity(0.8))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(label), \(grade), needs \(ratio.formatted()) to 1")
        .accessibilityValue(passes ? "Pass" : "Fail")
    }
}

#Preview {
    DuoView()
}
