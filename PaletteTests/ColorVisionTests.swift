import PaletteKit
import Testing

@testable import Palette_Studio

/// The color vision simulation behind the grid's preview and the analysis panel's Color Vision section.
struct ColorVisionTests {

    private let red = PaletteColor(hex: "#D03030", colorSpace: .okLch)!
    private let green = PaletteColor(hex: "#50A030", colorSpace: .okLch)!

    @Test func normalVisionIsIdentity() {
        #expect(ColorVision.normal.simulate(red, colorSpace: .okLch) == red)
    }

    @Test func achromatopsiaRemovesChroma() {
        let gray = ColorVision.achromatopsia.simulate(red, colorSpace: .okLch)
        #expect(ColorMetrics.sample(gray, colorSpace: .okLch).chroma < 1)
    }

    @Test func simulationKeepsTheName() {
        var named = red
        named.name = "Brick"
        #expect(ColorVision.protanopia.simulate(named, colorSpace: .okLch).name == "Brick")
    }

    /// Red/green is the classic confusion: both red-green deficiencies must pull the pair much closer.
    @Test(arguments: [ColorVision.protanopia, .deuteranopia])
    func redGreenDeficienciesConfuseRedAndGreen(vision: ColorVision) {
        let normal = red.deltaE2000(to: green, colorSpace: .okLch)
        let simulated = vision.simulate(red, colorSpace: .okLch)
            .deltaE2000(to: vision.simulate(green, colorSpace: .okLch), colorSpace: .okLch)
        #expect(simulated < normal / 2)
    }

    @Test func analysisReportsEveryDeficiency() {
        let analysis = PaletteAnalysis(colors: [red, green], colorSpace: .okLch)
        #expect(analysis.visionReports.map(\.vision) == ColorVision.deficiencies)
    }
}
