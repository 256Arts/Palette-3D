//
//  PaletteEditorView.swift
//  Palette 3D
//
//  Edits one saved palette. Perfect palettes expose the generator parameters until the user
//  customizes a color, after which generation is locked to preserve their edits.
//

import SwiftUI
import UniformTypeIdentifiers
#if os(macOS)
import AppKit
#endif

struct PaletteEditorView: View {

    @Bindable var palette: Palette

    @State private var exportError: String?
    @State private var showingDiscardConfirmation = false
    @State private var showingAnalysis = false

    @State private var generator = PaletteGenerator()
    @State private var paletteText = ""
    @State private var showingInspector = true
    @State private var selectedDetent: PresentationDetent = .medium

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    #if os(visionOS)
    @Environment(\.openWindow) private var openWindow
    #endif

    #if canImport(UIKit)
    private let isPhone = UIDevice.current.userInterfaceIdiom == .phone
    #else
    private let isPhone = false
    #endif

    private var inspectorPresented: Binding<Bool> {
        Binding(get: { showingInspector && palette.canEditParameters }, set: { showingInspector = $0 })
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
            .navigationSubtitle("^[\(palette.colors.count) Colors](inflect: true)")
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
                        ForEach(Gamut.allCases) { gamut in
                            Menu(gamut.shareMenuTitle, systemImage: "square.and.arrow.up") {
                                ForEach(gamut.representations) { representation in
                                    ShareLink(representation.name,
                                              item: PaletteColor.text(palette.colors, representation: representation, colorSpace: generator.parameters.colorSpace, gamut: gamut))
                                }
                            }
                        }
                        ShareLink(item: GIMPPaletteExport(name: palette.name, colors: palette.colors, colorSpace: generator.parameters.colorSpace),
                                  preview: SharePreview("\(palette.name).gpl")) {
                            Label("GIMP Palette File", systemImage: "swatchpalette")
                        }
                        ShareLink(item: PaletteImageExport(name: palette.name, colors: palette.colors, colorSpace: generator.parameters.colorSpace),
                                  preview: SharePreview("\(palette.name).png")) {
                            Label("Palette Image", systemImage: "photo")
                        }
                        #if os(macOS)
                        Button("Save as Color List…", systemImage: "swatchpalette") {
                            exportColorList()
                        }
                        #endif
                    }
                }
                // Export is the primary action here; keep it in the bar while other items overflow first.
                #if os(iOS) || os(macOS)
                .visibilityPriority(.high)
                #endif

                ToolbarItem(placement: .secondaryAction) {
                    Button("Analyze", systemImage: "chart.bar.xaxis") {
                        showingAnalysis = true
                    }
                    .disabled(palette.colors.count < 2)
                }

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
            .sheet(isPresented: $showingAnalysis) {
                PaletteAnalysisView(colors: palette.colors, colorSpace: generator.parameters.colorSpace)
            }
            .onChange(of: generator.parameters) { _, parameters in
                regenerate(parameters)
            }
            .onAppear(perform: load)
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
            try palette.colors.writeCLR(to: url, named: palette.name, colorSpace: generator.parameters.colorSpace)
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
            if palette.canEditParameters {
                ParametersView(generator: generator)
                    .frame(width: 360)
            }
        }
        #else
        display
            .safeAreaPadding(.bottom, selectedDetent == .height(64) || horizontalSizeClass == .regular || !isPhone ? 0 : 400)
            .inspector(isPresented: inspectorPresented) {
                ParametersView(generator: generator)
                    .presentationDetents([.height(64), .medium, .large], selection: $selectedDetent)
                    .presentationBackgroundInteraction(.enabled)
                    .interactiveDismissDisabled(isPhone)
                    .inspectorColumnWidth(ideal: 360)
            }
            .toolbar {
                if palette.canEditParameters && !showingInspector {
                    ToolbarItem {
                        Button("Parameters", systemImage: "sidebar.trailing") {
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
