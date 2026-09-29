import Foundation
import PaletteKit

extension ColorMetrics {

    /// The strongest WCAG 2.1 grade a contrast ratio reaches, so a bare number always has a
    /// plain-language peer. The thresholds are the ones the standard sets for text: 4.5 for normal, 3 for
    /// large, and 7 for the enhanced grade.
    static func wcagGrade(_ contrast: Double) -> LocalizedStringResource {
        switch contrast {
        case 7...: "AAA for all text"
        case 4.5...: "AA for all text"
        case 3...: "AA for large text"
        default: "Below AA"
        }
    }
}
