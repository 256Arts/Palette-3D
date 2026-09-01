import PaletteKit
import SwiftUI
#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

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

    /// The gamut of the device's display, so the grid can flag colors it can't show. Falls back to
    /// `.p3` when the display gamut is unknown (all modern Apple displays are at least P3).
    static var deviceDefault: GamutFilter {
        #if canImport(AppKit)
        NSScreen.main?.canRepresent(.p3) == false ? .srgb : .p3
        #elseif canImport(UIKit)
        UITraitCollection.current.displayGamut == .SRGB ? .srgb : .p3
        #else
        .p3
        #endif
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
    var onDropColors: ([Color]) -> Void
    var onDelete: (Int) -> Void
    var onReorder: ([PaletteColor]) -> Void

    @SceneStorage("gridCellSize") private var cellSize: Double = 64
    @State private var gamutFilter: GamutFilter = .deviceDefault
    @GestureState private var pinch: CGFloat = 1

    private static let minSize: CGFloat = 44
    private static let maxSize: CGFloat = 220

    private var effectiveSize: CGFloat {
        min(max(CGFloat(cellSize) * pinch, Self.minSize), Self.maxSize)
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
                // Only the OS 27 branch reorders by drag; see `usesManualMoveCommands` for the
                // fallback, and for how to unwrap this once OS 26 is dropped.
                if #available(iOS 27, macOS 27, visionOS 27, *) {
                    ForEach(items) { item in
                        swatch(item)
                    }
                    .reorderable()
                } else {
                    ForEach(items) { item in
                        swatch(item)
                    }
                }
            }
            .modifier(SwatchDragContainers(items: items, onReorder: onReorder))
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

    private func swatch(_ item: DraggableColor) -> some View {
        let color = item.color
        let index = colors.firstIndex(of: color) ?? 0
        let button = Button {
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
                                .foregroundStyle(.white.opacity(0.8))
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

        return Group {
            if usesManualMoveCommands {
                // Without a drag container the swatch carries its own drag, so exporting a color still works.
                button.draggable(item)
            } else {
                button
            }
        }
        .contextMenu {
            if usesManualMoveCommands {
                Button("Move Left", systemImage: "arrow.left") { move(from: index, by: -1) }
                    .disabled(index == 0)
                Button("Move Right", systemImage: "arrow.right") { move(from: index, by: 1) }
                    .disabled(index == colors.count - 1)
                Divider()
            }
            Button("Delete", systemImage: "trash", role: .destructive) { onDelete(index) }
        }
    }

    /// Drag-to-reorder needs the OS 27 reorder containers, so older systems get explicit move commands.
    ///
    /// Once OS 26 is dropped, ordering collapses back to a single path: delete this flag,
    /// `move(from:by:)`, the Move Left / Move Right context-menu items, and the per-swatch
    /// `.draggable(item)` (`dragContainer` supplies those drags once it is unconditional); unwrap the
    /// `#available` in `body` so the `ForEach` always carries `.reorderable()`; and fold
    /// `SwatchDragContainers` back into `body` as plain `.reorderContainer(for:)` / `.dragContainer(for:)`
    /// modifiers. `onReorder` can then take the `ReorderDifference` itself instead of a rebuilt
    /// `[PaletteColor]`, which lets `DisplayView` apply the move to its colors in place.
    private var usesManualMoveCommands: Bool {
        if #available(iOS 27, macOS 27, visionOS 27, *) {
            return false
        } else {
            return true
        }
    }

    /// Moves a swatch one place along the palette — the pre-OS 27 stand-in for dragging it.
    private func move(from index: Int, by offset: Int) {
        var reordered = colors
        let destination = index + offset
        guard reordered.indices.contains(index), reordered.indices.contains(destination) else { return }
        reordered.swapAt(index, destination)
        onReorder(reordered)
    }

    private var zoom: some Gesture {
        MagnifyGesture()
            .updating($pinch) { value, state, _ in state = value.magnification }
            .onEnded { value in
                cellSize = Double(min(max(CGFloat(cellSize) * value.magnification, Self.minSize), Self.maxSize))
            }
    }
}

/// The OS 27 containers that give the grid drag-to-reorder and let a swatch be dragged out of the app.
/// Older systems get nothing here; `PaletteGridView` falls back to per-swatch drags and move commands.
///
/// This type exists only to hold the availability check — delete it when OS 26 is dropped, per
/// `PaletteGridView.usesManualMoveCommands`.
private struct SwatchDragContainers: ViewModifier {

    let items: [DraggableColor]
    let onReorder: ([PaletteColor]) -> Void

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 27, macOS 27, visionOS 27, *) {
            content
                .reorderContainer(for: DraggableColor.self) { difference in
                    var reordered = items
                    difference.apply(to: &reordered)
                    onReorder(reordered.map(\.color))
                }
                .dragContainer(for: DraggableColor.self) { id in
                    items.first { $0.id == id }.map { [$0] } ?? []
                }
        } else {
            content
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
        onDropColors: { _ in },
        onDelete: { _ in },
        onReorder: { _ in })
}
