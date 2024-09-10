//
//  PaletteColor.swift
//  Palette 3D
//
//  Created by 256 Arts Developer on 2022-08-15.
//

import ChromaKit
import SwiftUI

enum ColorSpace: CaseIterable, Identifiable {
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
}

struct PaletteColor: Equatable, Identifiable {

    var lightnessFraction: Double
    var chromaFraction: Double
    var hueAngle: Angle

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
    var visualizedX: Float {
        Float(normalizedA * visualizedLightnessLayerRadius)
    }
    var visualizedY: Float {
        Float(lightnessFraction * 2 - 1)
    }
    var visualizedZ: Float {
        Float(normalizedB * visualizedLightnessLayerRadius)
    }
    
    init(lightnessFraction: Double, chromaFraction: Double, hueAngle: Angle) {
        self.lightnessFraction = lightnessFraction
        self.chromaFraction = chromaFraction
        self.hueAngle = hueAngle
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
        
        switch colorSpace {
        case .lch:
            self.init(lightnessFraction: numbers[0] / 100, chromaFraction: numbers[1] / 150, hueAngle: .degrees(numbers[2]))
        case .lab:
//            let normalizedA = numbers[1] / 125
//            let normalizedB = numbers[2] / 125
            self.init(lightnessFraction: numbers[0] / 100, chromaFraction: 0, hueAngle: .zero)
        case .okLch:
            self.init(lightnessFraction: numbers[0], chromaFraction: numbers[1] / 0.4, hueAngle: .degrees(numbers[2]))
        case .okLab:
//            let normalizedA = numbers[1] / 0.4
//            let normalizedB = numbers[2] / 0.4
            self.init(lightnessFraction: numbers[0], chromaFraction: 0, hueAngle: .zero)
        }
    }

    private func absoluteColor(colorSpace: ColorSpace) -> XYZConvertable {
        switch colorSpace {
        case .lch:
            Lch(l: lightnessFraction * 100, c: chromaFraction * 150, h: hueAngle.degrees)
        case .lab:
            Lab(l: lightnessFraction * 100, a: normalizedA * 125, b: normalizedB * 125)
        case .okLch:
            Oklch(l: lightnessFraction, c: chromaFraction * 0.4, h: hueAngle.degrees)
        case .okLab:
            Oklab(l: lightnessFraction, a: normalizedA * 0.4, b: normalizedB * 0.4)
        }
    }
    
    func color(colorSpace: ColorSpace) -> Color {
        Color(absoluteColor(colorSpace: colorSpace))
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
    
    static let cssDecimalFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 5
        return formatter
    }()

}
