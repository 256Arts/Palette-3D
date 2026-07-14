import PaletteKit
import SwiftUI

#if canImport(AppKit)
typealias SystemColor = NSColor
#else
typealias SystemColor = UIColor
#endif

struct DisplayView: View {
    
    enum DisplayMode: Identifiable {
        case grid, sphere, text
        
        var id: Self { self }
    }
    
    @Bindable var generator: PaletteGenerator
    @Binding var paletteColors: [PaletteColor]
    @Binding var paletteText: String

    /// Called when the user manually edits colors (e.g. via the text editor), so the palette can lock its parameters.
    var onManualEdit: () -> Void = {}

    @State var displayMode: DisplayMode = .sphere
    @State var canShowTextInputWarning = true
    @State var showingTextInputWarning = false
    @State private var editingColorIndex: Int?
    @State private var showingAddColor = false
    @FocusState var textIsFocused: Bool
    
    private var displayModePlacement: ToolbarItemPlacement {
        #if os(macOS)
        .principal
        #else
        .bottomBar
        #endif
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

    private func reorderColors(_ difference: ReorderDifference<PaletteColor.ID, ReorderableSingleCollectionIdentifier>) {
        difference.apply(to: &paletteColors)
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
                    onAdd: { showingAddColor = true },
                    onDropColors: addColors,
                    onDelete: { deleteColor(at: $0) },
                    onReorder: reorderColors)
            case .sphere:
                PaletteSphereView(
                    colors: paletteColors,
                    colorSpace: generator.parameters.colorSpace,
                    chromaMultiplier: generator.parameters.chromaMultiplier,
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
        .toolbar {
            ToolbarItem(placement: displayModePlacement) {
                Picker("Display Mode", selection: $displayMode) {
                    Image(systemName: "rotate.3d")
                        .tag(DisplayMode.sphere)
                    Image(systemName: "square.grid.3x3")
                        .tag(DisplayMode.grid)
                    Image(systemName: "text.alignleft")
                        .tag(DisplayMode.text)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }
            #if !os(visionOS)
            // visionOS toolbar items have no shared background to hide.
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
                    onDelete: {
                        deleteColor(at: index)
                        editingColorIndex = nil
                    })
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
        DisplayView(generator: PaletteGenerator(), paletteColors: .constant([]), paletteText: .constant(""))
    }
}
