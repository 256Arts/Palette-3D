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

    /// The pasteboard's plain text, if it holds any. Reading it may ask the user to allow the paste, so
    /// only an explicit Paste command should call it.
    static var pasteboardText: String? {
        #if canImport(AppKit)
        NSPasteboard.general.string(forType: .string)
        #else
        UIPasteboard.general.string
        #endif
    }
}
