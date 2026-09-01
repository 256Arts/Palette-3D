import PaletteKit
import SwiftData
import SwiftUI

/// Deterministic demo state for App Store screenshots, switched on by the `-screenshotMode` launch
/// argument that `Scripts/screenshots.sh` passes.
///
/// A fresh install has an empty library, so a shot of the palette list would otherwise be the empty
/// state. The seed lands in an *in-memory* store, so a screenshot run neither shows nor disturbs
/// whatever library is on the machine taking the shots.
enum ScreenshotMode {

    /// Whether this launch is a screenshot run. Read once, by `Palette3DApp.init`.
    static var isActive: Bool {
        ProcessInfo.processInfo.arguments.contains("-screenshotMode")
    }

    /// A fixed date for the seed. `handpickedPalettes(on:)` promotes whichever seasonal palette the
    /// date falls in, so without pinning it a June run and a December run would not match.
    private static let seedDate = DateComponents(
        calendar: Calendar(identifier: .gregorian),
        timeZone: TimeZone(identifier: "GMT"),
        year: 2026, month: 6, day: 15).date!

    private static let colorSpace: ColorSpace = .okLch

    /// The generated palette the shots open in the editor. Named here because the UI test looks it up.
    static let featuredPaletteName = "Sunset Study"

    /// Fills `context` with a library worth photographing: one generated palette to open in the
    /// editor, then premades beneath it. Timestamps descend so `PaletteListView`'s `dateModified`
    /// sort keeps the order written here.
    @MainActor
    static func seed(_ context: ModelContext) {
        var stamp = seedDate
        func insert(_ palette: Palette) {
            palette.dateModified = stamp
            stamp -= 60
            context.insert(palette)
        }

        insert(.perfect(name: featuredPaletteName))
        for premade in PaletteKit.Palette.handpickedPalettes(on: seedDate, colorSpace: colorSpace).prefix(8) {
            insert(Palette(premade))
        }
    }
}
