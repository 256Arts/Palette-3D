import Testing

@testable import Palette_Studio

/// A rating prompt that fires too early, twice in one version, or into a screenshot is worse than none.
struct ReviewPromptTests {

    @Test(arguments: [
        (created: 2, last: "", version: "2.0", screenshots: false, expected: false),
        (created: 3, last: "", version: "2.0", screenshots: false, expected: true),
        (created: 9, last: "1.0", version: "2.0", screenshots: false, expected: true),
        (created: 9, last: "2.0", version: "2.0", screenshots: false, expected: false),
        (created: 9, last: "", version: "2.0", screenshots: true, expected: false),
    ])
    func prompts(_ c: (created: Int, last: String, version: String, screenshots: Bool, expected: Bool)) {
        #expect(ReviewPrompt.shouldPrompt(createdCount: c.created, lastPromptedVersion: c.last,
                                          currentVersion: c.version, isScreenshotRun: c.screenshots) == c.expected)
    }
}
