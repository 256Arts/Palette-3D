//
//  DuoView.swift
//  Palette 3D
//
//  Pick two colors and a mix amount, then compare how CSS blends them: a `color-mix()` swatch
//  followed by a gradient between the two colors in each interpolation color space.
//  Rendered via WebKit because SwiftUI has no `color-mix()` or per-space gradient interpolation.
//

import SwiftUI
import Foundation
import ChromaKit

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

    /// The CSS interpolation spaces used for the mix/gradient rows, perceptual-first.
    private static let interpolationSpaces = ["oklch", "oklab", "lch", "lab", "hsl", "hwb", "srgb", "srgb-linear", "xyz"]

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
                    HTMLView(html: html)
                        .clipShape(.rect(cornerRadius: 16))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .padding()
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

    private var html: String {
        let first = cssColor(firstColor)
        let second = cssColor(secondColor)
        let rows = Self.interpolationSpaces.map { space in
            let background = switch mode {
            case .stats:
                ""
            case .mix:
                "color-mix(in \(space), \(first) \(percent)%, \(second))"
            case .gradient:
                "linear-gradient(to right in \(space), \(first), \(second))"
            }
            return "<div class=\"row\"><span class=\"label\">\(space)</span><div class=\"bar\" style=\"background:\(background)\"></div></div>"
        }.joined()
        let heading = switch mode {
        case .stats: ""
        case .mix: "color-mix() · \(percent)% / \(100 - percent)% by interpolation space"
        case .gradient: "Gradients by interpolation space"
        }
        return """
        <!doctype html>
        <html>
        <head>
        <meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1">
        <style>
        :root { color-scheme: light dark; }
        * { box-sizing: border-box; }
        body { margin: 0; padding: 16px; background: canvas; color: canvastext;
               font: 13px/1.3 -apple-system, system-ui, sans-serif; }
        h2 { font-size: 11px; font-weight: 600; letter-spacing: .06em; text-transform: uppercase;
             color: color-mix(in srgb, canvastext, transparent 50%); margin: 0 0 8px 0; }
        .row { display: flex; align-items: center; gap: 12px; margin-bottom: 8px; }
        .label { flex: 0 0 74px; font-family: ui-monospace, monospace;
                 color: color-mix(in srgb, canvastext, transparent 35%); }
        .bar { flex: 1; height: 34px; border-radius: 8px;
               box-shadow: inset 0 0 0 1px color-mix(in srgb, canvastext, transparent 88%); }
        </style>
        </head>
        <body>
        <h2>\(heading)</h2>
        \(rows)
        </body>
        </html>
        """
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
