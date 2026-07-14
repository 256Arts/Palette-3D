import PaletteKit
import SwiftUI
import SwiftData

@main
struct Palette3DApp: App {

    /// A single shared container so every window (including the visionOS volume) reads the same store.
    private let container: ModelContainer

    @State private var showingEvent = false

    init() {
        container = try! ModelContainer(for: Palette.self)
    }

    var body: some Scene {
        WindowGroup {
            PaletteListView()
                .alert("Event Intro", isPresented: $showingEvent) {
                    Button("OK", role: .close) { }
                } message: {
                    Text("Now let's celebrate by designing a color palette in the style using the new features!")
                }
                .onOpenURL { url in
                    if url.path().contains("palette3d/appstoreevent") {
                        showingEvent = true
                    }
                }
        }
        .modelContainer(container)

        #if os(visionOS)
        WindowGroup("Display", id: "display", for: PersistentIdentifier.self) { $paletteID in
            VolumetricDisplayView(paletteID: paletteID)
        }
        .windowStyle(.volumetric)
        .defaultSize(width: 1, height: 1, depth: 1, in: .meters)
        .modelContainer(container)
        #endif
    }
}
