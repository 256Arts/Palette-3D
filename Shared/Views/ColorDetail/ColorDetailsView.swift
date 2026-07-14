import SwiftUI
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

struct ColorDetailsView: View {

    @Binding var color: PaletteColor
    let colorSpace: ColorSpace
    var onDelete: () -> Void

    /// The gamut whose color formats are listed. Defaults to the tightest gamut that contains the color.
    @State private var gamut: Gamut

    @Environment(\.dismiss) private var dismiss

    init(color: Binding<PaletteColor>, colorSpace: ColorSpace, onDelete: @escaping () -> Void) {
        _color = color
        self.colorSpace = colorSpace
        self.onDelete = onDelete
        _gamut = State(initialValue: Gamut.containing([color.wrappedValue], colorSpace: colorSpace))
    }

    private struct Metric: Identifiable {
        let name: String
        let value: String
        var id: String { name }
    }

    /// The color expressed in every representation belonging to the selected gamut. CSS color-space rows are
    /// re-derived from the realized P3 value so each is a true conversion, not the same fractions reinterpreted.
    private var metrics: [Metric] {
        gamut.representations.map { representation in
            Metric(name: representation.name,
                   value: color.string(representation, colorSpace: colorSpace, gamut: gamut))
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
                        HStack {
                            TextField("Name", text: nameBinding)
                                .font(.title2.weight(.semibold))
                                .textFieldStyle(.plain)
                            ColorPicker("Edit Color", selection: colorPickerBinding, supportsOpacity: false)
                                .labelsHidden()
                        }

                        VStack(spacing: 16) {
                            gamutPicker

                            VStack(spacing: 0) {
                                ForEach(Array(metrics.enumerated()), id: \.element.id) { index, metric in
                                    if index > 0 { Divider() }
                                    metricRow(metric)
                                }
                            }
                            .background(.quaternary.opacity(0.5), in: .rect(cornerRadius: 12))
                        }

                        Button("Delete Color", systemImage: "trash", role: .destructive) {
                            onDelete()
                        }
                        .frame(maxWidth: .infinity)
                        .buttonStyle(.bordered)
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
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", systemImage: "checkmark") { dismiss() }
                }
                ToolbarItem {
                    ShareLink(item: color.cssString(colorSpace: colorSpace, convertedToP3: false))
                }
            }
        }
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

    private func metricRow(_ metric: Metric) -> some View {
        HStack(spacing: 12) {
            Text(metric.name)
                .foregroundStyle(.secondary)
                .frame(width: 90, alignment: .leading)
            Text(metric.value)
                .monospaced()
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
            Button("Copy", systemImage: "doc.on.doc") { copy(metric.value) }
                .labelStyle(.iconOnly)
                .buttonStyle(.borderless)
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
        onDelete: {})
}
