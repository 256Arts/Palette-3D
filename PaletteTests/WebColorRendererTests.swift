import PaletteKit
import SwiftUI
import Testing

@testable import Palette_Studio

/// The shades, complements, and pair bars are all drawn from `WebColorRenderer`, and all of them fail the
/// same silent way: an empty batch leaves the section on screen with nothing in it. These pin the
/// contract they rely on — one color out per color in, in order.
@MainActor
struct WebColorRendererTests {

    /// The `color-mix()` requests a shade ramp makes, in the shape `ShadesView` builds them.
    @Test func resolvesAShadeRamp() async {
        let base = PaletteColor(lightnessFraction: 0.7, chromaFraction: 0.4, hueAngle: .degrees(30))
            .cssString(colorSpace: .okLch, convertedToP3: true)
        let requests = ["oklch", "oklab", "lch", "hsl", "srgb"].flatMap { space in
            [-80.0, -40, 0, 40, 80].map { amount -> String in
                guard amount != 0 else { return base }
                return "color-mix(in \(space), \(amount < 0 ? "white" : "black") \(abs(amount).formatted())%, \(base))"
            }
        }

        let resolved = await WebColorRenderer.shared.resolve(requests)
        #expect(resolved.count == requests.count)
    }

    /// The relative-color-syntax rotations a complement wheel makes.
    @Test func resolvesAComplementWheel() async {
        let requests = (0..<3).map { step in
            "oklch(from oklch(0.7 0.15 30) l c calc(h + 360 * \(step) / 3))"
        }

        let resolved = await WebColorRenderer.shared.resolve(requests)
        #expect(resolved.count == requests.count)
    }

    /// The single-color overload validates, which is what the pasteboard import leans on.
    @Test func resolvesOnlyRealColors() async {
        #expect(await WebColorRenderer.shared.resolve("#ff8800") != nil)
        #expect(await WebColorRenderer.shared.resolve("rebeccapurple") != nil)
        #expect(await WebColorRenderer.shared.resolve("not a color") == nil)
    }
}
