import PaletteKit
import PhotosUI
import SwiftUI

/// One in-flight import of a color from outside the app: the source the user chose, and — once an image
/// has been decoded — the picture waiting under the eyedropper. A screen offering imports holds this one
/// value, hands the menu a binding to it, and lets ``SwiftUI/View/importingColor(_:perform:)`` do the rest.
struct ColorImport {

    /// Where the color is coming from. Only one can be in flight, so this is a single optional rather
    /// than a flag per picker.
    enum Source: String, Identifiable, CaseIterable {
        case camera, photos, files, pasteboard
        var id: String { rawValue }
    }

    /// A decoded image wrapped so it can drive a `.sheet(item:)`.
    struct PickedImage: Identifiable {
        let id = UUID()
        let cgImage: CGImage
    }

    var source: Source?
    var image: PickedImage?
}

/// The menu of ways to bring a color in from outside the app: the camera, the photo library, an image
/// file, or text on the pasteboard.
///
/// It only *chooses*. The pickers are presented by ``SwiftUI/View/importingColor(_:perform:)``, which the
/// screen attaches to its content — a presentation attached to a toolbar item isn't reliably shown.
struct ColorImportMenu: View {

    @Binding var colorImport: ColorImport

    var body: some View {
        Menu {
            #if os(iOS)
            Button("Take Photo", systemImage: "camera") { colorImport.source = .camera }
            #endif
            Button("Choose Photo", systemImage: "photo.on.rectangle") { colorImport.source = .photos }
            Button("Choose File", systemImage: "folder") { colorImport.source = .files }
            Button("Paste Color", systemImage: "clipboard") { colorImport.source = .pasteboard }
        } label: {
            Label("Import Color", systemImage: "eyedropper")
        }
    }
}

extension View {

    /// Presents whichever picker an attached ``ColorImportMenu`` asked for, and hands back the color the
    /// user sampled or pasted. Attach it to a screen's content, not to its toolbar.
    func importingColor(_ colorImport: Binding<ColorImport>, perform: @escaping (Color) -> Void) -> some View {
        modifier(ColorImportModifier(colorImport: colorImport, perform: perform))
    }
}

private struct ColorImportModifier: ViewModifier {

    @Binding var colorImport: ColorImport
    let perform: (Color) -> Void

    @State private var photoItem: PhotosPickerItem?
    /// Raised when the pasteboard holds no color, since a Paste that quietly does nothing reads as a bug.
    @State private var pasteFailed = false

    func body(content: Content) -> some View {
        content
            .photosPicker(isPresented: isPresented(.photos), selection: $photoItem, matching: .images)
            .fileImporter(isPresented: isPresented(.files), allowedContentTypes: [.image]) { result in
                if case let .success(url) = result, let cgImage = ImageLoader.cgImage(fromFile: url) {
                    colorImport.image = ColorImport.PickedImage(cgImage: cgImage)
                }
            }
            #if os(iOS)
            .fullScreenCover(isPresented: isPresented(.camera)) {
                CameraPicker { colorImport.image = ColorImport.PickedImage(cgImage: $0) }
                    .ignoresSafeArea()
            }
            #endif
            .sheet(item: $colorImport.image) { image in
                ImageColorPickerView(cgImage: image.cgImage, onPick: perform)
            }
            .alert("No Color to Paste", isPresented: $pasteFailed) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Copy a color value such as #FF8800, rgb(255 136 0), or oklch(0.7 0.2 60) and try again.")
            }
            .onChange(of: photoItem) { _, newItem in
                guard let newItem else { return }
                Task {
                    if let data = try? await newItem.loadTransferable(type: Data.self),
                       let cgImage = ImageLoader.cgImage(from: data) {
                        colorImport.image = ColorImport.PickedImage(cgImage: cgImage)
                    }
                    photoItem = nil
                }
            }
            // The pasteboard is the one source with nothing to present, so it completes here instead.
            .onChange(of: colorImport.source) { _, source in
                guard source == .pasteboard else { return }
                colorImport.source = nil
                Task {
                    if let pasted = await pastedColor() {
                        perform(pasted)
                    } else {
                        pasteFailed = true
                    }
                }
            }
    }

    /// A `Bool` binding onto one source, which is what each picker presents from.
    private func isPresented(_ source: ColorImport.Source) -> Binding<Bool> {
        Binding(get: { colorImport.source == source },
                set: { if !$0, colorImport.source == source { colorImport.source = nil } })
    }

    /// Reads the pasteboard as a CSS color, so anything CSS understands pastes — `#ff8800`,
    /// `rebeccapurple`, `rgb(...)`, `oklch(...)`, `color(display-p3 ...)`. Bare hex digits are retried with
    /// the `#` a copied value often arrives without.
    private func pastedColor() async -> Color? {
        guard let text = String.pasteboardText?.trimmingCharacters(in: .whitespacesAndNewlines),
              !text.isEmpty else { return nil }
        if let color = await WebColorRenderer.shared.resolve(text) { return color }
        return await WebColorRenderer.shared.resolve("#\(text)")
    }
}
