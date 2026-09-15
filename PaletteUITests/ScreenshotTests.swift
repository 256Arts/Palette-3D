import XCTest

/// Drives the app through the screens that become App Store screenshots and attaches each one to the
/// result bundle, where `Scripts/screenshots.sh` extracts them.
///
/// One test rather than one per screen: the shots are a walk through a single launch, and splitting
/// them would pay the launch — and the reseed — every time.
@MainActor
final class ScreenshotTests: XCTestCase {

    private var app: XCUIApplication!

    func testCaptureAppStoreScreenshots() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-screenshotMode"]
        app.launch()

        #if os(macOS)
        openWindowIfNeeded()
        #endif

        // The library is the landing tab, so it is ready as soon as a seeded row exists.
        let featuredRow = control("PaletteRow.Sunset Study")
        XCTAssertTrue(featuredRow.waitForExistence(timeout: 30), "seeded library never appeared")
        settle()
        capture("01-library")

        activate(control("Pairs"), "Pairs tab")
        settle(seconds: 4)   // the ramps come back from an offscreen WKWebView, not from SwiftUI
        capture("04-pairs")

        activate(control("Color"), "Color tab")
        settle()
        capture("05-color")

        activate(control("Palettes"), "Palettes tab")
        activate(control("PaletteRow.Sunset Study"), "featured palette row")
        settle(seconds: 4)   // the sphere is RealityKit; give it frames to draw
        capture("02-editor-sphere")

        activate(control("Grid"), "Grid display mode")
        settle()
        capture("03-editor-grid")
    }

    #if os(macOS)
    /// Opens a window when the launch came up without one.
    ///
    /// `XCUIApplication.launch()` launches a Mac app in the *background*, and AppKit gives a
    /// background launch no window — it holds it until the user arrives. The app comes up as a menu
    /// bar and nothing else, every lookup in the walk comes back empty, and the run dies on the
    /// first wait with the seed sitting in a store no window is showing. `activate()` is not what
    /// AppKit waits for: only a reopen, the event a Dock icon click sends, builds the window, and a
    /// test runner has no way to send one — so the walk asks for the window itself, with the app's
    /// own New Window.
    ///
    /// Whether a launch gets away without this depends on who started the run: LaunchServices
    /// activates a launched app only while the process that launched it is frontmost, so the same
    /// walk comes up with a window when it is run by hand from a frontmost Terminal and with
    /// nothing but a menu bar when an agent runs it in the background.
    ///
    /// Waiting first rather than counting windows straight after `launch()`, which returns on idle
    /// and can beat the window into the accessibility tree — ⌘N would then open a second, empty one
    /// and the walk would photograph that.
    private func openWindowIfNeeded() {
        if app.windows.firstMatch.waitForExistence(timeout: 10) { return }
        app.typeKey("n", modifierFlags: .command)
        XCTAssertTrue(app.windows.firstMatch.waitForExistence(timeout: 15),
                      "the app launched with no window and ⌘N opened none")
    }
    #endif

    // MARK: - Driving

    /// Tabs and toolbar segments surface as different element types per platform, so look through the
    /// types that can actually be activated rather than guessing one.
    private func control(_ label: String) -> XCUIElement {
        for query in [app.buttons, app.radioButtons, app.descendants(matching: .tab)] {
            let element = query[label]
            if element.exists { return element }
        }
        return app.buttons[label]   // nothing matched; let the caller's assertion name the miss
    }

    private func activate(_ element: XCUIElement, _ description: String) {
        XCTAssertTrue(element.waitForExistence(timeout: 15), "never found \(description)")
        #if os(macOS)
        element.click()
        #else
        element.tap()
        #endif
    }

    /// Animations and async content have no element to wait on, so the shots pause instead.
    private func settle(seconds: TimeInterval = 2) {
        Thread.sleep(forTimeInterval: seconds)
    }

    // MARK: - Capturing

    private func capture(_ name: String) {
        // Every capture below photographs the whole screen, or the frontmost window — never this
        // app in particular. So an app that has lost the foreground yields another app's UI, filed
        // under this app's name, at the right size, with nothing to notice. The shared runner holds
        // a machine-wide lock so that cannot happen; this is the check that it held.
        XCTAssertEqual(app.state, .runningForeground,
                       "\(name): the app under test was not frontmost — another app has this device")
        #if os(macOS)
        captureWindow(named: name)
        #else
        // The simulator's screen already *is* the store's canvas, at the exact required pixel size.
        attach(XCTAttachment(screenshot: XCUIScreen.main.screenshot()), named: name)
        #endif
    }

    private func attach(_ attachment: XCTAttachment, named name: String) {
        attachment.name = name
        attachment.lifetime = .keepAlways   // attachments on a passing test are discarded otherwise
        add(attachment)
    }

    #if os(macOS)

    /// Asks the shell running the tests to photograph the window, and waits for it.
    ///
    /// The good capture is `screencapture -l`, which reads the window's own buffer: correctly masked
    /// to the rounded corners, with real alpha and the system's own shadow. (`XCUIElement.screenshot()`
    /// crops the *screen* to the window's frame, so it loses the shadow — drawn outside that frame —
    /// and leaves desktop inside the corners.) But `screencapture` needs Screen Recording, which the
    /// test runner has no grant for and the terminal running `Scripts/screenshots.sh` does. So the
    /// test drives the UI and the script takes the picture.
    ///
    /// They meet in a plain directory under /tmp. That works only because the runner is deliberately
    /// unsandboxed (PaletteUITests/PaletteUITests.entitlements): a sandboxed runner cannot write /tmp,
    /// and its own container is unreadable to the script, so the two would have nowhere to meet.
    private static let handshakeDirectory = URL(fileURLWithPath: "/tmp/app-store-screenshots")

    private func captureWindow(named name: String) {
        let files = FileManager.default
        let handshake = Self.handshakeDirectory
        let done = handshake.appendingPathComponent("done-\(name)")
        try? files.removeItem(at: done)

        let request = handshake.appendingPathComponent("request-\(name)")
        guard files.createFile(atPath: request.path, contents: nil) else {
            return XCTFail("could not write a capture request to \(request.path)")
        }

        let deadline = Date().addingTimeInterval(30)
        while Date() < deadline {
            if files.fileExists(atPath: done.path) { return }
            Thread.sleep(forTimeInterval: 0.1)
        }
        XCTFail("timed out waiting for the script to capture \(name) — is Scripts/screenshots.sh watching \(handshake.path)?")
    }

    #endif
}
