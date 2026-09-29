import PaletteKit
import SwiftUI

/// Pinned text formats first, then the rest grouped by gamut, then the file formats. Any entry whose
/// gamut can't hold every color in the palette is flagged — exporting there would silently clamp.
///
/// The contents of a menu rather than the menu itself, so the editor's toolbar and the Palette ▸ Export
/// command share one list.
struct PaletteExportMenu: View {

    let palette: Palette
    let colorSpace: ColorSpace
    #if os(macOS)
    /// Saving a color list needs a save panel and somewhere to report failure, which the editor owns.
    let exportColorList: () -> Void
    #endif

    /// Shared with the color details rows, where formats are pinned.
    @AppStorage(PinnedColorFormats.storageKey) private var pinnedFormats = PinnedColorFormats()

    var body: some View {
        let clampsSRGB = Gamut.sRGB.clamps(palette.colors, colorSpace: colorSpace)

        Section {
            ForEach(pinnedFormats.formats) { format in
                textShareLink(format, name: format.qualifiedName)
            }
        }

        Section {
            ForEach(Gamut.allCases) { gamut in
                Menu {
                    ForEach(gamut.representations) { representation in
                        let format = ColorFormat(gamut: gamut, representation: representation)
                        textShareLink(format, name: format.name)
                    }
                } label: {
                    FormatLabel(name: LocalizedStringKey(gamut.shareMenuTitle),
                                isClamped: gamut.clamps(palette.colors, colorSpace: colorSpace),
                                systemImage: "square.and.arrow.up")
                }
            }
        }

        Section {
            // The GIMP palette and the palette image are both written as 8-bit sRGB pixels.
            ShareLink(item: GIMPPaletteExport(palette: palette.snapshot(), colorSpace: colorSpace),
                      preview: SharePreview("\(palette.name).gpl")) {
                FormatLabel(name: "GIMP Palette File", isClamped: clampsSRGB, systemImage: "swatchpalette")
            }
            ShareLink(item: PaletteImageExport(palette: palette.snapshot(), colorSpace: colorSpace),
                      preview: SharePreview("\(palette.name).png")) {
                FormatLabel(name: "Palette Image", isClamped: clampsSRGB, systemImage: "photo")
            }
            #if os(macOS)
            // An NSColorList holds each color as a Display P3 system color.
            Button(action: exportColorList) {
                FormatLabel(name: "Save as Color List…",
                            isClamped: Gamut.displayP3.clamps(palette.colors, colorSpace: colorSpace),
                            systemImage: "swatchpalette")
            }
            #endif
        }
    }

    private func textShareLink(_ format: ColorFormat, name: String) -> some View {
        ShareLink(item: format.text(palette.colors, colorSpace: colorSpace)) {
            FormatLabel(name: LocalizedStringKey(name), isClamped: format.gamut.clamps(palette.colors, colorSpace: colorSpace))
        }
    }
}
