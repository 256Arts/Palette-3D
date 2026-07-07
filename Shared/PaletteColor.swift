//
//  PaletteColor.swift
//  Palette 3D
//
//  Created by 256 Arts Developer on 2022-08-15.
//

import ChromaKit
import SwiftUI
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

enum ColorSpace: String, CaseIterable, Identifiable, Codable {
    case lab, lch, okLab, okLch

    var id: Self { self }
    
    var name: String {
        switch self {
        case .lab: "Lab"
        case .lch: "Lch"
        case .okLab: "Oklab (Perceptual)"
        case .okLch: "Oklch (Perceptual)"
        }
    }

    /// The absolute lightness value at `lightnessFraction == 1`.
    var lightnessScale: Double {
        switch self {
        case .lab, .lch: 100
        case .okLab, .okLch: 1
        }
    }

    /// The absolute chroma value at `chromaFraction == 1`.
    var chromaScale: Double {
        switch self {
        case .lch: 150
        case .lab: 125
        case .okLab, .okLch: PaletteColor.maxChromaP3
        }
    }
}

struct PaletteColor: Equatable, Identifiable, Codable {

    var lightnessFraction: Double
    var chromaFraction: Double
    var hueAngle: Angle

    /// An optional user-facing name. `nil` when unnamed; optional so palettes saved before naming existed still decode.
    var name: String?

    var id: String {
        "\(lightnessFraction)-\(chromaFraction)-\(hueAngle)"
    }
    var normalizedA: Double { // [0, 1]
        cos(hueAngle.radians) * chromaFraction
    }
    var normalizedB: Double { // [0, 1]
        sin(hueAngle.radians) * chromaFraction
    }
    var visualizedLightnessLayerRadius: Double {
        sqrt(1 - pow(lightnessFraction * 2 - 1, 2))
    }
    var visualizedX: Double {
        normalizedA * visualizedLightnessLayerRadius
    }
    var visualizedY: Double {
        (lightnessFraction * 2) - 1
    }
    var visualizedZ: Double {
        normalizedB * visualizedLightnessLayerRadius
    }
    
    init(lightnessFraction: Double, chromaFraction: Double, hueAngle: Angle, name: String? = nil) {
        self.lightnessFraction = lightnessFraction
        self.chromaFraction = chromaFraction
        self.hueAngle = hueAngle
        self.name = name
    }
    
    init?(css: String) {
        guard let colorSpaceEndIndex = css.index(css.startIndex, offsetBy: 4, limitedBy: css.endIndex) else { return nil }
        
        guard let colorSpace: ColorSpace = switch css[css.startIndex ..< colorSpaceEndIndex] {
        case "lch(": .lch
        case "oklc": .okLch
        default: nil // Lab and Oklab not supported
        } else { return nil }
        
        guard let openParenIndex = css.firstIndex(of: "("), let closeParenIndex = css.firstIndex(of: ")") else { return nil }
        
        let numbers = css[css.index(after: openParenIndex) ..< closeParenIndex].components(separatedBy: .whitespaces).compactMap({ Double($0) })
        
        guard numbers.count == 3 else { return nil }

        // Only lch/oklch reach here; lab/oklab were rejected by the prefix guard above.
        self.init(
            lightnessFraction: numbers[0] / colorSpace.lightnessScale,
            chromaFraction: numbers[1] / colorSpace.chromaScale,
            hueAngle: .degrees(numbers[2]))
    }

    /// Creates a palette color from a displayable color (e.g. an imported `.clr` entry),
    /// mapped into the given color space's fraction model. Returns `nil` if the color has no RGB representation.
    init?(_ color: SystemColor, colorSpace: ColorSpace) {
        guard let p3 = P3(color) else { return nil }
        self.init(p3, colorSpace: colorSpace)
    }

