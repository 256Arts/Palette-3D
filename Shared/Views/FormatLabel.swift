import SwiftUI

/// An export format's name, flagged when writing the color (or the whole palette) in that format clamps
/// it into gamut.
///
/// The warning takes the label's *icon* slot rather than decorating the title, because these labels are
/// mostly rendered inside `Menu`s, which keep only a label's title and image. A format with its own icon
/// gives that slot up while it's clamped — the warning is the more important of the two.
struct FormatLabel: View {

    let name: String
    let isClamped: Bool
    var systemImage: String?

    var body: some View {
        if isClamped {
            Label(name, systemImage: "exclamationmark.triangle.fill")
        } else if let systemImage {
            Label(name, systemImage: systemImage)
        } else {
            Text(name)
        }
    }
}
