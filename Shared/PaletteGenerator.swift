//
//  PaletteGenerator.swift
//  Palette 3D
//
//  Created by 256 Arts Developer on 2022-08-15.
//

import SwiftUI

final class PaletteGenerator: ObservableObject {

    /// Color space
    @Published var colorSpace: ColorSpace = .okLch
    
    /// Number of levels of lightness
    @Published var lightnessLevels: Int = 5
    
    /// Rotates each lightness layer
    @Published var lightnessTwist = false
    
    /// Number of levels of chroma
    @Published var chromaLevels: Int = 3
    
    /// Whether the 1st chroma level is just a single grayscale color
    @Published var chromaStartsAtZero = true
    
    /// Chroma multiplier (0.5 = all colors have half the chroma)
    @Published var chromaMultiplier = 1.0
    
    /// Number of different hues at the largest chroma level
    @Published var maxHueSegments: Int = 12
    
    /// Whether each hue should be represented in all lightness levels
    @Published var continuousHues = true
    
    /// Rotates each chroma ring
    @Published var chromaTwist = false
    
    /// Rotate the entire palette to pick different hues
    @Published var startingHueOffset: Angle = .zero

    func generate() -> [PaletteColor] {
        var colors: [PaletteColor] = []
        let maxLightnessLayerRadius = 1.0
        let maxLightnessLayerCircumference = 2 * .pi * maxLightnessLayerRadius
        let targetCircumferencePerHue = maxLightnessLayerCircumference / Double(maxHueSegments)
        
        for lightness in stride(from: 0.0, through: 1.0, by: 1.0 / Double(lightnessLevels-1)) {
            let lightnessLayerRadius = sqrt(1 - pow(lightness * 2 - 1, 2))
            
            switch lightness {
            case 0, 1:
                colors.append(PaletteColor(lightnessFraction: lightness, chromaFraction: 0, hueAngle: .zero))
            default:
                let chromaStep = chromaStartsAtZero ? 1 / Double(chromaLevels-1) : 1 / (Double(chromaLevels)-0.5)
                let chromaStart = chromaStartsAtZero ? 0 : chromaStep / 2
                
                for chroma in stride(from: chromaStart, through: 1.0, by: chromaStep) {
                    if chroma == 0 {
                        colors.append(PaletteColor(lightnessFraction: lightness, chromaFraction: chroma, hueAngle: .zero))
                    } else {
                        let chromaLayerRadius = chroma * lightnessLayerRadius
                        let chromaLayerCircumference = 2 * .pi * chromaLayerRadius
                        let hueSegments = Int(round(continuousHues ? Double(maxHueSegments) * chroma : chromaLayerCircumference / targetCircumferencePerHue))
                        let hueStart = startingHueOffset.degrees + (chromaTwist ? (chroma * 360) / Double(hueSegments) : 0) + (lightnessTwist ? (lightness * 360) / Double(hueSegments) : 0)
                        let hueEnd = hueStart + 360
                        let hueStep = 360 / Double(hueSegments)
                        
                        for hue in stride(from: hueStart, to: hueEnd, by: hueStep) {
                            colors.append(PaletteColor(lightnessFraction: lightness, chromaFraction: chroma * chromaMultiplier, hueAngle: .degrees(hue)))
                        }
                    }
                }
            }
        }

        return colors
    }

}
