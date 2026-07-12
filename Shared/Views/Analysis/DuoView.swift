//
//  DuoView.swift
//  Palette 3D
//
//  Pick two colors and a mix amount, then compare how CSS blends them: a `color-mix()` swatch
//  followed by a gradient between the two colors in each interpolation color space.
//  A background ``WebColorRenderer`` resolves the CSS colors (SwiftUI has no `color-mix()` or
//  per-space interpolation); the results are drawn natively as `Color` swatches and gradients.
//

import SwiftUI
import Foundation
import ChromaKit

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

    /// Resolves `color-mix()` / gradient stops in the background, off the SwiftUI view tree.
    @State private var renderer = WebColorRenderer()
    /// The natively-drawable bars for the current inputs, one per interpolation space.
    @State private var bars: [InterpolationBar] = []

    /// The CSS interpolation spaces used for the mix/gradient rows, perceptual-first.
    private static let interpolationSpaces = ["oklch", "oklab", "lch", "lab", "hsl", "hwb", "srgb", "srgb-linear", "xyz"]
    /// Stops sampled per gradient bar — enough for a smooth curve through the perceptual path.
    private static let gradientSampleCount = 24

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                HStack(spacing: 16) {
                    ColorPicker("First Color", selection: $firstColor, supportsOpacity: false)
                    if mode == .mix {
                        VStack(spacing: 6) {
                            HStack {
                                Text("Mix")
                                Spacer()
                                Text("\(percent)% / \(100 - percent)%")
                                    .monospacedDigit()
                                    .foregroundStyle(.secondary)
                            }
                            Slider(value: $mix, in: 0...100)
                                .tint(.clear)
                        }
                    } else {
                        Spacer()
                    }
                    ColorPicker("Second Color", selection: $secondColor, supportsOpacity: false)
                }
                .labelsHidden()

                if let metrics, mode == .stats {
                    MetricsView(first: firstColor, second: secondColor, deltaE: metrics.deltaE, contrast: metrics.contrast)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    interpolationView
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                }
            }
            .padding()
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
        .frame(minWidth: 640, minHeight: 820)
        #else
        .presentationSizing(.page)
        #endif
    }

    private var percent: Int { Int(mix.rounded()) }

    /// Perceptual difference (CIEDE2000) and WCAG relative-luminance contrast between the two colors.
    private var metrics: (deltaE: Double, contrast: Double)? {
        guard let p1 = P3(SystemColor(firstColor)), let p2 = P3(SystemColor(secondColor)) else { return nil }
        let (lab1, y1) = ColorMetrics.labAndLuminance(p1)
        let (lab2, y2) = ColorMetrics.labAndLuminance(p2)
        let deltaE = ColorMetrics.deltaE2000(lab1, lab2)
        let contrast = ColorMetrics.wcagContrast(y1, y2)
        return (deltaE, contrast)
    }

    /// A picked color as a CSS `color(display-p3 ...)` literal, preserving wide-gamut values.
    private func cssColor(_ color: Color) -> String {
        guard let p3 = P3(SystemColor(color)) else { return "black" }
        func channel(_ value: Double) -> String { String(format: "%.4f", max(0, min(1, value))) }
        return "color(display-p3 \(channel(p3.r)) \(channel(p3.g)) \(channel(p3.b)))"
    }

    /// Natively-drawn interpolation rows: a monospaced space label beside a swatch or gradient bar.
    private var interpolationView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(heading)
                .font(.caption.weight(.semibold))
                .textCase(.uppercase)
                .foregroundStyle(.secondary)
                .padding(.bottom, 4)
            ForEach(bars) { bar in
                HStack(spacing: 12) {
                    Text(bar.space)
                        .font(.system(.footnote, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .frame(width: 74, alignment: .leading)
                    barShape(bar.colors)
                }
            }
        }
    }

    /// A single swatch (mix mode) or a left-to-right gradient (gradient mode) through the sampled stops.
    private func barShape(_ colors: [Color]) -> some View {
        let shape = RoundedRectangle(cornerRadius: 8)
        return Group {
            if colors.count == 1 {
                shape.fill(colors[0])
            } else {
                shape.fill(LinearGradient(colors: colors, startPoint: .leading, endPoint: .trailing))
            }
        }
        .frame(height: 34)
        .overlay(shape.strokeBorder(.primary.opacity(0.12)))
    }

    private var heading: String {
        switch mode {
        case .stats: ""
        case .mix: "color-mix() · \(percent)% / \(100 - percent)% by interpolation space"
        case .gradient: "Gradients by interpolation space"
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

        let resolved = await renderer.resolve(requests)
        guard resolved.count == requests.count else { return }

        bars = Self.interpolationSpaces.enumerated().map { index, space in
            let stops = resolved[(index * perBar)..<((index + 1) * perBar)]
            return InterpolationBar(space: space, colors: stops.map { Color(.displayP3, red: $0.r, green: $0.g, blue: $0.b) })
        }
    }
}

