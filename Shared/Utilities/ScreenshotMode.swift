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

    // MARK: - Saying what happened

    /// What this launch seeded, in one line, for the walk and for the shared runner.
    ///
    /// A failed walk otherwise reports only "seeded content never appeared", which is equally true
    /// of a store that never seeded, a screen that never opened, and an identifier renamed last
    /// week. The walk reads this out of the accessibility tree before its first shot and prints it
    /// on any miss, and the fixed prefix makes it greppable in the build log.
    @MainActor
    private(set) static var status = "the seed has not run"

    @MainActor
    private static func report(_ line: String) {
        status = line
        print("SCREENSHOT MODE: \(line)")
    }

    /// Whether `context` is the throwaway store this mode promises, checked before the first insert.
    ///
    /// The damage a screenshot run can do is writing demo palettes into the user's own — and by the
    /// time anybody notices, CloudKit has synced them. So the seed stops at the door rather than
    /// afterwards, and says which half of the contract failed.
    @MainActor
    private static func verify(_ context: ModelContext) -> Bool {
        let configurations = context.container.configurations
        let onDisk = configurations.filter { !$0.isStoredInMemoryOnly }
        guard onDisk.isEmpty else {
            report("""
                REFUSED — the container is on disk (\(onDisk.map(\.name).joined(separator: ", "))), \
                so seeding would write demo palettes into real ones. Build it with \
                ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none).
                """)
            return false
        }
        let synced = configurations.filter { $0.cloudKitContainerIdentifier != nil }
        guard synced.isEmpty else {
            report("""
                REFUSED — the container still syncs with CloudKit \
                (\(synced.compactMap(\.cloudKitContainerIdentifier).joined(separator: ", "))), so the \
                real account's palettes would arrive in the store being photographed. Add \
                cloudKitDatabase: .none.
                """)
            return false
        }
        return true
    }

    /// Fills `context` with a library worth photographing: one generated palette to open in the
    /// editor, then premades beneath it. Timestamps descend so `PaletteListView`'s `dateModified`
    /// sort keeps the order written here.
    @MainActor
    static func seed(_ context: ModelContext) {
        guard verify(context) else { return }

        var stamp = seedDate
        func insert(_ palette: Palette) {
            palette.dateModified = stamp
            stamp -= 60
            context.insert(palette)
        }

        insert(.perfect(name: featuredPaletteName))
        let premades = PaletteKit.Palette.handpickedPalettes(on: seedDate, colorSpace: colorSpace).prefix(8)
        for premade in premades {
            insert(Palette(premade))
        }
        report("ready — in-memory store, no CloudKit; seeded 1 generated palette, \(premades.count) premade palettes")
    }
}

extension View {

    /// Carries `ScreenshotMode.status` into the accessibility tree, where the walk reads it.
    ///
    /// Nothing on a normal launch; on a screenshot run, a one-point transparent label — present to
    /// XCUITest, invisible in the shot. It is how the walk can tell a seed that never ran from a
    /// screen that never opened, neither of which the app can report any other way: a simulator
    /// app's `print` does not reach the build log, and there is no file path both the app and the
    /// runner can write.
    @ViewBuilder
    func screenshotModeStatus() -> some View {
        if ScreenshotMode.isActive {
            overlay(alignment: .topLeading) {
                Text(ScreenshotMode.status)
                    .font(.system(size: 1))
                    .opacity(0.001)
                    .accessibilityIdentifier("ScreenshotMode.Status")
                    .allowsHitTesting(false)
            }
        } else {
            self
        }
    }
}
