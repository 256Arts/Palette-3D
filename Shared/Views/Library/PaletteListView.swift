//
//  PaletteListView.swift
//  Palette 3D
//
//  Root list of saved palettes. Create perfect/empty palettes, or import a `.gpl` (GIMP palette,
//  any platform), `.clr` (macOS), or palette-image file — via the import menu or by dropping onto
//  the list. Also lands palettes arriving from lospec.com's `lospec-palette://` URL scheme.
//

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
                    .draggable(PaletteExport(
                        name: palette.name,
                        colors: palette.colors,
                        colorSpace: palette.parameters?.colorSpace ?? .okLch))
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
                    importGPL(from: url)
                }
            }
            .fileImporter(isPresented: $showingImageImporter, allowedContentTypes: [.image]) { result in
                if case let .success(url) = result {
                    importPaletteImage(from: url)
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

    /// Imports a dropped `.gpl` (any platform), `.clr` (macOS), or palette-image file.
    /// Returns whether anything was imported.
    private func importFiles(_ urls: [URL]) -> Bool {
        var imported = false
        for url in urls {
            switch url.pathExtension.lowercased() {
            case "gpl":
                imported = importGPL(from: url) || imported
            #if os(macOS)
            case "clr":
                if let colors = [PaletteColor](clrFile: url, colorSpace: .okLch), !colors.isEmpty {
                    create(.plain(name: url.deletingPathExtension().lastPathComponent, colors: colors))
                    imported = true
                }
            #endif
            default:
                if UTType(filenameExtension: url.pathExtension)?.conforms(to: .image) == true {
                    imported = importPaletteImage(from: url) || imported
                }
            }
        }
        return imported
    }

    /// Imports a palette-image file (one color per pixel), alerting if it isn't a valid palette image.
    @discardableResult
    private func importPaletteImage(from url: URL) -> Bool {
        guard let colors = [PaletteColor](paletteImageFile: url, colorSpace: .okLch), !colors.isEmpty else {
            showingImageImportError = true
            return false
        }
        create(.plain(name: url.deletingPathExtension().lastPathComponent, colors: colors))
        return true
    }

    /// Fetches and lands a palette from a `lospec-palette://<slug>` URL.
    private func importLospec(from url: URL) async {
        guard let lospec = try? await LospecPalette.fetch(url) else { return }
        let colors = lospec.paletteColors(colorSpace: .okLch)
        guard !colors.isEmpty else { return }
        create(.plain(name: lospec.name, colors: colors))
    }

    @discardableResult
    private func importGPL(from url: URL) -> Bool {
        let didAccess = url.startAccessingSecurityScopedResource()
        defer { if didAccess { url.stopAccessingSecurityScopedResource() } }

        guard let text = try? String(contentsOf: url, encoding: .utf8),
              let palette = GIMPPalette(gpl: text, colorSpace: .okLch), !palette.colors.isEmpty else { return false }
        let name = palette.name ?? url.deletingPathExtension().lastPathComponent
        create(.plain(name: name, colors: palette.colors))
        return true
    }
}

private struct PaletteRow: View {

    let palette: Palette

    private var colorSpace: ColorSpace {
        palette.parameters?.colorSpace ?? .okLch
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
