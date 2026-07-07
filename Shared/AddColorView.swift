//
//  AddColorView.swift
//  Palette 3D
//
//  A sheet for composing a new palette color: a full-bleed preview, a name, and a color picker.
//  A color can also be dropped onto the preview to set it.
//

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

                    HStack {
                        TextField("Name", text: $name)
                            .font(.title2.weight(.semibold))
                            .textFieldStyle(.plain)
                        ColorPicker("Color", selection: $color, supportsOpacity: false)
                            .labelsHidden()
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
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add", systemImage: "plus", action: add)
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
