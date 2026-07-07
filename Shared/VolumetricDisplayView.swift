//
//  VolumetricDisplayView.swift
//  Palette 3D
//
//  The visionOS `.volumetric` window: renders a palette's sphere, looked up live from SwiftData by id
//  so edits in the main window update the volume.
//

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
            let parameters = palette.parameters ?? .init()
            PaletteSphereView(
                colors: palette.colors,
                colorSpace: parameters.colorSpace,
                chromaMultiplier: parameters.chromaMultiplier)
        } else {
            ContentUnavailableView("No Palette", systemImage: "circle.dashed")
        }
    }
}
#endif
