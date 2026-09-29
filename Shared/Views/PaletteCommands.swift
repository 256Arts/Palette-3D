import PaletteKit
import SwiftUI

/// What the library publishes to the menu bar: its creation and import paths, so a menu item takes the
/// same route as the toolbar's New Palette menu.
struct PaletteLibraryFocus {
    let newPerfectPalette: () -> Void
    let newEmptyPalette: () -> Void
    let importGIMPPalette: () -> Void
    let importPaletteImage: () -> Void
}

/// What an open editor publishes to the menu bar.
struct PaletteEditorFocus {
    let palette: Palette
    let colorSpace: ColorSpace
    @Binding var displayMode: DisplayView.DisplayMode
    @Binding var showingAddColor: Bool
    #if os(macOS)
    let exportColorList: () -> Void
    #endif
}

extension FocusedValues {
    @Entry var paletteLibrary: PaletteLibraryFocus?
    @Entry var paletteEditor: PaletteEditorFocus?
}

/// The library and editor in the menu bar — on the Mac, and in the iPad's menu and ⌘-hold overlay.
/// Every item acts through a focused value, so it disables itself when there's nothing to act on.
struct PaletteCommands: Commands {

    @FocusedValue(\.paletteLibrary) private var library
    @FocusedValue(\.paletteEditor) private var editor
    @Environment(\.openWindow) private var openWindow

    var body: some Commands {
        // ⌘N makes a palette, as it makes a document elsewhere; New Window keeps the Option variant.
        CommandGroup(replacing: .newItem) {
            Button("New Perfect Palette") { library?.newPerfectPalette() }
                .keyboardShortcut("n")
                .disabled(library == nil)
            Button("New Empty Palette") { library?.newEmptyPalette() }
                .disabled(library == nil)
            Button("New Window") { openWindow(id: Palette3DApp.mainWindowID) }
                .keyboardShortcut("n", modifiers: [.command, .option])
            Divider()
            Button("Import GIMP Palette…") { library?.importGIMPPalette() }
                .keyboardShortcut("o")
                .disabled(library == nil)
            Button("Import Palette Image…") { library?.importPaletteImage() }
                .disabled(library == nil)
        }

        CommandGroup(before: .toolbar) {
            ForEach(Array(DisplayView.DisplayMode.allCases.enumerated()), id: \.element) { index, mode in
                Toggle(mode.title, isOn: displayModeBinding(mode))
                    .keyboardShortcut(KeyEquivalent(Character("\(index + 1)")))
                    .disabled(editor == nil)
            }
            Divider()
        }

        // Show/Hide Inspector (⌃⌘I), driven by the editor's own `.inspector` presentation.
        InspectorCommands()

        CommandMenu("Palette") {
            Button("Add Color…") { editor?.showingAddColor = true }
                .keyboardShortcut("n", modifiers: [.command, .shift])
                .disabled(editor == nil)
            if let editor {
                Menu("Export") {
                    #if os(macOS)
                    PaletteExportMenu(palette: editor.palette, colorSpace: editor.colorSpace,
                                      exportColorList: editor.exportColorList)
                    #else
                    PaletteExportMenu(palette: editor.palette, colorSpace: editor.colorSpace)
                    #endif
                }
            } else {
                Menu("Export") { }
                    .disabled(true)
            }
        }
    }

    /// A checkmarked item per mode: turning one on selects it; turning the current one off does nothing.
    private func displayModeBinding(_ mode: DisplayView.DisplayMode) -> Binding<Bool> {
        Binding(
            get: { editor?.displayMode == mode },
            set: { isOn in if isOn { editor?.displayMode = mode } })
    }
}
