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
            switch selection {
            case .parameters:
                ParametersView(generator: generator)
            case .analysis:
                PaletteAnalysisView(colors: colors, colorSpace: generator.parameters.colorSpace)
            }
        }
    }

    /// Above the panel rather than inside it, so it survives the smallest detent — where the drawer is a
    /// sliver, and that sliver is then still a control rather than a blank edge.
    @ViewBuilder private var header: some View {
        Group {
            if canEditParameters {
                Picker("Panel", selection: $panel) {
                    ForEach(Panel.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            } else {
                Text(Panel.analysis.rawValue)
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
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
