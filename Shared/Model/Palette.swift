import Foundation
import PaletteKit
import SwiftData

/// The app's saved palette.
///
/// This is the SwiftData face of a palette; the colors, generator, and file formats all come from
/// **PaletteKit**. `Palette` here always means this `@Model` — PaletteKit's storage-agnostic value
/// type is spelled `PaletteKit.Palette`, and the two convert via `init(_:)` and `snapshot()`.
@Model
final class Palette {

    var name: String

    /// The generation parameters, if this is a "perfect" palette. `nil` for plain color lists (e.g. imported `.clr`).
    var parameters: PaletteGenerator.Parameters?

    /// The realized colors. For a perfect palette this is regenerated from `parameters` until the user customizes it.
    var colors: [PaletteColor]

    /// Once the user manually edits a color, generation is locked so parameter changes can't overwrite their work.
    var isCustomized: Bool

    var dateModified: Date

    init(name: String, parameters: PaletteGenerator.Parameters?, colors: [PaletteColor], isCustomized: Bool = false, dateModified: Date = .now) {
        self.name = name
        self.parameters = parameters
        self.colors = colors
        self.isCustomized = isCustomized
        self.dateModified = dateModified
    }

    /// A perfect palette seeded from generator parameters, with its colors generated.
    static func perfect(name: String = "Perfect Palette", parameters: PaletteGenerator.Parameters = .init()) -> Palette {
        Palette(name: name, parameters: parameters, colors: PaletteGenerator(parameters).generate())
    }

    /// A plain palette from a fixed list of colors (e.g. a `.clr` import or an empty palette).
    static func plain(name: String, colors: [PaletteColor] = []) -> Palette {
        Palette(name: name, parameters: nil, colors: colors)
    }

    /// Saves an imported PaletteKit palette (a `.gpl`, `.clr`, palette image, or lospec fetch) as a
    /// plain palette — an import has colors, but no generator recipe behind them.
    convenience init(_ imported: PaletteKit.Palette) {
        self.init(name: imported.name, parameters: nil, colors: imported.colors)
    }

    /// A value snapshot for export and drag-and-drop, so no `@Model` is touched off the main actor
    /// mid-transfer.
    func snapshot() -> PaletteKit.Palette {
        PaletteKit.Palette(
            name: name,
            colors: colors,
            source: parameters == nil ? .imported : .generated)
    }

    /// The color space this palette's fractions are realized in. Plain palettes were imported into
    /// Oklch, which is also the generator's default.
    var colorSpace: ColorSpace {
        parameters?.colorSpace ?? .okLch
    }

    /// Whether the generation parameters may still be edited (perfect and not yet customized).
    var canEditParameters: Bool {
        parameters != nil && !isCustomized
    }
}
