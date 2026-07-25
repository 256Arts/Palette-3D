import PaletteKit

/// One text export format: a `ColorRepresentation` realized in a particular `Gamut`.
///
/// Neither half identifies a format on its own — the framework snippets (SwiftUI/UIKit/AppKit) exist
/// under both P3 and sRGB, which is exactly the distinction a user pinning "SwiftUI P3" cares about.
struct ColorFormat: Hashable, Identifiable {

    let gamut: Gamut
    let representation: ColorRepresentation

    /// Round-trips through `init?(id:)`, which is how a pin persists. Neither raw value contains a slash.
    var id: String { "\(gamut.rawValue)/\(representation.rawValue)" }

    init(gamut: Gamut, representation: ColorRepresentation) {
        self.gamut = gamut
        self.representation = representation
    }

    init?(id: String) {
        let parts = id.split(separator: "/")
        guard parts.count == 2,
              let gamut = Gamut(rawValue: String(parts[0])),
              let representation = ColorRepresentation(rawValue: String(parts[1])) else { return nil }
        self.init(gamut: gamut, representation: representation)
    }

    /// Every format the app can export, in menu order.
    static let allCases: [ColorFormat] = Gamut.allCases.flatMap { gamut in
        gamut.representations.map { ColorFormat(gamut: gamut, representation: $0) }
    }

    /// The name to use inside the format's own gamut section, where the gamut is already established.
    var name: String {
        representation.name
    }

    /// The name to use wherever the format appears away from its gamut section — a pin list or the top
    /// of the export menu. Qualified only when the representation exists in more than one gamut, so most
    /// formats stay short and only the ambiguous ones read "SwiftUI (P3)".
    var qualifiedName: String {
        Self.allCases.count(where: { $0.representation == representation }) > 1
            ? "\(representation.name) (\(gamut.rawValue))"
            : representation.name
    }

    /// This format's value for `color`.
    func string(_ color: PaletteColor, colorSpace: ColorSpace) -> String {
        color.string(representation, colorSpace: colorSpace, gamut: gamut)
    }

    /// The palette rendered as one line per color in this format.
    func text(_ colors: [PaletteColor], colorSpace: ColorSpace) -> String {
        PaletteColor.text(colors, representation: representation, colorSpace: colorSpace, gamut: gamut)
    }
}

/// The formats the user has pinned, in the order they pinned them. `RawRepresentable` over a string of
/// ids so it persists straight into `@AppStorage`, shared by the color details rows and the export menu.
struct PinnedColorFormats: RawRepresentable, Equatable {

    static let storageKey = "pinnedColorFormats"

    var formats: [ColorFormat]

    init(_ formats: [ColorFormat] = []) {
        self.formats = formats
    }

    init?(rawValue: String) {
        self.init(rawValue.split(separator: " ").compactMap { ColorFormat(id: String($0)) })
    }

    var rawValue: String {
        formats.map(\.id).joined(separator: " ")
    }

    func contains(_ format: ColorFormat) -> Bool {
        formats.contains(format)
    }

    /// Pins `format`, or unpins it if it was already pinned. New pins land at the end so existing ones
    /// keep their position.
    mutating func toggle(_ format: ColorFormat) {
        if let index = formats.firstIndex(of: format) {
            formats.remove(at: index)
        } else {
            formats.append(format)
        }
    }
}

extension Gamut {

    /// Whether expressing any of `colors` in this gamut's formats clamps it — i.e. whether exporting the
    /// whole palette here loses color. Short-circuits on the first out-of-gamut color.
    func clamps(_ colors: [PaletteColor], colorSpace: ColorSpace) -> Bool {
        colors.contains { clamps($0, colorSpace: colorSpace) }
    }
}
