//
//  PaletteTests.swift
//  PaletteTests
//
//  Created by 256 Arts Developer on 2024-09-05.
//

import Testing
import SwiftData
import SwiftUI

@testable import Palette_3D

struct PaletteTests {

    /// Verifies SwiftData can persist and reload a `Palette`'s Codable value types (`Parameters?` and `[PaletteColor]`).
    @MainActor
    @Test func palettePersistsThroughSwiftData() throws {
        let container = try ModelContainer(for: Palette.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = container.mainContext

        context.insert(Palette.perfect(name: "Perfect"))
        context.insert(Palette.plain(name: "Plain", colors: [PaletteColor(lightnessFraction: 0.5, chromaFraction: 0.3, hueAngle: .degrees(120))]))
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<Palette>())
        #expect(fetched.count == 2)

        let perfect = try #require(fetched.first { $0.name == "Perfect" })
        #expect(perfect.parameters != nil)
        #expect(!perfect.colors.isEmpty)

        let plain = try #require(fetched.first { $0.name == "Plain" })
        #expect(plain.parameters == nil)
        #expect(plain.colors.count == 1)
        #expect(plain.colors.first?.hueAngle == .degrees(120))
    }

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

        // Lab and P3 are output-only formats; they should not parse back in.
        let labCSS = color.cssString(colorSpace: .lab, convertedToP3: false)
        #expect(labCSS == "lab(0 0 0)")
        #expect(PaletteColor(css: labCSS) == nil)

        let p3CSS = color.cssString(colorSpace: .lab, convertedToP3: true)
        #expect(p3CSS == "color(display-p3 0 0 0)")
        #expect(PaletteColor(css: p3CSS) == nil)

        // Lch and Oklch round-trip through CSS.
        for space in [ColorSpace.lch, .okLch] {
            let original = PaletteColor(lightnessFraction: 0.5, chromaFraction: 0.2, hueAngle: .degrees(90))
            let parsed = PaletteColor(css: original.cssString(colorSpace: space, convertedToP3: false))
            #expect(abs((parsed?.lightnessFraction ?? -1) - 0.5) < 1e-6)
            #expect(abs((parsed?.chromaFraction ?? -1) - 0.2) < 1e-6)
            #expect(abs((parsed?.hueAngle.degrees ?? -1) - 90) < 1e-6)
        }
    }

}
