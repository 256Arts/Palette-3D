import Foundation

/// A palette fetched from lospec.com's palette-list JSON API.
struct LospecPalette: Decodable {

    let name: String
    let author: String
    let colors: [String] // 6-digit hex strings, without a leading "#".

    /// Whether `url` is a `lospec-palette://<slug>` link this type can fetch.
    static func canHandle(_ url: URL) -> Bool {
        url.scheme == "lospec-palette" && url.host() != nil
    }

    /// Fetches the palette a `lospec-palette://<slug>` URL points to.
    static func fetch(_ url: URL) async throws -> LospecPalette {
        guard let slug = url.host(),
              let jsonURL = URL(string: "https://lospec.com/palette-list/\(slug).json") else {
            throw URLError(.badURL)
        }
        let (data, _) = try await URLSession.shared.data(from: jsonURL)
        return try JSONDecoder().decode(LospecPalette.self, from: data)
    }

    /// The palette's colors realized in the given color space. Unparseable entries are skipped.
    func paletteColors(colorSpace: ColorSpace) -> [PaletteColor] {
        colors.compactMap { PaletteColor(hex: $0, colorSpace: colorSpace) }
    }
}

extension PaletteColor {

    /// Parses a 6-digit sRGB hex string, with or without a leading `#`.
    init?(hex: String, colorSpace: ColorSpace) {
        let digits = hex.hasPrefix("#") ? String(hex.dropFirst()) : hex
        guard digits.count == 6, let value = Int(digits, radix: 16) else { return nil }
        self.init(sRGB8BitRed: (value >> 16) & 0xFF, green: (value >> 8) & 0xFF, blue: value & 0xFF, colorSpace: colorSpace)
    }
}
