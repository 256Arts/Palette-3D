import PaletteKit
import SwiftUI
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

struct ColorDetailsView: View {

    /// Where the color came from, which decides how the view is dismissed and whether naming it means
    /// anything. Two of these have no `onDelete`, so the closures alone can no longer tell them apart.
    enum Provenance {
        /// A row in a palette: named, deletable, confirmed with Done.
        case palette
        /// Opened from a shade or complement ramp — no palette row behind it, so it closes rather than
        /// confirms, offers to be added, and its own ramps don't drill further.
        case derived
        /// The Color tab's scratch color. It belongs to no palette and is never dismissed.
        case scratch
    }

    @Binding var color: PaletteColor
    let colorSpace: ColorSpace
    let provenance: Provenance

    /// Removes the color from its palette. Only a `.palette` color has a row to remove.
    var onDelete: (() -> Void)?

    /// Appends a color to the palette. Passed down to the derived-color sheet, which is where it applies.
    var onAdd: ((PaletteColor) -> Void)?

    /// A color opened from one of the ramps. `PaletteColor`'s own id is derived from its value, so editing
    /// it would change its identity and re-present the sheet; this carries a stable one instead.
    private struct DerivedColor: Identifiable {
        var color: PaletteColor
        let id = UUID()
    }

    @State private var inspected: DerivedColor?

    /// The gamut whose color formats are listed. Defaults to the tightest gamut that contains the color.
    @State private var gamut: Gamut

    /// Collapsed by default whenever there are pins — the point of pinning is not to scroll past the rest.
    @State private var showingAllFormats = false

    @AppStorage(PinnedColorFormats.storageKey) private var pinnedFormats = PinnedColorFormats()

    @Environment(\.dismiss) private var dismiss

    init(color: Binding<PaletteColor>,
         colorSpace: ColorSpace,
         provenance: Provenance,
         onDelete: (() -> Void)? = nil,
         onAdd: ((PaletteColor) -> Void)? = nil) {
        _color = color
        self.colorSpace = colorSpace
        self.provenance = provenance
        self.onDelete = onDelete
        self.onAdd = onAdd
        _gamut = State(initialValue: Gamut.containing([color.wrappedValue], colorSpace: colorSpace))
    }

    /// The formats of the selected gamut. CSS color-space rows are re-derived from the realized P3 value
    /// so each is a true conversion, not the same fractions reinterpreted.
    private var gamutFormats: [ColorFormat] {
        gamut.representations.map { ColorFormat(gamut: gamut, representation: $0) }
    }

    /// A name is only worth offering where something keeps it: a palette color's row. A derived color is
    /// discarded unless it's added, and the scratch color belongs to nothing at all — for both, the picker
    /// takes the row on its own and carries its label rather than floating there as a bare swatch.
    @ViewBuilder private var header: some View {
        if provenance == .palette {
            HStack {
                TextField("Name", text: nameBinding)
                    .font(.title2.weight(.semibold))
                    .textFieldStyle(.plain)
                ColorPicker("Edit Color", selection: colorPickerBinding, supportsOpacity: false)
                    .labelsHidden()
            }
        } else {
            ColorPicker("Edit Color", selection: colorPickerBinding, supportsOpacity: false)
                .font(.title2.weight(.semibold))
        }
    }

    private var nameBinding: Binding<String> {
        Binding(get: { color.name ?? "" }, set: { color.name = $0.isEmpty ? nil : $0 })
    }

