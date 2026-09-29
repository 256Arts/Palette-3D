import SwiftUI

/// The two halves of the system's *grouped* look, for the screens that build their own containers instead
/// of using a `List`.
///
/// SwiftUI's `.background` / `.background.secondary` are the plain (ungrouped) pair, and in light mode
/// `.background.secondary` is the very same gray as the grouped page — which reads as an inversion:
/// a white page carrying gray cards, the opposite of every grouped list in the app.
extension Color {

    /// The page behind grouped content: gray in light mode, near-black in dark.
    static var groupedBackground: Color {
        #if canImport(UIKit)
        Color(uiColor: .systemGroupedBackground)
        #else
        Color(nsColor: .windowBackgroundColor)
        #endif
    }

    /// A card or row sitting on ``groupedBackground``: white in light mode, raised gray in dark.
    static var groupedContent: Color {
        #if canImport(UIKit)
        Color(uiColor: .secondarySystemGroupedBackground)
        #else
        Color(nsColor: .controlBackgroundColor)
        #endif
    }
}
