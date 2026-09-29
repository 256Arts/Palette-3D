import PaletteKit
import SwiftUI

struct PaletteAnalysisView: View {

    let colors: [PaletteColor]
    let colorSpace: ColorSpace

    /// The inputs the analysis is derived from, as one value to key the recompute on.
    private struct Inputs: Equatable {
        let colors: [PaletteColor]
        let colorSpace: ColorSpace
    }

    /// Held rather than computed: this view lives in the editor's inspector, alongside the controls that
    /// edit the palette, and the pairwise analysis is O(n²) — it must not run on every body evaluation.
    @State private var analysis: PaletteAnalysis?

    var body: some View {
        Group {
            if colors.count < 2 {
                ContentUnavailableView("Not Enough Colors",
                                       systemImage: "chart.bar.xaxis",
                                       description: Text("Add at least two colors to analyze how they relate."))
            } else if let analysis {
                analysisList(analysis)
            } else {
                // Not decoration: without it this branch is empty content, and `.task` doesn't run on
                // empty content — the analysis would never be computed, leaving the panel blank forever.
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .task(id: Inputs(colors: colors, colorSpace: colorSpace)) {
            analysis = PaletteAnalysis(colors: colors, colorSpace: colorSpace)
        }
    }

    private func analysisList(_ analysis: PaletteAnalysis) -> some View {
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

            Section {
                ForEach(analysis.visionReports, id: \.vision) { report in
                    visionRow(report)
                }
            } header: {
                Text("Color Vision")
            } footer: {
                Text("The closest pair as seen with each color vision deficiency. Pairs that drop below ΔE \(number(PaletteAnalysis.confusableDeltaE, 0)) only under the simulation may be confused.")
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
            pairSwatches(colors[pair.first], colors[pair.second], value: format.string(value))
        } label: {
            Text(title)
        }
    }

    /// The closest pair under one deficiency, drawn as that viewer sees it.
    private func visionRow(_ report: PaletteAnalysis.VisionReport) -> some View {
        LabeledContent {
            pairSwatches(report.vision.simulate(colors[report.closestPair.first], colorSpace: colorSpace),
                         report.vision.simulate(colors[report.closestPair.second], colorSpace: colorSpace),
                         value: StatFormat.deltaE.string(report.closestPair.deltaE))
        } label: {
            Text(report.vision.name)
            if report.confusedPairs > 0 {
                Label("^[\(report.confusedPairs) pair](inflect: true) confused", systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
            } else {
                Text(report.vision.summary)
            }
        }
    }

    private func pairSwatches(_ first: PaletteColor, _ second: PaletteColor, value: String) -> some View {
        HStack(spacing: 6) {
            swatch(first)
            swatch(second)
            Text(value)
                .monospacedDigit()
                .foregroundStyle(.secondary)
        }
    }

    private func swatch(_ color: PaletteColor) -> some View {
        RoundedRectangle(cornerRadius: 4)
            .fill(color.color(colorSpace: colorSpace))
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

    /// How the palette holds up under one color vision deficiency.
    struct VisionReport {
        let vision: ColorVision
        /// The pair with the smallest simulated ΔE₀₀.
        let closestPair: Pair
        /// Pairs distinct to normal vision that fall below `confusableDeltaE` under the simulation.
        let confusedPairs: Int
    }

    /// The ΔE₀₀ below which two swatches are hard to tell apart at a glance.
    static let confusableDeltaE = 5.0

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
    let visionReports: [VisionReport]

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

        visionReports = ColorVision.deficiencies.compactMap { vision in
            let simulated = colors.map { ColorMetrics.sample(vision.simulate($0, colorSpace: colorSpace), colorSpace: colorSpace) }
            var closest: Pair?
            var confused = 0
            var pairIndex = 0    // walks `deltaEs` in the same order as the loop above
            for i in simulated.indices {
                for j in (i + 1)..<simulated.count {
                    let dE = ColorMetrics.deltaE2000(simulated[i], simulated[j])
                    if dE < Self.confusableDeltaE && deltaEs[pairIndex] >= Self.confusableDeltaE { confused += 1 }
                    if closest == nil || dE < closest!.deltaE {
                        closest = Pair(first: i, second: j, deltaE: dE, contrast: ColorMetrics.wcagContrast(simulated[i], simulated[j]))
                    }
                    pairIndex += 1
                }
            }
            return closest.map { VisionReport(vision: vision, closestPair: $0, confusedPairs: confused) }
        }
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
