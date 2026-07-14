import PaletteKit
import SwiftData
import SwiftUI
import Testing

@testable import Palette_3D

/// The color model, generator, and file formats are PaletteKit's, and are tested there. What's left
/// for the app to prove is its own layer: that SwiftData can store a palette, and that the bridge
/// between the `@Model` and PaletteKit's value type is lossless.
///
/// `Palette` is ambiguous in this module — both the app and PaletteKit define one — so each is
/// named explicitly: `SavedPalette` for the app's `@Model`, `KitPalette` for PaletteKit's value type.
private typealias SavedPalette = Palette_3D.Palette
private typealias KitPalette = PaletteKit.Palette

struct PaletteTests {

    /// Verifies SwiftData can persist and reload a `Palette`'s Codable value types (`Parameters?` and `[PaletteColor]`).
    @MainActor
    @Test func palettePersistsThroughSwiftData() throws {
        let container = try ModelContainer(for: SavedPalette.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = container.mainContext

        context.insert(SavedPalette.perfect(name: "Perfect"))
        context.insert(SavedPalette.plain(name: "Plain", colors: [PaletteColor(lightnessFraction: 0.5, chromaFraction: 0.3, hueAngle: .degrees(120))]))
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<SavedPalette>())
        #expect(fetched.count == 2)

        let perfect = try #require(fetched.first { $0.name == "Perfect" })
        #expect(perfect.parameters != nil)
        #expect(!perfect.colors.isEmpty)

        let plain = try #require(fetched.first { $0.name == "Plain" })
        #expect(plain.parameters == nil)
        #expect(plain.colors.count == 1)
        #expect(plain.colors.first?.hueAngle == .degrees(120))
    }

    /// An imported PaletteKit palette lands as a plain saved palette, and snapshots back out intact —
    /// this is the path every import (.gpl, .clr, palette image, lospec) and every export takes.
    @Test func importedPaletteRoundTripsThroughTheModel() throws {
        let imported = try #require(KitPalette(gpl: "GIMP Palette\nName: Imported\n255 0 0 Red\n0 0 255\n", name: "Fallback", colorSpace: .okLch))

        let saved = SavedPalette(imported)
        #expect(saved.name == "Imported")
        #expect(saved.parameters == nil) // An import has colors, but no generator recipe.
        #expect(saved.colorSpace == .okLch)
        #expect(saved.colors.count == 2)
        #expect(saved.colors.first?.name == "Red")

        let snapshot = saved.snapshot()
        #expect(snapshot.name == "Imported")
        #expect(snapshot.source == .imported)
        #expect(snapshot.colors == imported.colors)
    }

    /// A generated palette snapshots as `.generated`, so an export knows it came from the generator.
    @Test func perfectPaletteSnapshotsAsGenerated() {
        let perfect = SavedPalette.perfect(name: "Perfect")
        let snapshot = perfect.snapshot()

        #expect(snapshot.source == .generated)
        #expect(snapshot.colors == perfect.colors)
        #expect(perfect.colorSpace == perfect.parameters?.colorSpace)
    }
}
