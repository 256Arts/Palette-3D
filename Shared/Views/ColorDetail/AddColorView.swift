import PaletteKit
import SwiftUI
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

struct AddColorView: View {

    let colorSpace: ColorSpace
    var onAdd: (PaletteColor) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var color: Color = .gray
    @State private var name: String = ""
    @State private var colorImport = ColorImport()

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
                    ColorImportMenu(colorImport: $colorImport)
                }
            }
            .importingColor($colorImport) { color = $0 }
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
