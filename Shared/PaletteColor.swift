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

/// A user-selectable way to express a color as text, spanning the CSS color-space notations plus
/// sRGB-derived RGB/Hex/HSL/HSB. Used both for the color detail rows and for choosing an export format.
enum ColorRepresentation: String, CaseIterable, Identifiable {
    case oklch, oklab, lch, lab, displayP3, rgb, hex, hsl, hsb

    var id: Self { self }

    var name: String {
        switch self {
        case .oklch: "Oklch"
        case .oklab: "Oklab"
        case .lch: "Lch"
        case .lab: "Lab"
        case .displayP3: "Display P3"
        case .rgb: "RGB"
        case .hex: "Hex"
        case .hsl: "HSL"
        case .hsb: "HSB"
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

    /// The realized color's raw sRGB channels (unclamped). Values outside [0, 1] are outside the sRGB gamut.
    private func rawSRGBComponents(colorSpace: ColorSpace) -> (r: CGFloat, g: CGFloat, b: CGFloat) {
        let color = systemColor(colorSpace: colorSpace)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0
        #if canImport(AppKit)
        if let srgb = color.usingColorSpace(.sRGB) {
            (r, g, b) = (srgb.redComponent, srgb.greenComponent, srgb.blueComponent)
        }
        #else
        var a: CGFloat = 0
        color.getRed(&r, green: &g, blue: &b, alpha: &a)
        #endif
        return (r, g, b)
    }

    /// The color's sRGB channels as 8-bit integers (0–255), gamut-clamped from the realized value.
    private func srgb8Bit(colorSpace: ColorSpace) -> (r: Int, g: Int, b: Int) {
        let (r, g, b) = rawSRGBComponents(colorSpace: colorSpace)
        func channel(_ value: CGFloat) -> Int { Int((max(0, min(1, value)) * 255).rounded()) }
        return (channel(r), channel(g), channel(b))
    }

    /// Whether the realized color lies outside the sRGB gamut, so its RGB/Hex values are clamped.
    func isOutsideSRGBGamut(colorSpace: ColorSpace) -> Bool {
        let (r, g, b) = rawSRGBComponents(colorSpace: colorSpace)
        let tolerance: CGFloat = 0.5 / 255 // Ignore overflow too small to change a channel.
        return [r, g, b].contains { $0 < -tolerance || $0 > 1 + tolerance }
    }

    /// Whether the realized color lies outside the Display P3 gamut.
    func isOutsideP3Gamut(colorSpace: ColorSpace) -> Bool {
        let p3 = p3(colorSpace: colorSpace)
        let tolerance = 0.001
        return [p3.r, p3.g, p3.b].contains { $0 < -tolerance || $0 > 1 + tolerance }
    }

    /// An sRGB hex string (e.g. `#1A2B3C`), gamut-clamped from the color's realized value.
    func hexString(colorSpace: ColorSpace) -> String {
        let (r, g, b) = srgb8Bit(colorSpace: colorSpace)
        return String(format: "#%02X%02X%02X", r, g, b)
    }

    /// An sRGB CSS color (e.g. `rgb(26 43 60)`), gamut-clamped from the color's realized value.
    func rgbString(colorSpace: ColorSpace) -> String {
        let (r, g, b) = srgb8Bit(colorSpace: colorSpace)
        return "rgb(\(r) \(g) \(b))"
    }

    /// The realized color's sRGB channels clamped to [0, 1].
    private func clampedSRGBComponents(colorSpace: ColorSpace) -> (r: Double, g: Double, b: Double) {
        let (r, g, b) = rawSRGBComponents(colorSpace: colorSpace)
        func clamp(_ value: CGFloat) -> Double { Double(max(0, min(1, value))) }
        return (clamp(r), clamp(g), clamp(b))
    }

    /// Hue angle in degrees [0, 360) for the given clamped sRGB channels. Shared by HSL and HSB.
    private func hueDegrees(_ r: Double, _ g: Double, _ b: Double) -> Int {
        let maxV = max(r, g, b), delta = maxV - min(r, g, b)
        guard delta > 0 else { return 0 }
        let hue: Double
        if maxV == r {
            hue = (g - b) / delta
        } else if maxV == g {
            hue = (b - r) / delta + 2
        } else {
            hue = (r - g) / delta + 4
        }
        let degrees = (hue * 60).truncatingRemainder(dividingBy: 360)
        return Int((degrees < 0 ? degrees + 360 : degrees).rounded())
    }

    private func percent(_ value: Double) -> String {
        "\(Int((value * 100).rounded()))%"
    }

    /// The realized color as CSS `hsl()`, derived from clamped sRGB.
    func hslString(colorSpace: ColorSpace) -> String {
        let (r, g, b) = clampedSRGBComponents(colorSpace: colorSpace)
        let maxV = max(r, g, b), minV = min(r, g, b), delta = maxV - minV
        let l = (maxV + minV) / 2
        let s = delta == 0 ? 0 : delta / (1 - abs(2 * l - 1))
        return "hsl(\(hueDegrees(r, g, b)) \(percent(s)) \(percent(l)))"
    }

    /// The realized color as `hsb()` (a.k.a. HSV), derived from clamped sRGB.
    func hsbString(colorSpace: ColorSpace) -> String {
        let (r, g, b) = clampedSRGBComponents(colorSpace: colorSpace)
        let maxV = max(r, g, b), delta = maxV - min(r, g, b)
        let s = maxV == 0 ? 0 : delta / maxV
        return "hsb(\(hueDegrees(r, g, b)) \(percent(s)) \(percent(maxV)))"
    }

    /// This color expressed in the given representation. The CSS color-space notations are re-derived from
    /// the realized P3 value, so each is a true conversion independent of the palette's own color space.
    func string(_ representation: ColorRepresentation, colorSpace: ColorSpace) -> String {
        switch representation {
        case .oklch: converted(.okLch, from: colorSpace)
        case .oklab: converted(.okLab, from: colorSpace)
        case .lch: converted(.lch, from: colorSpace)
        case .lab: converted(.lab, from: colorSpace)
        case .displayP3: cssString(colorSpace: colorSpace, convertedToP3: true)
        case .rgb: rgbString(colorSpace: colorSpace)
        case .hex: hexString(colorSpace: colorSpace)
        case .hsl: hslString(colorSpace: colorSpace)
        case .hsb: hsbString(colorSpace: colorSpace)
        }
    }

    private func converted(_ target: ColorSpace, from colorSpace: ColorSpace) -> String {
        PaletteColor(p3(colorSpace: colorSpace), colorSpace: target).cssString(colorSpace: target, convertedToP3: false)
    }

    /// A note about clamping for this representation, or `nil` if it can represent the color exactly.
    func gamutWarning(_ representation: ColorRepresentation, colorSpace: ColorSpace) -> String? {
        switch representation {
        case .displayP3:
            isOutsideP3Gamut(colorSpace: colorSpace) ? "Outside the Display P3 gamut." : nil
        case .rgb, .hex, .hsl, .hsb:
            isOutsideSRGBGamut(colorSpace: colorSpace) ? "Outside the sRGB gamut. The value shown is clamped." : nil
        case .oklch, .oklab, .lch, .lab:
            nil
        }
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

    /// The palette rendered as newline-separated colors in the given representation, for export.
    static func text(_ colors: [PaletteColor], representation: ColorRepresentation, colorSpace: ColorSpace) -> String {
        colors.map { $0.string(representation, colorSpace: colorSpace) }.joined(separator: "\n")
    }

    static let maxChromaP3 = 0.4
    
    static let cssDecimalFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 5
        return formatter
    }()

}
