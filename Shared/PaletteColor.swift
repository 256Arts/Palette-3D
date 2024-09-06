//
//  PaletteColor.swift
//  Palette3D
//
//  Created by 256 Arts Developer on 2022-08-15.
//

import ChromaKit
import SwiftUI

enum ColorSpace: String, CaseIterable, Identifiable {
    case lab, lch, okLab, okLch

    var id: Self { self }
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

    func color(colorSpace: ColorSpace) -> Color {
        switch colorSpace {
        case .lch:
            Color.lch(lightnessFraction * 100, chromaFraction * 150, hueAngle.degrees)
        case .lab:
            Color.lab(lightnessFraction * 100, normalizedA * 125, normalizedB * 125)
        case .okLch:
            Color.oklch(lightnessFraction, chromaFraction * 0.4, hueAngle.degrees)
        case .okLab:
            Color.oklab(lightnessFraction, normalizedA * 0.4, normalizedB * 0.4)
        }
    }
    
    func cssString(colorSpace: ColorSpace) -> String {
        switch colorSpace {
        case .lch:
            "lch(\(lightnessFraction * 100) \(chromaFraction * 150) \(hueAngle.degrees))"
        case .lab:
            "lab(\(lightnessFraction * 100) \(normalizedA * 125) \(normalizedB * 125))"
        case .okLch:
            "oklch(\(lightnessFraction) \(chromaFraction * 0.4) \(hueAngle.degrees))"
        case .okLab:
            "oklab(\(lightnessFraction) \(normalizedA * 0.4) \(normalizedB * 0.4))"
        }
    }

}
