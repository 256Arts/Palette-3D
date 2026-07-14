import SwiftUI
import PhotosUI
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

struct AddColorView: View {

    /// A picked/captured image wrapped so it can drive an `.sheet(item:)`.
    private struct PickableImage: Identifiable {
        let id = UUID()
        let cgImage: CGImage
    }

    let colorSpace: ColorSpace
    var onAdd: (PaletteColor) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var color: Color = .gray
    @State private var name: String = ""

    @State private var photoItem: PhotosPickerItem?
    @State private var showPhotosPicker = false
    @State private var showFileImporter = false
    @State private var pickableImage: PickableImage?
    #if os(iOS)
    @State private var showCamera = false
    #endif

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    color
                        .frame(height: 260)
                        .frame(maxWidth: .infinity)
                        .dropDestination(for: Color.self) { dropped, _ in
                            guard let first = dropped.first else { return false }
                            color = first
                            return true
                        }

                    VStack(spacing: 16) {
                        HStack {
                            TextField("Name", text: $name)
                                .font(.title2.weight(.semibold))
                                .textFieldStyle(.plain)
                            ColorPicker("Color", selection: $color, supportsOpacity: false)
                                .labelsHidden()
                        }
                    }
                    .padding()
                }
            }
            .ignoresSafeArea(edges: .top)
            .navigationTitle("New Color")
            #if !os(macOS)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackgroundVisibility(.hidden, for: .navigationBar)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", systemImage: "xmark") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add", systemImage: "checkmark", action: add)
                }
                ToolbarItem {
                    Menu {
                        #if os(iOS)
                        Button("Take Photo", systemImage: "camera") { showCamera = true }
                        #endif
                        Button("Choose Photo", systemImage: "photo.on.rectangle") { showPhotosPicker = true }
                        Button("Choose File", systemImage: "folder") { showFileImporter = true }
                    } label: {
                        Label("Pick Color from Image", systemImage: "eyedropper")
                            .frame(maxWidth: .infinity)
                    }
                }
            }
            .photosPicker(isPresented: $showPhotosPicker, selection: $photoItem, matching: .images)
            .fileImporter(isPresented: $showFileImporter, allowedContentTypes: [.image]) { result in
                if case let .success(url) = result, let cgImage = ImageLoader.cgImage(fromFile: url) {
                    pickableImage = PickableImage(cgImage: cgImage)
                }
            }
            #if os(iOS)
            .fullScreenCover(isPresented: $showCamera) {
                CameraPicker { cgImage in
                    pickableImage = PickableImage(cgImage: cgImage)
                }
                .ignoresSafeArea()
            }
            #endif
            .sheet(item: $pickableImage) { image in
                ImageColorPickerView(cgImage: image.cgImage) { color = $0 }
            }
            .onChange(of: photoItem) { _, newItem in
                guard let newItem else { return }
                Task {
                    if let data = try? await newItem.loadTransferable(type: Data.self),
                       let cgImage = ImageLoader.cgImage(from: data) {
                        pickableImage = PickableImage(cgImage: cgImage)
                    }
                    photoItem = nil
                }
            }
        }
    }

    private func add() {
        guard var newColor = PaletteColor(SystemColor(color), colorSpace: colorSpace) else { return }
        newColor.name = name.isEmpty ? nil : name
        onAdd(newColor)
        dismiss()
    }
}

#Preview {
    AddColorView(colorSpace: .okLch, onAdd: { _ in })
}
