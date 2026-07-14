import PaletteKit
import SwiftUI

struct PaletteAnalysisView: View {

    let colors: [PaletteColor]
    let colorSpace: ColorSpace

    @Environment(\.dismiss) private var dismiss

    private var analysis: PaletteAnalysis { PaletteAnalysis(colors: colors, colorSpace: colorSpace) }

    var body: some View {
        NavigationStack {
            Group {
                if colors.count < 2 {
                    ContentUnavailableView("Not Enough Colors",
                                           systemImage: "chart.bar.xaxis",
                                           description: Text("Add at least two colors to analyze how they relate."))
                } else {
                    analysisList
                }
            }
            .navigationTitle("Analysis")
            #if !os(macOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .navigation) {
                    Button("Close", systemImage: "xmark", role: .close) { dismiss() }
                }
            }
        }
        #if os(macOS)
        .frame(minWidth: 460, minHeight: 620)
        #else
        .presentationDetents([.medium, .large])
        #endif
    }

    private var analysisList: some View {
        List {
            Section {
                stats(analysis.deltaE, format: .deltaE)
                if let pair = analysis.mostSimilarPair {
                    pairRow("Most Similar", pair, value: pair.deltaE, format: .deltaE)
                }
                if let pair = analysis.mostDifferentPair {
                    pairRow("Most Different", pair, value: pair.deltaE, format: .deltaE)
                }
            } header: {
                Text("Perceptual Difference · ΔE₀₀")
            } footer: {
                Text("CIEDE2000 across all \(analysis.pairCount) color pairs. ΔE below ~2 is barely perceptible; above ~10 is distinct.")
            }

            Section {
                stats(analysis.contrast, format: .contrast)
                LabeledContent("AA Text Pairs · ≥4.5", value: "\(analysis.contrastPassing(4.5)) of \(analysis.pairCount)")
                LabeledContent("UI / Large Pairs · ≥3", value: "\(analysis.contrastPassing(3)) of \(analysis.pairCount)")
                if let pair = analysis.lowestContrastPair {
                    pairRow("Lowest Contrast", pair, value: pair.contrast, format: .contrast)
                }
            } header: {
                Text("Contrast · WCAG 2.1")
            } footer: {
                Text("Ratios from 1:1 to 21:1. WCAG requires 4.5:1 for normal text, 3:1 for large text and UI.")
            }

            Section("Lightness & Chroma") {
                LabeledContent("Lightness Range", value: "\(number(analysis.minLightness, 0))–\(number(analysis.maxLightness, 0)) L*")
                LabeledContent("Mean Lightness", value: "\(number(analysis.meanLightness, 0)) L*")
                LabeledContent("Mean Chroma", value: number(analysis.meanChroma, 0))
                LabeledContent("Max Chroma", value: number(analysis.maxChroma, 0))
            }

            Section {
                LabeledContent("Hue Coverage", value: "\(number(analysis.hueCoverage, 0))°")
                LabeledContent("Largest Hue Gap", value: "\(number(analysis.largestHueGap, 0))°")
            } header: {
                Text("Hue")
            } footer: {
                Text("Coverage is the arc of the color wheel spanned by the palette; a large gap means an unused hue region.")
            }

            if analysis.outsideSRGB > 0 || analysis.outsideP3 > 0 {
                Section("Gamut") {
                    if analysis.outsideSRGB > 0 {
                        LabeledContent("Outside sRGB", value: "\(analysis.outsideSRGB) of \(colors.count)")
                    }
                    if analysis.outsideP3 > 0 {
                        LabeledContent("Outside Display P3", value: "\(analysis.outsideP3) of \(colors.count)")
                    }
                }
            }
        }
    }

    // MARK: Rows

    private enum StatFormat {
        case deltaE, contrast
        var fractionDigits: Int { self == .contrast ? 2 : 1 }
        func string(_ value: Double) -> String {
            self == .contrast ? "\(value.formatted(.number.precision(.fractionLength(2)))):1"
                              : value.formatted(.number.precision(.fractionLength(1)))
        }
    }

    @ViewBuilder
    private func stats(_ stats: DescriptiveStats?, format: StatFormat) -> some View {
        if let stats {
            LabeledContent("Mean", value: format.string(stats.mean))
            LabeledContent("Median", value: format.string(stats.median))
            LabeledContent("Mode", value: format.string(stats.mode))
            LabeledContent("Minimum", value: format.string(stats.min))
            LabeledContent("Maximum", value: format.string(stats.max))
            LabeledContent("Std. Deviation", value: format.string(stats.standardDeviation))
        }
    }

    private func pairRow(_ title: LocalizedStringKey, _ pair: PaletteAnalysis.Pair, value: Double, format: StatFormat) -> some View {
        LabeledContent {
            HStack(spacing: 6) {
                swatch(pair.first)
                swatch(pair.second)
                Text(format.string(value))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
        } label: {
            Text(title)
        }
    }

    private func swatch(_ index: Int) -> some View {
        RoundedRectangle(cornerRadius: 4)
            .fill(colors[index].color(colorSpace: colorSpace))
            .frame(width: 20, height: 20)
            .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(.separator))
    }

    private func number(_ value: Double, _ fractionDigits: Int) -> String {
        value.formatted(.number.precision(.fractionLength(fractionDigits)))
    }
}

