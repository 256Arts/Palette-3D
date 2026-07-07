//
//  PaletteGridView.swift
//  Palette 3D
//
//  Grid of color swatches. Tapping a swatch opens its details; pinch to zoom the swatches larger or
//  smaller. Larger swatches reveal the color's name, and the largest also show its hex value.
//

import SwiftUI

struct PaletteGridView: View {

    let colors: [PaletteColor]
    let colorSpace: ColorSpace
    var onSelect: (Int) -> Void
    var onAdd: () -> Void
    var onDropColors: ([Color]) -> Void
    var onDelete: (Int) -> Void

    @State private var cellSize: CGFloat = 64
    @GestureState private var pinch: CGFloat = 1

    private static let minSize: CGFloat = 44
    private static let maxSize: CGFloat = 220

    private var effectiveSize: CGFloat {
        min(max(cellSize * pinch, Self.minSize), Self.maxSize)
    }
    private var showsName: Bool { effectiveSize >= 96 }
    private var showsHex: Bool { effectiveSize >= 148 }

    var body: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: effectiveSize, maximum: effectiveSize * 1.4), spacing: 12)], spacing: 12) {
                ForEach(colors.indices, id: \.self) { index in
                    swatch(index)
                }
                addButton
            }
            .scenePadding()
            .animation(.snappy, value: showsName)
            .animation(.snappy, value: showsHex)
        }
        .dropDestination(for: Color.self) { colors, _ in
            onDropColors(colors)
            return true
        }
        .simultaneousGesture(zoom)
    }

    private func swatch(_ index: Int) -> some View {
        let color = colors[index]
        return Button {
            onSelect(index)
        } label: {
            VStack(spacing: 6) {
                RoundedRectangle(cornerRadius: effectiveSize * 0.18, style: .continuous)
                    .fill(color.color(colorSpace: colorSpace))
                    .aspectRatio(1, contentMode: .fit)
                    .overlay {
                        RoundedRectangle(cornerRadius: effectiveSize * 0.18, style: .continuous)
                            .strokeBorder(.primary.opacity(0.1), lineWidth: 1)
                    }
                if showsName {
                    Text(color.name ?? "Color \(index + 1)")
                        .font(.caption)
                        .lineLimit(1)
                        .foregroundStyle(color.name == nil ? .secondary : .primary)
                }
                if showsHex {
                    Text(color.hexString(colorSpace: colorSpace))
                        .font(.caption2)
                        .monospaced()
                        .foregroundStyle(.secondary)
                }
            }
        }
        .buttonStyle(.plain)
        .draggable(color.color(colorSpace: colorSpace))
        .contextMenu {
            Button("Delete", systemImage: "trash", role: .destructive) { onDelete(index) }
        }
    }

    private var addButton: some View {
        Button(action: onAdd) {
            RoundedRectangle(cornerRadius: effectiveSize * 0.18, style: .continuous)
                .fill(.quaternary)
                .aspectRatio(1, contentMode: .fit)
                .overlay {
                    Image(systemName: "plus")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
        }
        .buttonStyle(.plain)
    }

    private var zoom: some Gesture {
        MagnifyGesture()
            .updating($pinch) { value, state, _ in state = value.magnification }
            .onEnded { value in
                cellSize = min(max(cellSize * value.magnification, Self.minSize), Self.maxSize)
            }
    }
}

#Preview {
    PaletteGridView(
        colors: [
            PaletteColor(lightnessFraction: 0.6, chromaFraction: 0.5, hueAngle: .degrees(30), name: "Coral"),
            PaletteColor(lightnessFraction: 0.5, chromaFraction: 0.4, hueAngle: .degrees(200)),
        ],
        colorSpace: .okLch,
        onSelect: { _ in },
        onAdd: {},
        onDropColors: { _ in },
        onDelete: { _ in })
}
