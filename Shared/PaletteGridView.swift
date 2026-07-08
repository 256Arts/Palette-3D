//
//  PaletteGridView.swift
//  Palette 3D
//
//  Grid of color swatches. Tapping a swatch opens its details; pinch to zoom the swatches larger or
//  smaller. Larger swatches reveal the color's name, and the largest also show its hex value.
//

import SwiftUI

/// A gamut to highlight against. Colors that fall outside the selected gamut are clamped when
/// exported, so the grid flags them with a warning triangle.
enum GamutFilter: String, CaseIterable, Identifiable {
    case none, p3, srgb

    var id: Self { self }

    var name: String {
        switch self {
        case .none: "All"
        case .p3: "P3 Representable"
        case .srgb: "RGB Representable"
        }
    }

    /// Whether the given color is clamped in this gamut. `.none` never flags a color.
    func clamps(_ color: PaletteColor, colorSpace: ColorSpace) -> Bool {
        switch self {
        case .none: false
        case .p3: color.isOutsideP3Gamut(colorSpace: colorSpace)
        case .srgb: color.isOutsideSRGBGamut(colorSpace: colorSpace)
        }
    }
}

struct PaletteGridView: View {

    let colors: [PaletteColor]
    let colorSpace: ColorSpace
    var onSelect: (Int) -> Void
    var onAdd: () -> Void
    var onDropColors: ([Color]) -> Void
    var onDelete: (Int) -> Void
    var onReorder: (ReorderDifference<PaletteColor.ID, ReorderableSingleCollectionIdentifier>) -> Void

    @State private var cellSize: CGFloat = 64
    @State private var gamutFilter: GamutFilter = .none
    @GestureState private var pinch: CGFloat = 1

    private static let minSize: CGFloat = 44
    private static let maxSize: CGFloat = 220

    private var effectiveSize: CGFloat {
        min(max(cellSize * pinch, Self.minSize), Self.maxSize)
    }
    private var showsName: Bool { effectiveSize >= 96 }
    private var showsHex: Bool { effectiveSize >= 148 }

    /// Each color paired with the current space, so swatches can be dragged (reordered / exported).
    private var items: [DraggableColor] {
        colors.map { DraggableColor(color: $0, colorSpace: colorSpace) }
    }

    var body: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: effectiveSize, maximum: effectiveSize * 1.4), spacing: 12)], spacing: 12) {
                ForEach(items) { item in
                    swatch(item.color)
                }
                .reorderable()
                addButton
            }
            .reorderContainer(for: DraggableColor.self) { difference in
                onReorder(difference)
            }
            .dragContainer(for: DraggableColor.self) { id in
                items.first { $0.id == id }.map { [$0] } ?? []
            }
            .scenePadding()
            .animation(.snappy, value: showsName)
            .animation(.snappy, value: showsHex)
        }
        .toolbar {
            ToolbarItem {
                Menu {
                    Picker("Gamut Filter", selection: $gamutFilter) {
                        ForEach(GamutFilter.allCases) { filter in
                            Text(filter.name).tag(filter)
                        }
                    }
                } label: {
                    Label("Gamut Filter", systemImage: gamutFilter == .none ? "line.3.horizontal.decrease" : "line.3.horizontal.decrease.circle.fill")
                }
            }
        }
        .dropDestination(for: Color.self) { colors, _ in
            onDropColors(colors)
            return true
        }
        .simultaneousGesture(zoom)
    }

    private func swatch(_ color: PaletteColor) -> some View {
        let index = colors.firstIndex(of: color) ?? 0
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
                    .overlay {
                        if gamutFilter.clamps(color, colorSpace: colorSpace) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: effectiveSize * 0.4))
                                .symbolRenderingMode(.palette)
                                .foregroundStyle(.black, .yellow)
                                .shadow(radius: 2)
                        }
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
        .contentShape(.dragPreview, RoundedRectangle(cornerRadius: effectiveSize * 0.18, style: .continuous))
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
        onDelete: { _ in },
        onReorder: { _ in })
}
