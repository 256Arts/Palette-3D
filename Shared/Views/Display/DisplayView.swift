import PaletteKit
import SwiftUI

#if canImport(AppKit)
typealias SystemColor = NSColor
#else
typealias SystemColor = UIColor
#endif

struct DisplayView: View {
    
    /// Declared in the order the picker and the View menu show them.
    enum DisplayMode: CaseIterable, Identifiable {
        case sphere, grid, text

        var id: Self { self }

        var title: LocalizedStringKey {
            switch self {
            case .sphere: "Sphere"
            case .grid: "Grid"
            case .text: "Text"
            }
        }

        var systemImage: String {
            switch self {
            case .sphere: "rotate.3d"
            case .grid: "square.grid.3x3"
            case .text: "text.alignleft"
            }
        }
    }
    
    @Bindable var generator: PaletteGenerator
    @Binding var paletteColors: [PaletteColor]
    @Binding var paletteText: String
    /// Owned by the editor, so its menu bar commands can switch modes and add colors too.
    @Binding var displayMode: DisplayMode
    @Binding var showingAddColor: Bool

    /// Called when the user manually edits colors (e.g. via the text editor), so the palette can lock its parameters.
    var onManualEdit: () -> Void = {}

    /// Called as the text editor gains and loses focus, so a whole typing session can be undone as one step.
    var onTextEditingChanged: (Bool) -> Void = { _ in }

    @State var canShowTextInputWarning = true
    @State var showingTextInputWarning = false
    @State private var editingColorIndex: Int?
    @FocusState var textIsFocused: Bool
    
    #if !os(visionOS)
    private var displayModePlacement: ToolbarItemPlacement {
        #if os(macOS)
        .principal
        #else
        .bottomBar
        #endif
    }
    #endif

    private var displayModePicker: some View {
        Picker("Display Mode", selection: $displayMode) {
            ForEach(DisplayMode.allCases) { mode in
                Image(systemName: mode.systemImage)
                    .accessibilityLabel(mode.title)
                    .tag(mode)
            }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
    }

    /// Two-way binding to a stored `PaletteColor`, for the details sheet.
    private func colorValueBinding(_ index: Int) -> Binding<PaletteColor> {
        Binding(
            get: { paletteColors.indices.contains(index) ? paletteColors[index] : PaletteColor(lightnessFraction: 0.5, chromaFraction: 0, hueAngle: .zero) },
            set: { newValue in
                guard paletteColors.indices.contains(index) else { return }
                paletteColors[index] = newValue
                onManualEdit()
            })
    }

    private func appendColor(_ color: PaletteColor) {
        paletteColors.append(color)
        onManualEdit()
    }

    /// Appends colors dropped in from elsewhere (another swatch, an app, the system color picker).
    private func addColors(_ colors: [Color]) {
        let converted = colors.compactMap { PaletteColor(SystemColor($0), colorSpace: generator.parameters.colorSpace) }
        guard !converted.isEmpty else { return }
        paletteColors.append(contentsOf: converted)
        onManualEdit()
    }

    private func deleteColor(at index: Int) {
        guard paletteColors.indices.contains(index) else { return }
        paletteColors.remove(at: index)
        onManualEdit()
    }

    /// The grid hands back a rebuilt order rather than a `ReorderDifference`, since it cannot name that
    /// OS 27-only type while OS 26 is supported. Once it is dropped this takes the difference again and
    /// calls `ReorderDifference.apply(to: &paletteColors)`, reordering in place.
    private func reorderColors(_ reordered: [PaletteColor]) {
        paletteColors = reordered
        onManualEdit()
    }

    var body: some View {
        VStack {
            switch displayMode {
            case .grid:
                PaletteGridView(
                    colors: paletteColors,
                    colorSpace: generator.parameters.colorSpace,
                    onSelect: { editingColorIndex = $0 },
                    onDropColors: addColors,
                    onDelete: { deleteColor(at: $0) },
                    onReorder: reorderColors)
            case .sphere:
                PaletteSphereView(
                    colors: paletteColors,
                    colorSpace: generator.parameters.colorSpace,
                    onSelect: { editingColorIndex = $0 })
            case .text:
                TextEditor(text: $paletteText)
                    .autocorrectionDisabled()
                    .focused($textIsFocused)
                    #if !os(macOS)
                    .textInputAutocapitalization(.never)
                    #endif
                    .onChange(of: paletteText) { _, newValue in
                        guard textIsFocused else {
                            canShowTextInputWarning = true
                            return
                        }
                        
                        let cssStrings = newValue.components(separatedBy: "\n")
                        paletteColors = cssStrings.compactMap { PaletteColor(css: $0) }
                        onManualEdit()

                        if newValue.contains("lab(") /* Matches lab and oklab */ {
                            showingTextInputWarning = true
                            canShowTextInputWarning = false
                        }
                    }
            }
        }
        #if !os(macOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        #if os(visionOS)
        // A bottom-bar toolbar item sits inside a visionOS window, over the display it switches;
        // an ornament hangs it below the window instead.
        .ornament(attachmentAnchor: .scene(.bottom), contentAlignment: .top) {
            displayModePicker
                .frame(width: 300)
                .padding(12)
                .glassBackgroundEffect()
        }
        #endif
        .toolbar {
            // Adding a color belongs to the palette, not to one way of looking at it, so it stays put
            // across the display modes — including text, where typing a CSS line is the clumsier path.
            ToolbarItem {
                Button("Add Color", systemImage: "plus") { showingAddColor = true }
            }

            #if !os(visionOS)
            // Adding a color is its own action, not one of the display's; visionOS has no spacer to say so.
            ToolbarSpacer(.fixed)
            #endif

            #if !os(visionOS)
            ToolbarItem(placement: displayModePlacement) {
                displayModePicker
            }
            .sharedBackgroundVisibility(.hidden)
            #endif

            #if os(iOS)
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                
                Button("Done", systemImage: "checkmark") {
                    textIsFocused = false
                }
            }
            #endif
        }
        .onChange(of: textIsFocused) { _, isFocused in
            onTextEditingChanged(isFocused)
        }
        .onChange(of: paletteColors) {
            // Keep the CSS text in sync with grid/sphere edits, but don't fight the user while they type.
            if !textIsFocused {
                paletteText = PaletteColor.cssText(paletteColors, colorSpace: generator.parameters.colorSpace, convertedToP3: false)
            }
        }
        .alert("Text Input Not Supported", isPresented: $showingTextInputWarning) {
            Button("OK") { }
        } message: {
            Text("Only Lch and Oklch support text input. Lab, Oklab, and P3 are output only.")
        }
        .sheet(isPresented: editingColorPresented) {
            if let index = editingColorIndex, paletteColors.indices.contains(index) {
                ColorDetailsView(
                    color: colorValueBinding(index),
                    colorSpace: generator.parameters.colorSpace,
                    provenance: .palette,
                    onDelete: {
                        deleteColor(at: index)
                        editingColorIndex = nil
                    },
                    onAdd: appendColor)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
            }
        }
        .sheet(isPresented: $showingAddColor) {
            AddColorView(colorSpace: generator.parameters.colorSpace, onAdd: appendColor)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
    }

    private var editingColorPresented: Binding<Bool> {
        Binding(get: { editingColorIndex != nil }, set: { if !$0 { editingColorIndex = nil } })
    }

}

#Preview {
    NavigationStack {
        DisplayView(generator: PaletteGenerator(), paletteColors: .constant([]), paletteText: .constant(""),
                    displayMode: .constant(.sphere), showingAddColor: .constant(false))
    }
}
