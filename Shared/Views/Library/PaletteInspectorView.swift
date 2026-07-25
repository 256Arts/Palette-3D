import PaletteKit
import SwiftUI

/// The editor's trailing panel. A perfect palette switches between the parameters that generate it and
/// the analysis of the result; every other palette has only the analysis, so there is nothing to switch
/// and the panel is simply titled.
struct PaletteInspectorView: View {

    private enum Panel: String, CaseIterable, Identifiable {
        case parameters = "Parameters"
        case analysis = "Analysis"
        var id: Self { self }
    }

    @Bindable var generator: PaletteGenerator
    let colors: [PaletteColor]
    /// Whether the generator still owns the colors. Once the palette is customized it doesn't, and the
    /// parameters panel goes away with it.
    let canEditParameters: Bool

    @State private var panel: Panel = .parameters

    private var selection: Panel { canEditParameters ? panel : .analysis }

    /// The panel carries its own navigation bar so the switcher can sit in the middle of it. On iPhone the
    /// inspector is a sheet, where a toolbar exists only inside a navigation stack.
    var body: some View {
        NavigationStack {
            content
                .navigationTitle(canEditParameters ? "" : Panel.analysis.rawValue)
                #if !os(macOS)
                .navigationBarTitleDisplayMode(.inline)
                #endif
                .toolbar {
                    // With no parameters there is nothing to switch, so the title names the panel instead.
                    if canEditParameters {
                        ToolbarItem(placement: .principal) {
                            Picker("Panel", selection: $panel) {
                                ForEach(Panel.allCases) { Text($0.rawValue).tag($0) }
                            }
                            .pickerStyle(.segmented)
                            .labelsHidden()
                        }
                    }
                }
        }
    }

    @ViewBuilder private var content: some View {
        switch selection {
        case .parameters:
            ParametersView(generator: generator)
        case .analysis:
            PaletteAnalysisView(colors: colors, colorSpace: generator.parameters.colorSpace)
        }
    }
}

#Preview {
    PaletteInspectorView(
        generator: PaletteGenerator(),
        colors: [
            PaletteColor(lightnessFraction: 0.6, chromaFraction: 0.5, hueAngle: .degrees(30), name: "Coral"),
            PaletteColor(lightnessFraction: 0.5, chromaFraction: 0.4, hueAngle: .degrees(200)),
        ],
        canEditParameters: true)
}
