import PaletteKit
import SwiftUI

/// PaletteKit's handpicked palettes, as a horizontally scrolling gallery — somewhere to start when the
/// library is empty, and a quick way to pull a classic in when it isn't.
///
/// The handpicked list is date-aware: it promotes whichever seasonal palette the day falls in
/// (Valentine's, May the 4th, Pride month, October, December) to the top, and offers the year-round set
/// otherwise.
struct PremadePaletteGallery: View {

    /// Adds a copy of the tapped palette to the library.
    var onSelect: (PaletteKit.Palette) -> Void

    /// Premades land in the same color space as every other import.
    private static let colorSpace = ColorSpace.okLch

    private static let cardWidth: CGFloat = 240
    private static let stripHeight: CGFloat = 56

    /// Resolved once, not read from `body`: unlike `premadePalettes`, the handpicked list isn't memoized
    /// and mints a fresh `id` per palette on every call, which would churn `ForEach`'s identity.
    @State private var palettes: [PaletteKit.Palette] = []

    var body: some View {
        ScrollView(.horizontal) {
            LazyHStack(spacing: 12) {
                ForEach(palettes) { palette in
                    Button {
                        onSelect(palette)
                    } label: {
                        card(palette)
                    }
                    .buttonStyle(.plain)
                }
            }
            .scrollTargetLayout()
            .padding(.horizontal)
            .padding(.vertical, 4)
        }
        .scrollTargetBehavior(.viewAligned)
        .scrollIndicators(.hidden)
        .paletteColorSpace(Self.colorSpace)
        .task {
            palettes = PaletteKit.Palette.handpickedPalettes(colorSpace: Self.colorSpace)
        }
    }

    /// A card is `PaletteStrip` under the palette's name — the same composition as PaletteKit's
    /// `PaletteRow`, but with the strip tall enough to actually judge a palette by.
    private func card(_ palette: PaletteKit.Palette) -> some View {
        VStack(spacing: 0) {
            // No swatch limit: showing the whole palette is the point of a gallery, and at this height
            // even a 64-color strip reads as bands rather than hairlines.
            PaletteStrip(palette, limit: nil)
                .frame(height: Self.stripHeight)
            HStack {
                Text(palette.name)
                    .lineLimit(1)
                Spacer(minLength: 8)
                Text(palette.colors.count, format: .number)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            .font(.subheadline)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .frame(width: Self.cardWidth)
        // The gallery's row is clear, so a card sits straight on the list's grouped background — it takes
        // the row fill to stand apart from it, the same as every palette row above.
        .background(Color.groupedContent)
        .clipShape(.rect(cornerRadius: 12))
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
    }
}

#Preview {
    PremadePaletteGallery { _ in }
}
