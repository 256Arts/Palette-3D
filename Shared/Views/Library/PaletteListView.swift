import PaletteKit
import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct PaletteListView: View {

    /// Called when a palette arrives from outside the app, so the root can bring this tab forward — an
    /// import that lands behind another tab would otherwise push its editor where nobody can see it.
    var onExternalImport: () -> Void = {}

    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityAssistiveAccessEnabled) private var isAssistiveAccessEnabled
    @Query(sort: \Palette.dateModified, order: .reverse) private var palettes: [Palette]

    @State private var path: [Palette] = []
    @State private var showingGPLImporter = false
    @State private var showingImageImporter = false
    @State private var showingImageImportError = false

    var body: some View {
        NavigationStack(path: $path) {
            List {
                ForEach(palettes) { palette in
                    NavigationLink(value: palette) {
                        PaletteRow(palette: palette)
                    }
                    #if os(macOS)
                    .draggable(PaletteColorListExport(palette: palette.snapshot(), colorSpace: palette.colorSpace))
                    #endif
                }
                .onDelete(perform: delete)

                // In the list rather than an overlay, so it can't blanket the gallery below — which is
                // exactly what an empty library most needs to reach.
                if palettes.isEmpty {
                    ContentUnavailableView("No Palettes", systemImage: "swatchpalette", description: Text("Start from a premade palette below, create your own, or import a .gpl file or palette image."))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                }

                Section {
                    PremadePaletteGallery(onSelect: add)
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                } header: {
                    Text("Premade Palettes")
                } footer: {
                    Text("Tap one to add a copy to your library.")
                }
            }
            .navigationTitle("Palettes")
            .navigationDestination(for: Palette.self) { palette in
                PaletteEditorView(palette: palette)
            }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Menu("New Palette", systemImage: "plus") {
                        Button("Perfect Palette", systemImage: "sparkles") {
                            create(.perfect())
                        }
                        Button("Empty Palette", systemImage: "square.dashed") {
                            create(.plain(name: "Palette"))
                        }
                        Divider()
                        Button("Import GIMP Palette…", systemImage: "square.and.arrow.down") {
                            showingGPLImporter = true
                        }
                        Button("Import Palette Image…", systemImage: "photo") {
                            showingImageImporter = true
                        }
                    }
                }

                #if !os(visionOS)
                ToolbarSpacer(.fixed)
                #endif

                #if !os(macOS)
                if !isAssistiveAccessEnabled {
                    // App-level links live on the root screen, not inside each palette editor.
                    // (On macOS they live in the Help menu instead.)
                    ToolbarOverflowMenu {
                        AppLinks()
                    }
                }
                #endif
            }
            .fileImporter(isPresented: $showingGPLImporter, allowedContentTypes: [.gimpPalette]) { result in
                if case let .success(url) = result {
                    importFiles([url])
                }
            }
            .fileImporter(isPresented: $showingImageImporter, allowedContentTypes: [.image]) { result in
                if case let .success(url) = result {
                    importFiles([url])
                }
            }
            .alert("Failed To Load Palette", isPresented: $showingImageImportError) {
            } message: {
                Text("Palette images must have a height of 1px, and not contain clear pixels.")
            }
            .onOpenURL { url in
                guard LospecPalette.canHandle(url) else { return }
                Task { await importLospec(from: url) }
            }
            #if os(macOS)
            .dropDestination(for: URL.self) { urls, _ in
                importFiles(urls)
            }
            #endif
        }
    }

    private func create(_ palette: Palette) {
        modelContext.insert(palette)
        path.append(palette)
    }

    /// Lands a premade as the user's own plain palette — a copy they can edit freely, like any import.
    private func add(_ premade: PaletteKit.Palette) {
        create(Palette(premade))
    }

    private func delete(_ offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(palettes[index])
        }
    }

    /// Imports dropped or picked palette files — `.gpl`, `.clr` (macOS), or palette images. PaletteKit
    /// picks the parser, so the app doesn't switch on the extension. Returns whether anything landed.
    @discardableResult
    private func importFiles(_ urls: [URL]) -> Bool {
        var imported = false
        for url in urls {
            guard let palette = PaletteKit.Palette(file: url, colorSpace: .okLch), !palette.colors.isEmpty else {
                // Only an image that failed can be a *malformed* palette; other files simply aren't palettes.
                if UTType(filenameExtension: url.pathExtension)?.conforms(to: .image) == true {
                    showingImageImportError = true
                }
                continue
            }
            create(Palette(palette))
            imported = true
        }
        return imported
    }

    /// Fetches and lands a palette from a `lospec-palette://<slug>` URL.
    private func importLospec(from url: URL) async {
        guard let palette = try? await PaletteKit.Palette.lospec(url, colorSpace: .okLch), !palette.colors.isEmpty else { return }
        onExternalImport()
        create(Palette(palette))
    }
}

private struct PaletteRow: View {

    let palette: Palette

    private var colorSpace: ColorSpace {
        palette.colorSpace
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(palette.name)
                if !palette.isCustomized, palette.parameters != nil {
                    Image(systemName: "sparkles")
                        .foregroundStyle(.secondary)
                }
                if !palette.colors.isEmpty {
                    let gamut = Gamut.containing(palette.colors, colorSpace: colorSpace)
                    Text(gamut.rawValue)
                        .font(.caption2.weight(.semibold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background {
                            Capsule()
                                .stroke(.secondary)
                        }
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text("\(palette.colors.count)")
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            HStack(spacing: 2) {
                ForEach(palette.colors.prefix(16)) { color in
                    RoundedRectangle(cornerRadius: 3)
                        .fill(color.color(colorSpace: colorSpace))
                        .frame(height: 16)
                }
            }
        }
        .padding(.vertical, 2)
    }
}

#Preview {
    PaletteListView()
        .modelContainer(for: Palette.self, inMemory: true)
}
