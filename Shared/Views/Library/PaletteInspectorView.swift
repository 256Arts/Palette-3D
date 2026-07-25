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

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            content
        }
    }

    /// A bar the panel draws itself, not a real toolbar. A toolbar renders here only inside a navigation
    /// stack, and nesting one is fatal: the inspector's content stays in the library's typed-path stack
    /// even where it presents as a sheet, and SwiftUI traps comparing the two paths. Sitting above the
    /// panel also keeps it alive at the smallest detent, where the drawer is a sliver.
    @ViewBuilder private var header: some View {
        Group {
            // With no parameters there is nothing to switch, so the title names the panel instead.
            if canEditParameters {
                Picker("Panel", selection: $panel) {
                    ForEach(Panel.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(maxWidth: 320)
            } else {
                Text(Panel.analysis.rawValue)
                    .font(.headline)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity)
        .background(.bar)
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
