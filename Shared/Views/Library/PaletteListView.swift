import PaletteKit
import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct PaletteListView: View {

    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityAssistiveAccessEnabled) private var isAssistiveAccessEnabled
    @Query(sort: \Palette.dateModified, order: .reverse) private var palettes: [Palette]

    @State private var path: [Palette] = []
    @State private var showingDuo = false
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
            }
            .navigationTitle("Palettes")
            .navigationDestination(for: Palette.self) { palette in
                PaletteEditorView(palette: palette)
            }
            .overlay {
                if palettes.isEmpty {
                    ContentUnavailableView("No Palettes", systemImage: "swatchpalette", description: Text("Create a palette, or import a .gpl file or palette image."))
                }
            }
            .sheet(isPresented: $showingDuo) {
                DuoView()
            }
            .toolbar {
                ToolbarItem {
                    Button("Duo", systemImage: "swirl.circle.righthalf.filled") {
                        showingDuo = true
                    }
                }
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

                #if !os(macOS)
                if !isAssistiveAccessEnabled {
                    // App-level links live on the root screen, not inside each palette editor.
                    ToolbarOverflowMenu {
                        Link(destination: URL(string: "https://www.256arts.com/")!) {
                            Label("Developer Website", systemImage: "safari")
                        }
                        Link(destination: URL(string: "https://www.256arts.com/joincommunity/")!) {
                            Label("Join Community", systemImage: "bubble.left.and.bubble.right")
                        }
                        Link(destination: URL(string: "https://github.com/256Arts/Palette-3D")!) {
                            Label("Contribute on GitHub", systemImage: "chevron.left.forwardslash.chevron.right")
                        }
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
