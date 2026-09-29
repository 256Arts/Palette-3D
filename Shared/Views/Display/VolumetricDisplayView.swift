import PaletteKit
#if os(visionOS)
import SwiftUI
import SwiftData

struct VolumetricDisplayView: View {

    let paletteID: PersistentIdentifier?

    @Environment(\.modelContext) private var modelContext

    private var palette: Palette? {
        guard let paletteID else { return nil }
        return modelContext.model(for: paletteID) as? Palette
    }

    var body: some View {
        if let palette {
            PaletteSphereView(colors: palette.colors, colorSpace: palette.colorSpace)
        } else {
            ContentUnavailableView("No Palette", systemImage: "circle.dashed")
        }
    }
}
#endif
