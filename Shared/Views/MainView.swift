import PaletteKit
import SwiftUI

/// The app's root: the palette library, the two-color comparison, and one scratch color to inspect.
///
/// Each tab owns its own `NavigationStack`. The tab bar stays a tab bar at every size — these are three
/// peer destinations, not a hierarchy, and the sidebar adaptation would hand the editor a second column
/// it has no use for — and it hides once a palette pushes its editor, which wants the full width.
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
    }
}

extension View {

    /// Drops ``MainView``'s tab bar for a screen pushed on top of a tab. `.tabBar` doesn't exist on
    /// macOS, where the same three tabs are already window-level and nothing covers them.
    func hidingTabBar() -> some View {
        #if os(macOS)
        self
        #else
        toolbar(.hidden, for: .tabBar)
        #endif
    }
}

#Preview {
    MainView()
        .modelContainer(for: Palette.self, inMemory: true)
}