/// All pairwise and per-color metrics for a palette, computed once from realized CIELab values.
struct PaletteAnalysis {

    /// One color pair, with the metrics that selected it.
    struct Pair { let first, second: Int; let deltaE, contrast: Double }

    let pairCount: Int
    let deltaE: DescriptiveStats?
    let contrast: DescriptiveStats?
    let mostSimilarPair: Pair?
    let mostDifferentPair: Pair?
    let lowestContrastPair: Pair?

    let minLightness, maxLightness, meanLightness: Double
    let meanChroma, maxChroma: Double
    let hueCoverage, largestHueGap: Double
    let outsideSRGB, outsideP3: Int

    private let contrasts: [Double]

    /// Number of color pairs whose WCAG contrast ratio meets `threshold`.
    func contrastPassing(_ threshold: Double) -> Int {
        contrasts.count { $0 >= threshold }
    }

    init(colors: [PaletteColor], colorSpace: ColorSpace) {
        // Convert each color once; the pairwise loop below is O(n²) and must not re-convert.
        let samples = colors.map { ColorMetrics.sample($0, colorSpace: colorSpace) }
        let lightnesses = samples.map(\.lightness)
        let chromas = samples.map(\.chroma)
        let hues = samples.map(\.hueDegrees)

        outsideSRGB = colors.count { $0.isOutsideSRGBGamut(colorSpace: colorSpace) }
        outsideP3 = colors.count { $0.isOutsideP3Gamut(colorSpace: colorSpace) }

        minLightness = lightnesses.min() ?? 0
        maxLightness = lightnesses.max() ?? 0
        meanLightness = lightnesses.isEmpty ? 0 : lightnesses.reduce(0, +) / Double(lightnesses.count)
        meanChroma = chromas.isEmpty ? 0 : chromas.reduce(0, +) / Double(chromas.count)
        maxChroma = chromas.max() ?? 0

        (hueCoverage, largestHueGap) = Self.hueSpread(hues)

        var deltaEs: [Double] = []
        var contrasts: [Double] = []
        var similar: Pair?
        var different: Pair?
        var lowestContrast: Pair?
        for i in samples.indices {
            for j in (i + 1)..<samples.count {
                let dE = ColorMetrics.deltaE2000(samples[i], samples[j])
                let contrast = ColorMetrics.wcagContrast(samples[i], samples[j])
                deltaEs.append(dE)
                contrasts.append(contrast)
                let pair = Pair(first: i, second: j, deltaE: dE, contrast: contrast)
                if similar == nil || dE < similar!.deltaE { similar = pair }
                if different == nil || dE > different!.deltaE { different = pair }
                if lowestContrast == nil || contrast < lowestContrast!.contrast { lowestContrast = pair }
            }
        }

        pairCount = deltaEs.count
        deltaE = DescriptiveStats(deltaEs)
        contrast = DescriptiveStats(contrasts, modeBin: 0.5)
        mostSimilarPair = similar
        mostDifferentPair = different
        lowestContrastPair = lowestContrast
        self.contrasts = contrasts
    }

    /// The arc of the hue wheel the palette spans, and the largest unused gap, in degrees.
    private static func hueSpread(_ hues: [Double]) -> (coverage: Double, largestGap: Double) {
        guard hues.count > 1 else { return (0, 360) }
        let sorted = hues.sorted()
        var largestGap = (sorted.first! + 360) - sorted.last!    // wrap-around gap
        for i in 1..<sorted.count {
            largestGap = Swift.max(largestGap, sorted[i] - sorted[i - 1])
        }
        return (360 - largestGap, largestGap)
    }
}
