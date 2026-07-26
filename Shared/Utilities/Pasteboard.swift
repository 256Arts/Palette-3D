#if canImport(AppKit)
import AppKit
#else
import UIKit
#endif

extension String {

    /// Puts the string on the system pasteboard. AppKit and UIKit disagree on the ceremony, and enough
    /// places copy a color, a snippet, or a gradient that it isn't worth restating.
    func copyToPasteboard() {
        #if canImport(AppKit)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(self, forType: .string)
        #else
        UIPasteboard.general.string = self
        #endif
    }
}
