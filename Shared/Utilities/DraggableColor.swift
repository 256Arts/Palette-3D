import PaletteKit
import SwiftUI
import UniformTypeIdentifiers

extension UTType {
    /// Lossless in-app representation for swatch drags, so reordering a swatch is never mistaken
    /// for dropping a loose `Color`.
    static let palette3DColor = UTType(exportedAs: "com.256arts.palette-3d.color")
}

struct DraggableColor: Transferable, Codable, Identifiable {

    var color: PaletteColor
    var colorSpace: ColorSpace

    var id: PaletteColor.ID { color.id }

    static var transferRepresentation: some TransferRepresentation {
        // Primary: the exact palette color, kept whole for in-app reordering.
        CodableRepresentation(contentType: .palette3DColor)
        // Secondary: a plain color, so other apps still receive something usable.
        ProxyRepresentation(exporting: { $0.color.color(colorSpace: $0.colorSpace) })
    }
}
