import PaletteKit
import Testing

@testable import Palette_Studio

private typealias SavedPalette = Palette_Studio.Palette

/// The editing rules the editor leans on: the customization lock, reordering, format pins, and the
/// WCAG grade shared by the color details and the Pairs tab.
struct EditingTests {

    // MARK: Customization

    @Test func manualEditLocksParameters() {
        let palette = SavedPalette.perfect(name: "Perfect")
        #expect(palette.canEditParameters)

        palette.markCustomized()
        #expect(palette.isCustomized)
        #expect(!palette.canEditParameters)
    }

    /// Generation is deterministic, so discarding edits must reproduce the perfect palette exactly —
    /// including dropping any names the user gave its colors.
    @Test func discardingEditsReproducesThePerfectPalette() throws {
        let palette = SavedPalette.perfect(name: "Perfect")
        let original = palette.colors

        palette.colors.removeLast()
        palette.colors[0].name = "Renamed"
        palette.markCustomized()

        palette.discardManualEdits()
        #expect(palette.colors == original)
        #expect(palette.canEditParameters)
    }

    /// A plain palette has no recipe, so there is nothing to discard back to.
    @Test func discardingLeavesAPlainPaletteAlone() {
        let colors = [PaletteColor(lightnessFraction: 0.5, chromaFraction: 0.3, hueAngle: .degrees(120))]
        let palette = SavedPalette.plain(name: "Plain", colors: colors)
        palette.markCustomized()

        palette.discardManualEdits()
        #expect(palette.colors == colors)
        #expect(!palette.canEditParameters)
    }

    // MARK: Reordering

    private struct Item: Identifiable, Equatable {
        let id: Character
    }

    @Test(arguments: [
        (ids: "c", before: "a" as Character?, expected: "cabde"),
        (ids: "a", before: "d", expected: "bcade"),
        (ids: "b", before: nil, expected: "acdeb"),
        // Moved items keep their current order, however they were listed.
        (ids: "db", before: "a", expected: "bdace"),
        (ids: "ae", before: nil, expected: "bcdae"),
        // A missing target lands at the end rather than dropping the items.
        (ids: "a", before: "z", expected: "bcdea"),
        (ids: "", before: "a", expected: "abcde"),
    ])
    func move(_ c: (ids: String, before: Character?, expected: String)) {
        var items = "abcde".map(Item.init)
        items.move(ids: Array(c.ids), before: c.before)
        #expect(String(items.map(\.id)) == c.expected)
    }

    // MARK: Pinned formats

    @Test func everyFormatRoundTripsThroughItsID() {
        for format in ColorFormat.allCases {
            #expect(ColorFormat(id: format.id) == format)
        }
        #expect(ColorFormat(id: "nonsense") == nil)
    }

    @Test func pinsRoundTripThroughStorageInPinOrder() throws {
        var pins = PinnedColorFormats()
        let formats = Array(ColorFormat.allCases.suffix(3).reversed())
        formats.forEach { pins.toggle($0) }

        let restored = try #require(PinnedColorFormats(rawValue: pins.rawValue))
        #expect(restored == pins)
        #expect(restored.formats == formats)

        pins.toggle(formats[1])
        #expect(pins.formats == [formats[0], formats[2]])
        #expect(!pins.contains(formats[1]))
    }

    /// A pin from a newer build, or a format since removed, is skipped rather than wiping the rest.
    @Test func unknownPinsAreDropped() throws {
        let known = try #require(ColorFormat.allCases.first)
        let pins = try #require(PinnedColorFormats(rawValue: "bogus/format \(known.id)"))
        #expect(pins.formats == [known])
    }

    // MARK: WCAG grade

    @Test(arguments: [
        (contrast: 21.0, grade: "AAA for all text"),
        (contrast: 7.0, grade: "AAA for all text"),
        (contrast: 6.99, grade: "AA for all text"),
        (contrast: 4.5, grade: "AA for all text"),
        (contrast: 4.49, grade: "AA for large text"),
        (contrast: 3.0, grade: "AA for large text"),
        (contrast: 2.99, grade: "Below AA"),
        (contrast: 1.0, grade: "Below AA"),
    ])
    func wcagGrade(_ c: (contrast: Double, grade: String)) {
        #expect(ColorMetrics.wcagGrade(c.contrast).key == c.grade)
    }
}
