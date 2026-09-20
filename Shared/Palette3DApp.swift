import PaletteKit
import SwiftUI
import SwiftData

@main
struct Palette3DApp: App {

    /// A single shared container so every window (including the visionOS volume) reads the same store.
    private let container: ModelContainer

    @State private var showingEvent = false

    init() {
        // A screenshot run gets a throwaway seeded store; every other launch keeps the real library.
        if ScreenshotMode.isActive {
            container = try! ModelContainer(for: Palette.self,
                                            configurations: ModelConfiguration(isStoredInMemoryOnly: true))
            ScreenshotMode.seed(container.mainContext)
        } else {
            container = try! ModelContainer(for: Palette.self)
        }
    }

    var body: some Scene {
        WindowGroup {
            MainView()
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
                .screenshotModeStatus()
        }
        .modelContainer(container)
        #if os(macOS)
        // The window the app should open at: room for the sphere and its inspector side by side.
        // Screenshots deliberately photograph this same size rather than one of their own.
        .defaultSize(width: 1280, height: 800)
        .commands {
            CommandGroup(replacing: .help) {
                AppLinks()
            }
        }
        #endif

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
