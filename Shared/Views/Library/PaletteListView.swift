//
//  PaletteListView.swift
//  Palette 3D
//
//  Root list of saved palettes. Create perfect/empty palettes, or import a `.gpl` (GIMP palette,
//  any platform) or `.clr` (macOS) file — via the import menu or by dropping onto the list.
//

import SwiftUI
import SwiftData

struct PaletteListView: View {

    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityAssistiveAccessEnabled) private var isAssistiveAccessEnabled
    @Query(sort: \Palette.dateModified, order: .reverse) private var palettes: [Palette]

    @State private var path: [Palette] = []
    @State private var showingDuo = false
    @State private var showingGPLImporter = false

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
                    ContentUnavailableView("No Palettes", systemImage: "swatchpalette", description: Text("Create a palette, or import a .gpl file."))
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

    /// Imports a dropped `.gpl` (any platform) or `.clr` (macOS) file. Returns whether anything was imported.
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
                break
            }
        }
        return imported
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
