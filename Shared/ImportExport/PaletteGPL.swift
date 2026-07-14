import SwiftUI
import UniformTypeIdentifiers

extension UTType {
    /// The GIMP palette (`.gpl`) file type.
    static var gimpPalette: UTType { UTType(filenameExtension: "gpl") ?? .plainText }
}

/// A parsed GIMP palette: its declared name (if any) and realized colors.
struct GIMPPalette {

    var name: String?
    var colors: [PaletteColor]

    /// Parses GIMP Palette (v1 or v2) text, realizing each color in the given color space.
    /// Returns `nil` if the required `GIMP Palette` magic header is missing.
    init?(gpl text: String, colorSpace: ColorSpace) {
        // Lines are line-feed separated; tolerate CRLF by stripping a trailing carriage return.
        var lines = text.split(separator: "\n", omittingEmptySubsequences: false).map {
            $0.hasSuffix("\r") ? String($0.dropLast()) : String($0)
        }

        guard lines.first?.trimmingCharacters(in: .whitespaces) == "GIMP Palette" else { return nil }
        lines.removeFirst()

        var name: String?
        var colors: [PaletteColor] = []

        for line in lines {
            if line.isEmpty || line.hasPrefix("#") {
                continue // Blank lines and comments are ignored anywhere in the file.
            } else if let value = line.headerValue(prefix: "Name:") {
                name = value
            } else if line.headerValue(prefix: "Columns:") != nil {
                continue // Column count only affects GIMP's own layout; we don't use it.
            } else if let color = PaletteColor(gplColorLine: line, colorSpace: colorSpace) {
                colors.append(color)
            }
        }

        self.name = name?.isEmpty == false ? name : nil
        self.colors = colors
    }
}

private extension StringProtocol {
    /// The trimmed value following a header `prefix` (e.g. `Name:`), or `nil` if the line isn't that header.
    func headerValue(prefix: String) -> String? {
        guard hasPrefix(prefix) else { return nil }
        return String(dropFirst(prefix.count)).trimmingCharacters(in: .whitespaces)
    }
}

extension PaletteColor {

    /// Parses one GIMP color line (`r g b optional name`), or `nil` if it doesn't start with three integers.
    init?(gplColorLine line: String, colorSpace: ColorSpace) {
        let scanner = Scanner(string: line)
        guard let r = scanner.scanInt(), let g = scanner.scanInt(), let b = scanner.scanInt() else { return nil }
        let name = String(line[scanner.currentIndex...]).trimmingCharacters(in: .whitespaces)
        self.init(sRGB8BitRed: r, green: g, blue: b, name: name.isEmpty ? nil : name, colorSpace: colorSpace)
    }

    /// This color as a GIMP color line (`r g b [name]`), realized and clamped to 8-bit sRGB.
    func gplLine(colorSpace: ColorSpace) -> String {
        let (r, g, b) = srgb8Bit(colorSpace: colorSpace)
        let components = String(format: "%3d %3d %3d", r, g, b)
        return name.map { "\(components) \($0)" } ?? components
    }
}

extension Array where Element == PaletteColor {

    /// Serializes the palette as GIMP Palette v2 text, realized in sRGB.
    /// - Parameter columns: GIMP's preferred display column count; `0` means flowing (variable).
    func gplString(named name: String, colorSpace: ColorSpace, columns: Int = 0) -> String {
        var lines = ["GIMP Palette", "Name: \(name)", "Columns: \(columns)", "#"]
        lines += map { $0.gplLine(colorSpace: colorSpace) }
        return lines.joined(separator: "\n") + "\n"
    }
}

/// A value-type snapshot of a palette for sharing out as a `.gpl` file. Cross-platform (plain text).
struct GIMPPaletteExport: Transferable {

    let name: String
    let colors: [PaletteColor]
    let colorSpace: ColorSpace

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(exportedContentType: .gimpPalette) { export in
            let safeName = export.name.replacingOccurrences(of: "/", with: "-")
            let url = URL.temporaryDirectory.appending(component: "\(safeName).gpl")
            let text = export.colors.gplString(named: export.name, colorSpace: export.colorSpace)
            try text.write(to: url, atomically: true, encoding: .utf8)
            return SentTransferredFile(url)
        }
    }
}
