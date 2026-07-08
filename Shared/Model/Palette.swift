//
//  Palette.swift
//  Palette 3D
//
//  A saved palette: either a "perfect" palette (keeps its generator parameters) or a plain color list.
//

import Foundation
import SwiftData

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

    /// Whether the generation parameters may still be edited (perfect and not yet customized).
    var canEditParameters: Bool {
        parameters != nil && !isCustomized
    }
}
