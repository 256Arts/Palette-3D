import CoreGraphics
import Foundation
import PaletteKit

/// A way of seeing color, so a palette can be previewed — and analyzed — the way a viewer with a color
/// vision deficiency sees it.
///
/// The dichromacies use Machado, Oliveira & Fernandes (2009) at full severity, which is defined over
/// linear RGB; achromatopsia keeps only relative luminance. Each simulated color is mapped back into a
/// `PaletteColor`, so the rest of the app (drawing, `ColorMetrics`) needs no second code path for it.
enum ColorVision: String, CaseIterable, Identifiable {
    case normal, protanopia, deuteranopia, tritanopia, achromatopsia

    var id: Self { self }

    /// Every deficiency, for analyses that report on each one.
    static let deficiencies = allCases.filter { $0 != .normal }

    var name: LocalizedStringResource {
        switch self {
        case .normal: "Normal Vision"
        case .protanopia: "Protanopia"
        case .deuteranopia: "Deuteranopia"
        case .tritanopia: "Tritanopia"
        case .achromatopsia: "Achromatopsia"
        }
    }

    /// Plain-language peer of `name` — the clinical terms mean little to most palette designers.
    var summary: LocalizedStringResource {
        switch self {
        case .normal: "Trichromatic"
        case .protanopia: "No red cones"
        case .deuteranopia: "No green cones"
        case .tritanopia: "No blue cones"
        case .achromatopsia: "No color"
        }
    }

    /// The linear-RGB transform, row-major.
    private var matrix: [[Double]] {
        switch self {
        case .normal:
            [[1, 0, 0], [0, 1, 0], [0, 0, 1]]
        case .protanopia:
            [[0.152286, 1.052583, -0.204868],
             [0.114503, 0.786281, 0.099216],
             [-0.003882, -0.048116, 1.051998]]
        case .deuteranopia:
            [[0.367322, 0.860646, -0.227968],
             [0.280085, 0.672501, 0.047413],
             [-0.011820, 0.042940, 0.968881]]
        case .tritanopia:
            [[1.255528, -0.076749, -0.178779],
             [-0.078411, 0.930809, 0.147602],
             [0.004733, 0.691367, 0.303900]]
        case .achromatopsia:
            // Every channel becomes the Rec. 709 relative luminance.
            Array(repeating: [0.2126, 0.7152, 0.0722], count: 3)
        }
    }

    private static let linearSRGB = CGColorSpace(name: CGColorSpace.extendedLinearSRGB)!

    /// `color` as this vision sees it. The result is clamped to sRGB — the gamut the simulation models —
    /// and keeps the original's name.
    func simulate(_ color: PaletteColor, colorSpace: ColorSpace) -> PaletteColor {
        guard self != .normal,
              let rgb = color.systemColor(colorSpace: colorSpace).cgColor
                .converted(to: Self.linearSRGB, intent: .defaultIntent, options: nil)?.components,
              rgb.count >= 3 else { return color }

        let simulated: [CGFloat] = matrix.map { row in
            CGFloat(min(max(row[0] * rgb[0] + row[1] * rgb[1] + row[2] * rgb[2], 0), 1))
        }
        guard let cgColor = CGColor(colorSpace: Self.linearSRGB, components: simulated + [1]) else { return color }
        // `UIColor(cgColor:)` is non-failable where `NSColor(cgColor:)` isn't; the annotation covers both.
        let systemColor: SystemColor? = SystemColor(cgColor: cgColor)
        guard let systemColor, var result = PaletteColor(systemColor, colorSpace: colorSpace) else { return color }
        result.name = color.name
        return result
    }
}
