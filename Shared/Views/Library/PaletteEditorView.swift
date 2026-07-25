import PaletteKit
import SwiftUI
import UniformTypeIdentifiers
#if os(macOS)
import AppKit
#endif

struct PaletteEditorView: View {

    @Bindable var palette: Palette

    @State private var exportError: String?
    @State private var showingDiscardConfirmation = false

    @State private var generator = PaletteGenerator()
    @State private var paletteText = ""
    @State private var showingInspector = true
    @State private var selectedDetent: PresentationDetent = .medium

    /// Shared with the color details rows, where formats are pinned.
    @AppStorage(PinnedColorFormats.storageKey) private var pinnedFormats = PinnedColorFormats()

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    #if os(visionOS)
    @Environment(\.openWindow) private var openWindow
    #endif

    #if canImport(UIKit)
    private let isPhone = UIDevice.current.userInterfaceIdiom == .phone
    #else
    private let isPhone = false
    #endif

    /// The inspector is no longer gated on the parameters: a palette that can't be regenerated still has
    /// an analysis to show there.
    private var inspectorPresented: Binding<Bool> {
        Binding(get: { showingInspector }, set: { showingInspector = $0 })
    }

    private var inspector: some View {
        PaletteInspectorView(generator: generator,
                             colors: palette.colors,
                             canEditParameters: palette.canEditParameters)
    }

    private var display: some View {
        DisplayView(
            generator: generator,
            paletteColors: $palette.colors,
            paletteText: $paletteText,
            onManualEdit: markCustomized)
    }

    var body: some View {
        editor
            #if !os(macOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .navigationTitle($palette.name)
            #if !os(visionOS)
            // visionOS has no navigation subtitle; the count is carried by the grid there instead.
            .navigationSubtitle("^[\(palette.colors.count) Colors](inflect: true)")
            #endif
            .toolbar {
                #if os(visionOS)
                ToolbarItem {
                    Button("Open in Volume", systemImage: "cube.transparent") {
                        openWindow(id: "display", value: palette.persistentModelID)
                    }
                }
                #endif
                ToolbarItem(placement: .primaryAction) {
                    Menu("Export", systemImage: "square.and.arrow.up") {
                        exportMenu
                    }
                }
                // Export is the primary action here; keep it in the bar while other items overflow first.
                #if os(iOS) || os(macOS)
                .visibilityPriority(.high)
                #endif

                // Only a customized perfect palette can be reverted to its generated colors.
                if palette.parameters != nil && palette.isCustomized {
                    ToolbarItem(placement: .secondaryAction) {
                        Button("Discard Manual Edits", systemImage: "arrow.uturn.backward") {
                            showingDiscardConfirmation = true
                        }
                        .confirmationDialog("Discard Manual Edits?", isPresented: $showingDiscardConfirmation, titleVisibility: .visible) {
                            Button("Discard & Regenerate", role: .destructive, action: discardManualEdits)
                        } message: {
                            Text("This regenerates the palette from its parameters, discarding your color edits and names.")
                        }
                    }
                }
            }
            .alert("Export Failed", item: $exportError) { _ in
                Button("OK") { }
            } message: { message in
                Text(message)
            }
            .onChange(of: generator.parameters) { _, parameters in
                regenerate(parameters)
            }
            .onAppear(perform: load)
    }

    /// Pinned text formats first, then the rest grouped by gamut, then the file formats. Any entry whose
    /// gamut can't hold every color in the palette is flagged — exporting there would silently clamp.
    @ViewBuilder
    private var exportMenu: some View {
        let colorSpace = generator.parameters.colorSpace
        let clampsSRGB = Gamut.sRGB.clamps(palette.colors, colorSpace: colorSpace)

        Section {
            ForEach(pinnedFormats.formats) { format in
                textShareLink(format, name: format.qualifiedName, colorSpace: colorSpace)
            }
        }

        Section {
            ForEach(Gamut.allCases) { gamut in
                Menu {
                    ForEach(gamut.representations) { representation in
                        let format = ColorFormat(gamut: gamut, representation: representation)
                        textShareLink(format, name: format.name, colorSpace: colorSpace)
                    }
                } label: {
                    FormatLabel(name: gamut.shareMenuTitle,
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

    private func textShareLink(_ format: ColorFormat, name: String, colorSpace: ColorSpace) -> some View {
        ShareLink(item: format.text(palette.colors, colorSpace: colorSpace)) {
            FormatLabel(name: name, isClamped: format.gamut.clamps(palette.colors, colorSpace: colorSpace))
        }
    }

    #if os(macOS)
    private func exportColorList() {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = palette.name
        if let clr = UTType(filenameExtension: "clr") {
            panel.allowedContentTypes = [clr]
        }
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try palette.snapshot().writeCLR(to: url, colorSpace: generator.parameters.colorSpace)
        } catch {
            exportError = error.localizedDescription
        }
    }
    #endif

    @ViewBuilder
    private var editor: some View {
        #if os(visionOS)
        // visionOS has no `.inspector`; place the parameters alongside the display instead.
        HStack(spacing: 0) {
            display
            inspector
                .frame(width: 360)
        }
        #else
        display
            .safeAreaPadding(.bottom, selectedDetent == .height(64) || horizontalSizeClass == .regular || !isPhone ? 0 : 400)
            .inspector(isPresented: inspectorPresented) {
                inspector
                    .presentationDetents([.height(64), .medium, .large], selection: $selectedDetent)
                    .presentationBackgroundInteraction(.enabled)
                    .interactiveDismissDisabled(isPhone)
                    .inspectorColumnWidth(ideal: 360)
            }
            .toolbar {
                // Ungated: closing the inspector on a palette with no parameters would otherwise strand it.
                if !showingInspector {
                    ToolbarItem {
                        Button("Inspector", systemImage: "sidebar.trailing") {
                            showingInspector = true
                        }
                    }
                }
            }
        #endif
    }

    private func load() {
        if let parameters = palette.parameters {
            generator.parameters = parameters
        }
        // Parameters are why you opened the editor; the analysis isn't, so it starts as a sliver.
        selectedDetent = palette.canEditParameters ? .medium : .height(64)
        paletteText = PaletteColor.cssText(palette.colors, colorSpace: generator.parameters.colorSpace, convertedToP3: false)
    }

    private func regenerate(_ parameters: PaletteGenerator.Parameters) {
        guard palette.canEditParameters else { return }

        let colors = generator.generate()
        paletteText = PaletteColor.cssText(colors, colorSpace: parameters.colorSpace, convertedToP3: false)

        // Skip no-op writes (e.g. seeding the generator on appear) so the modified date doesn't churn.
        guard palette.parameters != parameters || palette.colors != colors else { return }
        palette.parameters = parameters
        palette.colors = colors
        palette.dateModified = .now
    }

    private func markCustomized() {
        guard !palette.isCustomized else { return }
        palette.isCustomized = true
        palette.dateModified = .now
    }

    /// Reverts a customized perfect palette to its generated colors, unlocking the parameters inspector.
    /// Generation is deterministic, so this exactly reproduces the original perfect palette.
    private func discardManualEdits() {
        guard palette.parameters != nil else { return }
        palette.isCustomized = false
        let colors = generator.generate()
        palette.colors = colors
        paletteText = PaletteColor.cssText(colors, colorSpace: generator.parameters.colorSpace, convertedToP3: false)
        palette.dateModified = .now
    }
}
