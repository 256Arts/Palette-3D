import Combine
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
    /// Held here rather than in `DisplayView` so the menu bar's commands can reach them.
    @State private var displayMode: DisplayView.DisplayMode = .sphere
    @State private var showingAddColor = false
    @State private var selectedDetent: PresentationDetent = .medium

    /// The state the last undo step ended at — where the next one starts from.
    @State private var committedState: Palette.EditState?
    /// While the text editor is focused, edits accumulate into one undo step, registered on commit.
    @State private var isEditingText = false
    /// Mirrors the undo manager, which isn't observable, for the Undo/Redo buttons.
    @State private var canUndo = false
    @State private var canRedo = false

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.undoManager) private var undoManager
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
            displayMode: $displayMode,
            showingAddColor: $showingAddColor,
            onManualEdit: palette.markCustomized,
            onTextEditingChanged: { isEditingText = $0 })
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
                #if os(iOS) || os(macOS)
                if #available(iOS 27, macOS 26.1, *) {
                    ToolbarItem(placement: .primaryAction) {
                        Menu("Export", systemImage: "square.and.arrow.up") {
                            exportMenu
                        }
                    }
                    // Export is the primary action here; keep it in the bar while other items overflow first.
                    .visibilityPriority(.high)
                } else {
                    ToolbarItem(placement: .primaryAction) {
                        Menu("Export", systemImage: "square.and.arrow.up") {
                            exportMenu
                        }
                    }
                }
                #else
                ToolbarItem(placement: .primaryAction) {
                    Menu("Export", systemImage: "square.and.arrow.up") {
                        exportMenu
                    }
                }
                #endif

                #if !os(macOS)
                // macOS has Edit ▸ Undo; elsewhere a keyboard or a shake isn't always at hand.
                ToolbarItemGroup(placement: .secondaryAction) {
                    Button("Undo", systemImage: "arrow.uturn.backward") { undoManager?.undo() }
                        .disabled(!canUndo)
                    Button("Redo", systemImage: "arrow.uturn.forward") { undoManager?.redo() }
                        .disabled(!canRedo)
                }
                #endif

                // Only a customized perfect palette can be reverted to its generated colors.
                if palette.parameters != nil && palette.isCustomized {
                    ToolbarItem(placement: .secondaryAction) {
                        Button("Discard Manual Edits", systemImage: "arrow.counterclockwise") {
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
            .onChange(of: palette.parameters) { _, parameters in
                // An undo can restore older parameters; the generator follows, finding nothing to regenerate.
                if let parameters, parameters != generator.parameters {
                    generator.parameters = parameters
                }
            }
            .onChange(of: palette.editState) {
                if !isEditingText { commitUndoStep() }
            }
            .onChange(of: isEditingText) { _, isEditing in
                if !isEditing { commitUndoStep() }
            }
            .onReceive(undoStackChanges) { _ in
                canUndo = undoManager?.canUndo ?? false
                canRedo = undoManager?.canRedo ?? false
            }
            .focusedSceneValue(\.paletteEditor, focus)
            .onAppear(perform: load)
            .onDisappear {
                // Steps outlive the editor on the window's undo manager, where one could land on a
                // palette since deleted from the list.
                undoManager?.removeAllActions(withTarget: palette)
            }
    }

    /// What the menu bar's editor commands act on, while this editor is frontmost in its window.
    private var focus: PaletteEditorFocus {
        #if os(macOS)
        PaletteEditorFocus(palette: palette, colorSpace: generator.parameters.colorSpace,
                           displayMode: $displayMode, showingAddColor: $showingAddColor,
                           exportColorList: exportColorList)
        #else
        PaletteEditorFocus(palette: palette, colorSpace: generator.parameters.colorSpace,
                           displayMode: $displayMode, showingAddColor: $showingAddColor)
        #endif
    }

    private var undoStackChanges: some Publisher<Notification, Never> {
        let center = NotificationCenter.default
        return Publishers.Merge3(
            center.publisher(for: .NSUndoManagerDidCloseUndoGroup, object: undoManager),
            center.publisher(for: .NSUndoManagerDidUndoChange, object: undoManager),
            center.publisher(for: .NSUndoManagerDidRedoChange, object: undoManager))
    }

    private var exportMenu: some View {
        #if os(macOS)
        PaletteExportMenu(palette: palette, colorSpace: generator.parameters.colorSpace, exportColorList: exportColorList)
        #else
        PaletteExportMenu(palette: palette, colorSpace: generator.parameters.colorSpace)
        #endif
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
        committedState = palette.editState
    }

    /// Records everything since the last step — one color edit, one parameter change, or a whole
    /// typing session — as a single undo step. Observing the palette, rather than wrapping each
    /// mutation, catches every edit path in `DisplayView` along with the `isCustomized` it sets.
    private func commitUndoStep() {
        let current = palette.editState
        if let committedState, let undoManager {
            palette.registerUndo(from: committedState, with: undoManager) { restored in
                self.committedState = restored
            }
        }
        committedState = current
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

    private func discardManualEdits() {
        palette.discardManualEdits()
        paletteText = PaletteColor.cssText(palette.colors, colorSpace: palette.colorSpace, convertedToP3: false)
    }
}
