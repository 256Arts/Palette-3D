import Foundation

/// When to ask for an App Store rating: once someone has made a few palettes of their own and comes
/// back to the library from one — a moment of finished work, not a launch or a mid-edit interruption.
enum ReviewPrompt {

    static let createdCountKey = "reviewPrompt.palettesCreated"
    static let lastPromptedVersionKey = "reviewPrompt.lastPromptedVersion"

    /// Palettes created (perfect, empty, premade copy, or import) before the first ask.
    static let threshold = 3

    static var currentVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
    }

    /// At most once per app version, never in a screenshot run.
    static func shouldPrompt(createdCount: Int, lastPromptedVersion: String, currentVersion: String = currentVersion, isScreenshotRun: Bool = ScreenshotMode.isActive) -> Bool {
        !isScreenshotRun && createdCount >= threshold && lastPromptedVersion != currentVersion
    }
}
