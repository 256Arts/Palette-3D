import SwiftUI

@Observable
final class PaletteGenerator {

    /// The resolution-independent knobs that fully describe a "perfect" palette.
    struct Parameters: Codable, Equatable {

        /// Color space
        var colorSpace: ColorSpace = .okLch

        /// Number of levels of lightness
        var lightnessLevels: Int = 5

        /// Rotates each lightness layer
        var lightnessTwist = false

        /// Number of levels of chroma
        var chromaLevels: Int = 3

        /// Whether the 1st chroma level is just a single grayscale color
        var chromaStartsAtZero = true

        /// Chroma multiplier (0.5 = all colors have half the chroma)
        var chromaMultiplier = 1.0

        /// Number of different hues at the largest chroma level
        var maxHueSegments: Int = 12

        /// Whether each hue should be represented in all lightness levels
        var continuousHues = true

        /// Rotates each chroma ring
        var chromaTwist = false

        /// Rotate the entire palette to pick different hues
        var startingHueOffset: Angle = .zero
    }

    var parameters: Parameters

    init(_ parameters: Parameters = Parameters()) {
        self.parameters = parameters
    }

    func generate() -> [PaletteColor] {
        var colors: [PaletteColor] = []
        let lightnessRange = parameters.lightnessLevels == 1 ? [0.5] : Array(stride(from: 0.0, through: 1.0, by: 1.0 / Double(parameters.lightnessLevels-1)))
        let maxLightnessLayerRadius = 1.0
        let maxLightnessLayerCircumference = 2 * .pi * maxLightnessLayerRadius
        let targetCircumferencePerHue = maxLightnessLayerCircumference / Double(parameters.maxHueSegments)

        for lightness in lightnessRange {
            let lightnessLayerRadius = sqrt(1 - pow(lightness * 2 - 1, 2))

            switch lightness {
            case 0, 1:
                colors.append(PaletteColor(lightnessFraction: lightness, chromaFraction: 0, hueAngle: .zero))
            default:
                let chromaStep = parameters.chromaStartsAtZero ? 1 / Double(parameters.chromaLevels-1) : 1 / (Double(parameters.chromaLevels)-0.5)
                let chromaStart = parameters.chromaStartsAtZero ? 0 : chromaStep / 2

                for chroma in stride(from: 1.0, through: chromaStart, by: -chromaStep) { // Start at 1.0 to ensure single chroma level will be 1.0
                    if chroma == 0 {
                        colors.append(PaletteColor(lightnessFraction: lightness, chromaFraction: chroma, hueAngle: .zero))
                    } else {
                        let chromaLayerRadius = chroma * lightnessLayerRadius
                        let chromaLayerCircumference = 2 * .pi * chromaLayerRadius
                        let hueSegments = Int(round(parameters.continuousHues ? Double(parameters.maxHueSegments) * chroma : chromaLayerCircumference / targetCircumferencePerHue))
                        let hueStart = parameters.startingHueOffset.degrees + (parameters.chromaTwist ? (chroma * 360) / Double(hueSegments) : 0) + (parameters.lightnessTwist ? (lightness * 360) / Double(hueSegments) : 0)
                        let hueEnd = hueStart + 360
                        let hueStep = 360 / Double(hueSegments)

                        for hue in stride(from: hueStart, to: hueEnd, by: hueStep) {
                            colors.append(PaletteColor(lightnessFraction: lightness, chromaFraction: chroma * parameters.chromaMultiplier, hueAngle: .degrees(hue)))
                        }
                    }
                }
            }
        }

        return colors
    }

}
