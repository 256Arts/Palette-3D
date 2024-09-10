//
//  PaletteTests.swift
//  PaletteTests
//
//  Created by 256 Arts Developer on 2024-09-05.
//

import Testing

@testable import Palette_3D

struct PaletteTests {

    @Test func testValuesWithinRange() {
        let colors = PaletteGenerator().generate()
        
        #expect(colors.map({ $0.chromaFraction }).min()! >= 0)
        #expect(colors.map({ $0.chromaFraction }).max()! <= 1)
        
        #expect(colors.map({ $0.normalizedA }).min()! >= -1)
        #expect(colors.map({ $0.normalizedA }).max()! <= 1)
        #expect(colors.map({ $0.normalizedB }).min()! >= -1)
        #expect(colors.map({ $0.normalizedB }).max()! <= 1)
        
        #expect(colors.map({ $0.visualizedX }).min()! >= -1)
        #expect(colors.map({ $0.visualizedX }).max()! <= 1)
        #expect(colors.map({ $0.visualizedY }).min()! >= -1)
        #expect(colors.map({ $0.visualizedY }).max()! <= 1)
        #expect(colors.map({ $0.visualizedZ }).min()! >= -1)
        #expect(colors.map({ $0.visualizedZ }).max()! <= 1)
    }
    
    @Test func testCSS() {
        let color = PaletteColor(lightnessFraction: 0, chromaFraction: 0, hueAngle: .zero)
        
        #expect(color.cssString(colorSpace: .lab, convertedToP3: false) == "lab(0 0 0)")
        #expect(color.cssString(colorSpace: .lab, convertedToP3: true) == "color(display-p3 0 0 0)")
    }

}
