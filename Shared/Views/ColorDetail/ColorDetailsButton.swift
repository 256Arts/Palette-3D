import PaletteKit
import SwiftUI

/// Wraps a view as a button into its color's full details.
///
/// It stands in for a `ColorPicker` wherever the color deserves more than a picker: the sheet holds a
/// picker of its own, plus every format, the contrast readout, the ramps, and the image/pasteboard
/// imports — and edits made there write straight back through the binding, which is what makes this a
/// replacement rather than a read-only preview. The label is the caller's, since a swatch's shape belongs
/// to the screen it sits on.
struct ColorDetailsButton<Label: View>: View {

    let title: LocalizedStringKey
    @Binding var color: Color
    let colorSpace: ColorSpace
    @ViewBuilder let label: Label

    @State private var details: InspectedColor?

    var body: some View {
        Button {
            details = InspectedColor(color, colorSpace: colorSpace)
        } label: {
            label
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
    ColorDetailsButton(title: "Color", color: $color, colorSpace: .okLch) {
        color.frame(height: 64)
    }
    .padding()
}
