import PaletteKit
import SwiftUI

/// A swatch that opens its color's full details.
///
/// It stands in for a `ColorPicker` wherever the color deserves more than a picker: the sheet holds a
/// picker of its own, plus every format, the ramps, and the image/pasteboard imports — and edits made
/// there write straight back through the binding, so nothing is lost by the swap.
struct ColorDetailsButton: View {

    let title: LocalizedStringKey
    @Binding var color: Color
    let colorSpace: ColorSpace

    /// The swatch, sized like a `ColorPicker`'s, inside a full-size tap target.
    private static let diameter: CGFloat = 28

    @State private var details: InspectedColor?

    var body: some View {
        Button {
            details = InspectedColor(color, colorSpace: colorSpace)
        } label: {
            Circle()
                .fill(color)
                .frame(width: Self.diameter, height: Self.diameter)
                .overlay(Circle().strokeBorder(.white, lineWidth: 2))
                .shadow(radius: 2)
                .frame(width: 44, height: 44)
                .contentShape(.circle)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(title))
        .draggable(color)
        .dropDestination(for: Color.self) { dropped, _ in
            guard let first = dropped.first else { return false }
            color = first
            return true
        }
        .inspectingColor($details, colorSpace: colorSpace) { color = $0.color(colorSpace: colorSpace) }
    }
}

#Preview {
    @Previewable @State var color = Color.purple
    ColorDetailsButton(title: "Color", color: $color, colorSpace: .okLch)
}