    /// Editing via the picker replaces the color but preserves the name.
    private var colorPickerBinding: Binding<Color> {
        Binding(
            get: { color.color(colorSpace: colorSpace) },
            set: { newColor in
                guard var edited = PaletteColor(SystemColor(newColor), colorSpace: colorSpace) else { return }
                edited.name = color.name
                color = edited
            })
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    color.color(colorSpace: colorSpace)
                        .frame(height: 260)
                        .frame(maxWidth: .infinity)
                        .draggable(color.color(colorSpace: colorSpace))
                        .dropDestination(for: Color.self) { dropped, _ in
                            guard let first = dropped.first,
                                  var edited = PaletteColor(SystemColor(first), colorSpace: colorSpace) else { return false }
                            edited.name = color.name
                            color = edited
                            return true
                        }

                    VStack(alignment: .leading, spacing: 24) {
                        header

                        formats

                        ShadesView(css: color.cssString(colorSpace: colorSpace, convertedToP3: true),
                                   onSelect: derivedSelection)

                        ComplementsView(css: color.cssString(colorSpace: colorSpace, convertedToP3: true),
                                        onSelect: derivedSelection)

                        if let onDelete {
                            Button("Delete Color", systemImage: "trash", role: .destructive) {
                                onDelete()
                            }
                            .frame(maxWidth: .infinity)
                            .buttonStyle(.bordered)
                        }
                    }
                    .padding()
                }
            }
            .ignoresSafeArea(edges: .top)
            .navigationTitle(color.name ?? "Color")
            #if !os(macOS)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackgroundVisibility(.hidden, for: .navigationBar)
            #endif
            .toolbar {
                // `.scratch` gets neither: a root tab has nothing to confirm, close, or add itself to.
                if provenance == .palette {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done", systemImage: "checkmark") { dismiss() }
                    }
                }
                if provenance == .derived {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Close", systemImage: "xmark") { dismiss() }
                    }
                    if let onAdd {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Add", systemImage: "plus") {
                                onAdd(color)
                                dismiss()
                            }
                        }
                    }
                }
                ToolbarItem {
                    ShareLink(item: color.cssString(colorSpace: colorSpace, convertedToP3: false))
                }
            }
            .sheet(item: $inspected) { derived in
                ColorDetailsView(color: binding(to: derived),
                                 colorSpace: colorSpace,
                                 provenance: .derived,
                                 onAdd: onAdd)
            }
        }
    }

    /// Drilling into a ramp swatch — from a palette color or the scratch color, but not from a derived
    /// one, whose own ramps deliberately don't drill further.
    private var derivedSelection: ((Color) -> Void)? {
        guard provenance != .derived else { return nil }
        return inspect
    }

    private func inspect(_ derived: Color) {
        guard let picked = PaletteColor(SystemColor(derived), colorSpace: colorSpace) else { return }
        inspected = DerivedColor(color: picked)
    }

    /// Edits write back to the presented color, and reads fall back to the value the sheet was handed —
    /// the state is already `nil` while the sheet animates away, and reading it unguarded would trap.
    private func binding(to derived: DerivedColor) -> Binding<PaletteColor> {
        Binding(get: { inspected?.color ?? derived.color },
                set: { inspected?.color = $0 })
    }

    /// The pinned formats first, then the full gamut-by-gamut list — collapsed behind a disclosure once
    /// anything is pinned, and shown outright while nothing is (there is nothing to collapse away from yet).
    private var formats: some View {
        VStack(alignment: .leading, spacing: 16) {
            if pinnedFormats.formats.isEmpty {
                allFormats
            } else {
                formatRows(pinnedFormats.formats, name: \.qualifiedName)
                DisclosureGroup("All Formats", isExpanded: $showingAllFormats) {
                    allFormats
                        .padding(.top, 12)
                }
            }
        }
    }

    private var allFormats: some View {
        VStack(spacing: 16) {
            gamutPicker
            formatRows(gamutFormats, name: \.name)
        }
    }

    private func formatRows(_ formats: [ColorFormat], name: KeyPath<ColorFormat, String>) -> some View {
        VStack(spacing: 0) {
            ForEach(Array(formats.enumerated()), id: \.element.id) { index, format in
                if index > 0 { Divider() }
                formatRow(format, name: format[keyPath: name])
            }
        }
        .background(.quaternary.opacity(0.5), in: .rect(cornerRadius: 12))
    }

    /// A segmented picker over the gamuts. A ⚠ suffix marks a gamut that clamps the color — a Unicode glyph
    /// rather than an SF Symbol image, which a segmented Picker won't render inline.
    private var gamutPicker: some View {
        Picker("Gamut", selection: $gamut) {
            ForEach(Gamut.allCases) { gamut in
                let label = gamut.clamps(color, colorSpace: colorSpace) ? "\(gamut.rawValue) ⚠" : gamut.rawValue
                Text(label).tag(gamut)
            }
        }
        .pickerStyle(.segmented)
    }

    private func formatRow(_ format: ColorFormat, name: String) -> some View {
        let isClamped = format.gamut.clamps(color, colorSpace: colorSpace)
        let isPinned = pinnedFormats.contains(format)
        let value = format.string(color, colorSpace: colorSpace)

        return HStack(spacing: 12) {
            FormatLabel(name: name, isClamped: isClamped)
                .foregroundStyle(isClamped ? AnyShapeStyle(.orange) : AnyShapeStyle(.secondary))
                .accessibilityLabel(isClamped ? "\(name), clamped to fit this gamut" : name)
                .frame(width: 110, alignment: .leading)
            Text(value)
                .monospaced()
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
            Button("Copy", systemImage: "doc.on.doc") { copy(value) }
                .labelStyle(.iconOnly)
                .buttonStyle(.borderless)
            Menu {
                Button(isPinned ? "Unpin" : "Pin", systemImage: isPinned ? "pin.slash" : "pin") {
                    pinnedFormats.toggle(format)
                }
                ShareLink(item: value)
            } label: {
                Label("More", systemImage: "ellipsis")
            }
            .labelStyle(.iconOnly)
            .buttonStyle(.borderless)
            .menuIndicator(.hidden)
        }
        .font(.callout)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    private func copy(_ string: String) {
        #if canImport(AppKit)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(string, forType: .string)
        #else
        UIPasteboard.general.string = string
        #endif
    }
}

#Preview {
    ColorDetailsView(
        color: .constant(PaletteColor(lightnessFraction: 0.6, chromaFraction: 0.5, hueAngle: .degrees(30), name: "Coral")),
        colorSpace: .okLch,
        provenance: .palette,
        onDelete: {})
}
