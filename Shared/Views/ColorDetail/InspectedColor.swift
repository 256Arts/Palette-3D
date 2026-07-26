import PaletteKit
import SwiftUI

/// A color opened for inspection that has no palette row behind it — a shade, a complement, or a pair's
/// mix.
///
/// `PaletteColor`'s own `id` is derived from its value, so editing the color inside the sheet would
/// change its identity and re-present the sheet; this carries a stable one instead.
struct InspectedColor: Identifiable {

    var color: PaletteColor
    let id = UUID()

    /// Fails only for a color with no RGB representation, which a resolved swatch never is.
    init?(_ color: Color, colorSpace: ColorSpace) {
        guard let picked = PaletteColor(SystemColor(color), colorSpace: colorSpace) else { return nil }
        self.color = picked
    }
}

extension View {

    /// Presents a derived color's details as a sheet.
    ///
    /// The presented view inspects its *own* ramps through this same modifier, so the sheets stack and
    /// every color on screen stays reachable however many steps in it is.
    ///
    /// `onEdit` reports every edit made inside the sheet, which is what lets a caller that owns the color
    /// — rather than merely deriving it — write the change back to its source.
    func inspectingColor(_ inspected: Binding<InspectedColor?>,
                         colorSpace: ColorSpace,
                         onAdd: ((PaletteColor) -> Void)? = nil,
                         onEdit: ((PaletteColor) -> Void)? = nil) -> some View {
        sheet(item: inspected) { derived in
            ColorDetailsView(
                // Edits write back to the presented color, and reads fall back to the value the sheet was
                // handed — the state is already `nil` while the sheet animates away, and reading it
                // unguarded would trap.
                color: Binding(get: { inspected.wrappedValue?.color ?? derived.color },
                               set: {
                                   inspected.wrappedValue?.color = $0
                                   onEdit?($0)
                               }),
                colorSpace: colorSpace,
                provenance: .derived,
                onAdd: onAdd)
        }
    }
}
