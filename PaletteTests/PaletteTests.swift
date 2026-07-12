//
//  PaletteTests.swift
//  PaletteTests
//
//  Created by 256 Arts Developer on 2024-09-05.
//

import Testing
import SwiftData
import SwiftUI
import CoreGraphics

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

    @Test func testGPLParsing() throws {
        let gpl = """
        GIMP Palette
        Name: My Palette
        Columns: 4
        # A comment
        255   0   0 Red
          0 255   0
        # Another comment

        0 0 255 Full Blue
        """
        let palette = try #require(GIMPPalette(gpl: gpl, colorSpace: .okLch))
        #expect(palette.name == "My Palette")
        #expect(palette.colors.count == 3)
        #expect(palette.colors[0].name == "Red")
        #expect(palette.colors[1].name == nil) // No name given.
        #expect(palette.colors[2].name == "Full Blue") // Multi-word names are preserved.

        // sRGB pure red round-trips back to 8-bit sRGB (within rounding).
        let (r, g, b) = palette.colors[0].srgb8Bit(colorSpace: .okLch)
        #expect(r == 255 && g == 0 && b == 0)

        // A file missing the magic header is rejected.
        #expect(GIMPPalette(gpl: "255 0 0\n", colorSpace: .okLch) == nil)
    }

    @Test func testGPLRoundTrip() throws {
        let colors = [
            PaletteColor(sRGB8BitRed: 18, green: 52, blue: 86, name: "Navy", colorSpace: .okLch),
            PaletteColor(sRGB8BitRed: 200, green: 100, blue: 50, colorSpace: .okLch)
        ].compactMap { $0 }
        #expect(colors.count == 2)

        let text = colors.gplString(named: "Round Trip", colorSpace: .okLch)
        #expect(text.hasPrefix("GIMP Palette\nName: Round Trip\nColumns: 0\n#\n"))

        let reparsed = try #require(GIMPPalette(gpl: text, colorSpace: .okLch))
        #expect(reparsed.name == "Round Trip")
        #expect(reparsed.colors.count == 2)
        #expect(reparsed.colors[0].name == "Navy")
        for (original, parsed) in zip(colors, reparsed.colors) {
            #expect(original.srgb8Bit(colorSpace: .okLch) == parsed.srgb8Bit(colorSpace: .okLch))
        }
    }

    @Test func testHexParsing() throws {
        let red = try #require(PaletteColor(hex: "ff0000", colorSpace: .okLch))
        #expect(red.srgb8Bit(colorSpace: .okLch) == (255, 0, 0))

        // A leading "#" is tolerated (Lospec's JSON omits it, but users paste both forms).
        let navy = try #require(PaletteColor(hex: "#123456", colorSpace: .okLch))
        #expect(navy.srgb8Bit(colorSpace: .okLch) == (18, 52, 86))

        #expect(PaletteColor(hex: "fff", colorSpace: .okLch) == nil) // Shorthand not supported.
        #expect(PaletteColor(hex: "gggggg", colorSpace: .okLch) == nil)
    }

    @Test func testLospecPalette() throws {
        let json = #"{"name":"Test Palette","author":"Someone","colors":["ff0000","00ff00","0000ff"]}"#
        let lospec = try JSONDecoder().decode(LospecPalette.self, from: Data(json.utf8))
        #expect(lospec.name == "Test Palette")

        let colors = lospec.paletteColors(colorSpace: .okLch)
        #expect(colors.count == 3)
        #expect(colors[2].srgb8Bit(colorSpace: .okLch) == (0, 0, 255))

        #expect(LospecPalette.canHandle(URL(string: "lospec-palette://pico-8")!))
        #expect(!LospecPalette.canHandle(URL(string: "https://lospec.com/palette-list/pico-8")!))
    }

    /// Builds an RGBA8 sRGB image from rows of pixel tuples, for palette-image parsing tests.
    private func image(rows: [[(r: UInt8, g: UInt8, b: UInt8, a: UInt8)]]) throws -> CGImage {
        let width = rows[0].count
        var data = rows.flatMap { $0.flatMap { [$0.r, $0.g, $0.b, $0.a] } }
        let context = try #require(CGContext(
            data: &data,
            width: width,
            height: rows.count,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        return try #require(context.makeImage())
    }

    @Test func testPaletteImageParsing() throws {
        // A valid 3x1 palette image parses in pixel order.
        let valid = try image(rows: [[(255, 0, 0, 255), (0, 255, 0, 255), (0, 0, 255, 255)]])
        let colors = try #require([PaletteColor](paletteImage: valid, colorSpace: .okLch))
        #expect(colors.count == 3)
        #expect(colors[0].srgb8Bit(colorSpace: .okLch) == (255, 0, 0))
        #expect(colors[1].srgb8Bit(colorSpace: .okLch) == (0, 255, 0))
        #expect(colors[2].srgb8Bit(colorSpace: .okLch) == (0, 0, 255))

        // Taller than 1px is rejected.
        let tall = try image(rows: [[(255, 0, 0, 255)], [(0, 255, 0, 255)]])
        #expect([PaletteColor](paletteImage: tall, colorSpace: .okLch) == nil)

        // Clear pixels are rejected.
        let clear = try image(rows: [[(255, 0, 0, 255), (0, 0, 0, 0)]])
        #expect([PaletteColor](paletteImage: clear, colorSpace: .okLch) == nil)
    }

    @Test func testPaletteImageRoundTrip() throws {
        let colors = [
            PaletteColor(sRGB8BitRed: 18, green: 52, blue: 86, colorSpace: .okLch),
            PaletteColor(sRGB8BitRed: 200, green: 100, blue: 50, colorSpace: .okLch),
            PaletteColor(sRGB8BitRed: 0, green: 0, blue: 0, colorSpace: .okLch)
        ].compactMap { $0 }
        #expect(colors.count == 3)

        // The rendered image is exactly one opaque pixel per color, 1px tall.
        let image = try #require(colors.paletteImage(colorSpace: .okLch))
        #expect(image.width == 3)
        #expect(image.height == 1)

        // Encoding to PNG and re-decoding reproduces the sRGB values.
        let data = try colors.paletteImagePNGData(colorSpace: .okLch)
        let source = try #require(CGImageSourceCreateWithData(data as CFData, nil))
        let decoded = try #require(CGImageSourceCreateImageAtIndex(source, 0, nil))
        let reparsed = try #require([PaletteColor](paletteImage: decoded, colorSpace: .okLch))
        #expect(reparsed.count == 3)
        for (original, parsed) in zip(colors, reparsed) {
            #expect(original.srgb8Bit(colorSpace: .okLch) == parsed.srgb8Bit(colorSpace: .okLch))
        }

        // An empty palette has no image to export.
        #expect([PaletteColor]().paletteImage(colorSpace: .okLch) == nil)
    }

}
