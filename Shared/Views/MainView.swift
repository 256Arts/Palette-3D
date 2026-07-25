import PaletteKit
import SwiftUI

/// The app's root: the palette library, the two-color comparison, and one scratch color to inspect.
///
/// Each tab owns its own `NavigationStack`, so the tab bar stays put while a palette pushes its editor.
struct MainView: View {

    /// Named rather than inferred from position so `onExternalImport` can name the tab it needs forward.
    private enum Screen {
        case palettes, pairs, color
    }

    @State private var selection: Screen = .palettes

    /// The Color tab's scratch color, held here rather than in the tab so switching away and back doesn't
    /// reset it. It belongs to no palette, which is what `.scratch` tells the details view.
    @State private var scratchColor = PaletteColor(lightnessFraction: 0.6,
                                                   chromaFraction: 0.5,
                                                   hueAngle: .degrees(30))

    var body: some View {
        TabView(selection: $selection) {
            Tab("Palettes", systemImage: "circle.hexagonpath", value: .palettes) {
                PaletteListView(onExternalImport: { selection = .palettes })
            }
            Tab("Pairs", systemImage: "circle.grid.2x1", value: .pairs) {
                PairsView()
            }
            Tab("Color", systemImage: "circle", value: .color) {
                ColorDetailsView(color: $scratchColor, colorSpace: .okLch, provenance: .scratch)
            }
        }
        // Three tabs is a tab bar on iPhone, but a sidebar is the native shape for the same three
        // destinations on macOS and iPad.
        .tabViewStyle(.sidebarAdaptable)
    }
}

#Preview {
    MainView()
        .modelContainer(for: Palette.self, inMemory: true)
}