/// Native readout of the perceptual difference (ΔE₀₀) and WCAG contrast between the duo's two colors.
private struct MetricsView: View {

    let first: Color
    let second: Color
    let deltaE: Double
    let contrast: Double

    var body: some View {
        VStack(spacing: 16) {
            deltaECard
            contrastCard
        }
    }

    private var deltaECard: some View {
        card("Perceptual Difference", systemImage: "eye") {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(deltaE, format: .number.precision(.fractionLength(1)))
                    .font(.system(size: 64, weight: .bold, design: .rounded))
                    .monospacedDigit()
                VStack(alignment: .leading, spacing: 2) {
                    Text("ΔE₀₀")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(deltaEDescription)
                        .font(.title3.weight(.medium))
                }
            }
        }
    }

    private var contrastCard: some View {
        card("Contrast", systemImage: "circle.righthalf.filled", fill: true) {
            VStack(alignment: .leading, spacing: 20) {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(contrast, format: .number.precision(.fractionLength(2)))
                        .font(.system(size: 52, weight: .bold, design: .rounded))
                        .monospacedDigit()
                    Text(": 1")
                        .font(.title.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                HStack(spacing: 12) {
                    sample(text: first, on: second)
                    sample(text: second, on: first)
                }
                Spacer(minLength: 0)
                wcagGrid
            }
        }
    }

    /// A live preview of one color's text on the other as its background.
    private func sample(text textColor: Color, on background: Color) -> some View {
        Text("Aa")
            .font(.system(.title, design: .rounded).weight(.semibold))
            .foregroundStyle(textColor)
            .frame(maxWidth: .infinity)
            .frame(height: 64)
            .background(background, in: .rect(cornerRadius: 12))
    }

    private var wcagGrid: some View {
        Grid(horizontalSpacing: 20, verticalSpacing: 10) {
            GridRow {
                Color.clear.frame(height: 0).gridColumnAlignment(.leading)
                Text("AA").gridColumnAlignment(.center)
                Text("AAA").gridColumnAlignment(.center)
            }
            .font(.subheadline.weight(.bold))
            .foregroundStyle(.secondary)
            gridRow("Normal text", aa: contrast >= 4.5, aaa: contrast >= 7)
            gridRow("Large text", aa: contrast >= 3, aaa: contrast >= 4.5)
            GridRow {
                Text("UI & graphics").font(.body)
                badge(contrast >= 3)
                Text("—").font(.title3).foregroundStyle(.tertiary)
            }
        }
    }

    private func gridRow(_ label: String, aa: Bool, aaa: Bool) -> some View {
        GridRow {
            Text(label).font(.body)
            badge(aa)
            badge(aaa)
        }
    }

    /// A titled, filled container. `fill` lets the card expand to consume available height.
    private func card<Content: View>(_ title: String, systemImage: String, fill: Bool = false, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Label(title, systemImage: systemImage)
                .font(.headline)
                .foregroundStyle(.secondary)
            content()
        }
        .frame(maxWidth: .infinity, maxHeight: fill ? .infinity : nil, alignment: .topLeading)
        .padding(20)
        .background(.quaternary.opacity(0.4), in: .rect(cornerRadius: 16))
    }

    /// WCAG 2.1 pass/fail glyph for one threshold.
    private func badge(_ pass: Bool) -> some View {
        Image(systemName: pass ? "checkmark.circle.fill" : "xmark.circle.fill")
            .font(.title3)
            .foregroundStyle(pass ? Color.green : Color.red.opacity(0.8))
            .accessibilityLabel(pass ? "Pass" : "Fail")
    }

    /// A qualitative label for the ΔE₀₀ magnitude.
    private var deltaEDescription: String {
        switch deltaE {
        case ..<1: "Imperceptible"
        case ..<2: "Barely perceptible"
        case ..<10: "Perceptible"
        case ..<50: "Distinct"
        default: "Very distinct"
        }
    }
}

#Preview {
    DuoView()
}
