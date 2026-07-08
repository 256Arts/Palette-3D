//
//  PaletteListView.swift
//  Palette 3D
//
//  Root list of saved palettes. Create perfect/empty palettes, or drop a `.clr` file to import (macOS).
//

import SwiftUI
import SwiftData

struct PaletteListView: View {

    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityAssistiveAccessEnabled) private var isAssistiveAccessEnabled
    @Query(sort: \Palette.dateModified, order: .reverse) private var palettes: [Palette]

    @State private var path: [Palette] = []
    @State private var showingDuo = false

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
                    ContentUnavailableView("No Palettes", systemImage: "swatchpalette", description: Text("Create a palette, or drop a .clr file here."))
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
            #if os(macOS)
            .dropDestination(for: URL.self) { urls, _ in
                importCLR(urls)
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

    #if os(macOS)
    private func importCLR(_ urls: [URL]) -> Bool {
        guard let url = urls.first(where: { $0.pathExtension.lowercased() == "clr" }),
              let colors = [PaletteColor](clrFile: url, colorSpace: .okLch), !colors.isEmpty else { return false }
        create(.plain(name: url.deletingPathExtension().lastPathComponent, colors: colors))
        return true
    }
    #endif
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