    /// Creates a palette color from a display-P3 color, mapped into the given color space's fraction model.
    init(_ p3: P3, colorSpace: ColorSpace) {
        let l: Double, c: Double, h: Double
        switch colorSpace {
        case .lab, .lch:
            let lch = Lch(p3)
            (l, c, h) = (lch.l, lch.c, lch.h)
        case .okLab, .okLch:
            let oklch = Oklch(p3)
            (l, c, h) = (oklch.l, oklch.c, oklch.h)
        }
        self.init(
            lightnessFraction: l / colorSpace.lightnessScale,
            chromaFraction: c / colorSpace.chromaScale,
            hueAngle: .degrees(h))
    }

    private func absoluteColor(colorSpace: ColorSpace) -> XYZConvertable {
        let l = lightnessFraction * colorSpace.lightnessScale
        let scale = colorSpace.chromaScale
        return switch colorSpace {
        case .lch:
            Lch(l: l, c: chromaFraction * scale, h: hueAngle.degrees)
        case .lab:
            Lab(l: l, a: normalizedA * scale, b: normalizedB * scale)
        case .okLch:
            Oklch(l: l, c: chromaFraction * scale, h: hueAngle.degrees)
        case .okLab:
            Oklab(l: l, a: normalizedA * scale, b: normalizedB * scale)
        }
    }

    func color(colorSpace: ColorSpace) -> Color {
        Color(absoluteColor(colorSpace: colorSpace))
    }

    func systemColor(colorSpace: ColorSpace) -> SystemColor {
        SystemColor(absoluteColor(colorSpace: colorSpace))
    }

    /// This color realized as display-P3. Useful for converting between metrics or deriving a hex string.
    func p3(colorSpace: ColorSpace) -> P3 {
        absoluteColor(colorSpace: colorSpace).p3
    }

    /// An sRGB hex string (e.g. `#1A2B3C`), gamut-clamped from the color's realized value.
    func hexString(colorSpace: ColorSpace) -> String {
        let color = systemColor(colorSpace: colorSpace)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0
        #if canImport(AppKit)
        guard let srgb = color.usingColorSpace(.sRGB) else { return "—" }
        (r, g, b) = (srgb.redComponent, srgb.greenComponent, srgb.blueComponent)
        #else
        var a: CGFloat = 0
        color.getRed(&r, green: &g, blue: &b, alpha: &a)
        #endif
        func channel(_ value: CGFloat) -> Int { Int((max(0, min(1, value)) * 255).rounded()) }
        return String(format: "#%02X%02X%02X", channel(r), channel(g), channel(b))
    }
    
    func cssString(colorSpace: ColorSpace, convertedToP3: Bool) -> String {
        
        func round(_ number: Double) -> String {
            Self.cssDecimalFormatter.string(from: NSNumber(value: number))!
        }
        
        let absoluteColor = absoluteColor(colorSpace: colorSpace)
        
        if convertedToP3 {
            let p3 = absoluteColor.p3
            return "color(display-p3 \(round(p3.r)) \(round(p3.g)) \(round(p3.b)))"
        } else {
            return switch absoluteColor {
            case let lch as Lch:
                "lch(\(round(lch.l)) \(round(lch.c)) \(round(lch.h)))"
            case let lab as Lab:
                "lab(\(round(lab.l)) \(round(lab.a)) \(round(lab.b)))"
            case let oklch as Oklch:
                "oklch(\(round(oklch.l)) \(round(oklch.c)) \(round(oklch.h)))"
            case let oklab as Oklab:
                "oklab(\(round(oklab.l)) \(round(oklab.a)) \(round(oklab.b)))"
            default:
                ""
            }
        }
    }
    
    /// The palette rendered as newline-separated CSS colors. Trailing newlines fix layout when the inspector is collapsed.
    static func cssText(_ colors: [PaletteColor], colorSpace: ColorSpace, convertedToP3: Bool) -> String {
        colors.map { $0.cssString(colorSpace: colorSpace, convertedToP3: convertedToP3) }.joined(separator: "\n") + "\n\n"
    }

    static let maxChromaP3 = 0.4
    
    static let cssDecimalFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 5
        return formatter
    }()

}
