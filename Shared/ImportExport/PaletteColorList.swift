#if canImport(AppKit)
import AppKit
import SwiftUI
import UniformTypeIdentifiers

extension UTType {
    /// The `.clr` NSColorList file type.
    static var colorList: UTType { UTType(filenameExtension: "clr") ?? .data }
}

/// A value-type snapshot of a palette for dragging out (e.g. to Finder), so no SwiftData `@Model` is
/// accessed off the main actor during transfer. Exports a re-importable `.clr` file, or CSS as text.
struct PaletteExport: Transferable {

    let name: String
    let colors: [PaletteColor]
    let colorSpace: ColorSpace

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(exportedContentType: .colorList) { export in
            let safeName = export.name.replacingOccurrences(of: "/", with: "-")
            let url = URL.temporaryDirectory.appending(component: "\(safeName).clr")
            try export.colors.writeCLR(to: url, named: export.name, colorSpace: export.colorSpace)
            return SentTransferredFile(url)
        }
        ProxyRepresentation { export in
            PaletteColor.cssText(export.colors, colorSpace: export.colorSpace, convertedToP3: false)
        }
    }
}

extension Array where Element == PaletteColor {

    /// Loads a palette from an `NSColorList`, interpreting each color in the given color space.
    init(_ colorList: NSColorList, colorSpace: ColorSpace) {
        self = colorList.allKeys.compactMap { key in
            colorList.color(withKey: key).flatMap { PaletteColor($0, colorSpace: colorSpace) }
        }
    }

    /// Loads a palette from a `.clr` file, or `nil` if it can't be read as a color list.
    init?(clrFile url: URL, colorSpace: ColorSpace) {
        guard let colorList = NSColorList(name: url.deletingPathExtension().lastPathComponent, fromFile: url.path) else { return nil }
        self.init(colorList, colorSpace: colorSpace)
    }

    /// Realizes the palette into an ordered `NSColorList` in the given color space.
    func colorList(named name: String, colorSpace: ColorSpace) -> NSColorList {
        let colorList = NSColorList(name: name)
        for (index, color) in enumerated() {
            colorList.setColor(color.systemColor(colorSpace: colorSpace), forKey: String(format: "%04d", index))
        }
        return colorList
    }

    /// Writes the palette to a `.clr` file, realized in the given color space.
    func writeCLR(to url: URL, named name: String, colorSpace: ColorSpace) throws {
        try colorList(named: name, colorSpace: colorSpace).write(to: url)
    }

}
#endif
