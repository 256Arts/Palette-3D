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
