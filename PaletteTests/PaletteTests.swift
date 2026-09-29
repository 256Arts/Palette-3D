import PaletteKit
import SwiftData
import SwiftUI
import Testing

@testable import Palette_Studio

/// The color model, generator, and file formats are PaletteKit's, and are tested there. What's left
/// for the app to prove is its own layer: that SwiftData can store a palette, and that the bridge
/// between the `@Model` and PaletteKit's value type is lossless.
///
/// `Palette` is ambiguous in this module — both the app and PaletteKit define one — so each is
/// named explicitly: `SavedPalette` for the app's `@Model`, `KitPalette` for PaletteKit's value type.
private typealias SavedPalette = Palette_Studio.Palette
private typealias KitPalette = PaletteKit.Palette

struct PaletteTests {

    /// Verifies SwiftData can persist and reload a `Palette`'s Codable value types (`Parameters?` and `[PaletteColor]`).
    @MainActor
    @Test func palettePersistsThroughSwiftData() throws {
        let container = try ModelContainer(for: SavedPalette.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none))
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

    /// The library syncs through CloudKit, which rejects a schema with a required attribute that has no
    /// default or with a unique constraint — and only says so at launch, on a device signed into iCloud.
    @Test func schemaIsCloudKitCompatible() throws {
        let entity = try #require(Schema([SavedPalette.self]).entities.first)
        #expect(entity.uniquenessConstraints.isEmpty)
        for attribute in entity.attributes {
            #expect(attribute.isOptional || attribute.defaultValue != nil, "\(attribute.name) needs a default")
            #expect(!attribute.isUnique, "\(attribute.name) can't be unique")
        }
        // Checked statically rather than by opening a CloudKit container: its mirroring delegate
        // outlives the test and crashes the host once the store is torn down.
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

    /// Undoing a color edit on a perfect palette restores the colors *and* unlocks the parameters the
    /// edit locked; redo takes both back.
    @MainActor @Test func undoRestoresColorsAndCustomization() {
        let palette = SavedPalette.perfect(name: "Perfect")
        let undoManager = UndoManager()
        undoManager.groupsByEvent = false
        let original = palette.editState

        undoManager.beginUndoGrouping()
        palette.colors.removeFirst()
        palette.isCustomized = true
        palette.registerUndo(from: original, with: undoManager)
        undoManager.endUndoGrouping()
        #expect(undoManager.undoActionName == String(localized: "Edit Colors"))

        undoManager.undo()
        #expect(palette.editState == original)
        #expect(palette.canEditParameters)

        undoManager.redo()
        #expect(palette.colors.count == original.colors.count - 1)
        #expect(!palette.canEditParameters)
        // The redo registered the undo again, so the step can be walked back a second time.
        #expect(undoManager.canUndo)
    }

    /// A parameter change undoes as one step, parameters and regenerated colors together.
    @MainActor @Test func undoRestoresParameters() throws {
        let palette = SavedPalette.perfect(name: "Perfect")
        let undoManager = UndoManager()
        undoManager.groupsByEvent = false
        let original = palette.editState
        var restored: SavedPalette.EditState?

        var parameters = try #require(palette.parameters)
        parameters.lightnessLevels += 1
        undoManager.beginUndoGrouping()
        palette.parameters = parameters
        palette.colors = PaletteGenerator(parameters).generate()
        palette.registerUndo(from: original, with: undoManager) { restored = $0 }
        undoManager.endUndoGrouping()
        #expect(undoManager.undoActionName == String(localized: "Change Parameters"))

        undoManager.undo()
        #expect(palette.editState == original)
        #expect(restored == original)
    }
}
