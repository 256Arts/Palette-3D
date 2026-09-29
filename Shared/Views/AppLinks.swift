import SwiftUI

/// The app's external links, shared by the iOS toolbar overflow menu and the macOS Help menu.
struct AppLinks: View {

    var body: some View {
        Link(destination: URL(string: "https://www.256arts.com/")!) {
            Label("Developer Website", systemImage: "safari")
        }
        Link(destination: URL(string: "https://www.256arts.com/joincommunity/")!) {
            Label("Join Community", systemImage: "bubble.left.and.bubble.right")
        }
        Link(destination: URL(string: "https://github.com/256Arts/Palette-3D")!) {
            Label("Contribute on GitHub", systemImage: "chevron.left.forwardslash.chevron.right")
        }
    }
}
