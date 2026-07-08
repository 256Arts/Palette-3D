//
//  DuoView.swift
//  Palette 3D
//
//  Pick two colors and a mix amount, then compare how CSS blends them: a `color-mix()` swatch
//  followed by a gradient between the two colors in each interpolation color space.
//  Rendered via WebKit because SwiftUI has no `color-mix()` or per-space gradient interpolation.
//

import SwiftUI
import ChromaKit

struct DuoView: View {

    /// Whether the page shows single-swatch `color-mix()` results or full gradients between the two colors.
    private enum Mode: String, CaseIterable, Identifiable {
        case mix = "Mix"
        case gradient = "Gradient"
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

                HTMLView(html: html)
                    .clipShape(.rect(cornerRadius: 16))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
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
            case .mix:
                "color-mix(in \(space), \(first) \(percent)%, \(second))"
            case .gradient:
                "linear-gradient(to right in \(space), \(first), \(second))"
            }
            return "<div class=\"row\"><span class=\"label\">\(space)</span><div class=\"bar\" style=\"background:\(background)\"></div></div>"
        }.joined()
        let heading = switch mode {
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

#Preview {
    DuoView()
}
