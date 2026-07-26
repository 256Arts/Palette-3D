# AGENTS.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

Palette 3D is a multiplatform SwiftUI app (iOS, macOS, visionOS) that procedurally generates color palettes and visualizes them in 3D. Colors are positioned inside a sphere whose axes are perceptual color dimensions (lightness, chroma, hue). Palettes are saved to a SwiftData library, and can also be imported from and exported to standard formats (.gpl, .clr, palette images, lospec.com).

## Build & Test

The project is an Xcode project (`Palette 3D.xcodeproj`) with one app target (`Palette 3D`) and one test target (`Palette 3DTests`). Tests use Swift Testing (`import Testing` / `@Test`), not XCTest. The color model, generator, and file formats are tested in **PaletteKit** (`swift test` in its own repo); the tests here cover only this app's layer — SwiftData persistence and the `@Model` ↔ `PaletteKit.Palette` bridge.

```sh
# Build (let xcodebuild pick a destination, or use Xcode directly)
xcodebuild -scheme "Palette 3D" build

# Run all tests
xcodebuild -scheme "Palette 3D" test

# Run a single test
xcodebuild -scheme "Palette 3D" test -only-testing:"Palette 3DTests/PaletteTests/palettePersistsThroughSwiftData"
```

Note: the test target's deployment target is newer than the current Mac's macOS, so run the tests on an iOS simulator destination rather than `platform=macOS`.

Note: destinations/platforms are intentionally not pinned here — choose a current simulator or device at build time, as available SDKs change with Xcode updates.

## Dependencies

- **PaletteKit** (`/Volumes/Kingston/GitHub/PaletteKit`, a **local** Swift package — an external volume, so it's simply absent when unmounted) — the shared color engine: `PaletteColor`, `ColorSpace`, `ColorRepresentation`, `Gamut`, `SRGB8`, `PaletteGenerator`, `ColorMetrics`, every file format, the premade palettes, and reusable palette SwiftUI. Shared with Sprite Pencil and Sprite Catalog. **The color model and its math are not in this repo** — when a color type looks undefined here, it's PaletteKit's.
- ChromaKit arrives *transitively*, via PaletteKit. The app no longer imports it: everything it needs (perceptual metrics, P3 conversion) is exposed by PaletteKit, so `Lab`/`P3` never appear in app code.

## Architecture

The app has two layers: an abstract palette model (resolution-independent fractions) and per-color-space realization (actual displayable/CSS colors). Keeping these separate is the core design idea — and it now lives in **PaletteKit**, not here. On top sits this app's SwiftData palette library, its editor, and the 3D display.

**`Palette` is ambiguous by design.** In app code `Palette` always means the SwiftData `@Model`; PaletteKit's storage-agnostic value type is spelled `PaletteKit.Palette`. They convert via `Palette.init(_:)` (an import lands as a plain palette) and `Palette.snapshot()` (a value copy for export/drag, so no `@Model` is touched off the main actor).

**Palette library** (`Shared/Model/Palette.swift`):
- `Palette` is a SwiftData `@Model`: `name`, optional `parameters` (a `PaletteGenerator.Parameters`), `colors`, `isCustomized`, `dateModified`. A **perfect palette** keeps its generator parameters (created via `Palette.perfect(...)`); a **plain palette** is just a color list with `parameters == nil` (created via `Palette.plain(...)`, e.g. imports).
- Once the user manually edits a color, `isCustomized` locks generation (`canEditParameters` becomes false) so parameter changes can't overwrite their work. Generation is deterministic, so "Discard Manual Edits" exactly reproduces the perfect palette and unlocks the parameters again.
- `Palette3DApp` creates one shared `ModelContainer` used by every window (including the visionOS volume).

**Generation pipeline** (`PaletteGenerator` → `[PaletteColor]`) — **all of it lives in PaletteKit**; the app only drives it and persists the `Parameters`:
- `PaletteGenerator` (`@Observable`) wraps a `Parameters` struct (Codable/Equatable — this is what `Palette` persists) and `generate()` produces the colors. Generation is deterministic, which is what lets the app store the recipe instead of the colors. It works purely in **normalized fractions** (lightness, chroma, hue) and is unaware of any concrete color space. It models the palette as a sphere: lightness is the vertical axis, and each lightness layer is a disc whose radius (`sqrt(1 - (lightness*2-1)^2)`) shrinks toward the poles; chroma is radial distance, hue is the angle around the disc.
- `PaletteColor` is one color as `lightnessFraction` / `chromaFraction` / `hueAngle` plus an optional user-facing `name`. It is **color-space agnostic** until realized — `color(colorSpace:)`, `cssString(...)`, `hexString(...)`, etc. map fractions to absolute values (`chromaFraction * ColorSpace.chromaScale`) and convert via ChromaKit. It also parses inbound colors (`init(css:)`, `init(hex:colorSpace:)`, `init(sRGB8BitRed:...)`, `init(_ p3:colorSpace:)`). The `visualizedX/Y/Z` properties map a color to 3D sphere coordinates for the RealityKit view. `chromaScale` is *the* diameter knob: it's how far Display P3 reaches once each lightness layer is shrunk onto the sphere, so `chromaFraction == 1` lands on the sphere's surface, P3 fills the diameter, and wide-gamut colors plot outside it — hence the generator's chroma parameter reading "% of P3".
- `ColorRepresentation` + `Gamut` (PaletteKit) enumerate the text formats a color can be expressed in (CSS notations, RGB/Hex/HSL/HSB/HWB, SwiftUI/UIKit/AppKit/Java/Android snippets), grouped by gamut with clamping detection — used by the color detail rows and the export menu.
- `ColorFormat` (`Shared/Model/ColorFormat.swift`) pairs a representation with a gamut, because the framework snippets exist in both P3 and sRGB — that pair is what a user pins ("SwiftUI P3"). `PinnedColorFormats` persists the pins in `@AppStorage`, read by both `ColorDetailsView` (which does the pinning, and collapses the rest behind "All Formats") and the editor's export menu. `FormatLabel` (`Shared/Views/`) flags any format whose gamut clamps the color(s) — the warning takes the label's *icon* slot, since a `Menu` keeps only a label's title and image.

**Navigation & state flow:** the root view is `MainView` (`Shared/Views/`), a `TabView` over three tabs — Palettes (`PaletteListView`), Pairs (`PairsView`), and Color (a `ColorDetailsView` over one scratch color that `MainView` holds, so it survives tab switches). Each tab owns its own `NavigationStack`. It stays a *tab bar* at every size — deliberately not `.sidebarAdaptable`, since three peer destinations aren't a hierarchy and the editor has no use for a second column — and the pushed editor hides it via `hidingTabBar()` (`MainView.swift`), which is a no-op on macOS where `.tabBar` doesn't exist. An import arriving by URL can land behind an unselected tab, so `PaletteListView.onExternalImport` lets it ask `MainView` to bring the Palettes tab forward — the lospec path pushes an editor, which would otherwise happen out of sight.

Inside that first tab, `PaletteListView` (`Shared/Views/Library/`) is a `NavigationStack` over a `@Query` of saved palettes, sorted by `dateModified`. Below them, `PremadePaletteGallery` scrolls PaletteKit's `handpickedPalettes` (date-aware: the seasonal palette for today is promoted to the top), and tapping one lands a copy through the same path as an import. Unlike `premadePalettes`, that call isn't memoized and mints fresh palette ids each time, so the gallery resolves it once into `@State` rather than reading it from `body`. The empty state is a list row rather than an overlay, so it can't blanket that gallery. Selecting a palette pushes `PaletteEditorView`, which owns a transient `PaletteGenerator` + `paletteText` (seeded from the palette in `load()`). `PaletteInspectorView` is the trailing panel (an `.inspector`, or side-by-side on visionOS) and is always present: it switches between `ParametersView` and `PaletteAnalysisView` while `canEditParameters`, and drops to the analysis alone otherwise — which is why neither the panel nor the button that reopens it is gated on the parameters, and why a palette without them opens the drawer at its smallest detent. Each parameter change triggers `regenerate(...)`, which writes `parameters`/`colors` back to the model. Any manual color edit flows through `onManualEdit` → `markCustomized()`.

**Import/Export** — the parsers and `Transferable`s (GIMP `.gpl`, `NSColorList` `.clr`, 1px palette images, lospec.com's `lospec-palette://` scheme registered in `Palette-3D-Info.plist`) all live in **PaletteKit**. The app only funnels: `PaletteListView.importFiles(_:)` hands any URL to `PaletteKit.Palette(file:colorSpace:)` — which picks the parser itself, so the app never switches on the file extension — and lands the result as a plain palette. Exports pass `palette.snapshot()` to PaletteKit's `GIMPPaletteExport` / `PaletteImageExport` / `PaletteColorListExport`.

**Analysis** (`Shared/Views/Analysis/`): `PaletteAnalysisView` is a read-only panel (in the editor's inspector) with pairwise ΔE₀₀ / WCAG contrast statistics and coverage, computed from PaletteKit's `ColorMetrics`. It converts each color to a `ColorMetrics.Sample` once and compares samples — the pairwise loop is O(n²) and must not re-convert. It also lives beside the controls that edit the palette, so the analysis is held in `@State` behind a `.task(id:)` rather than computed from `body`. `PairsView` — the Pairs tab, and a root rather than a sheet, so it carries no Close button — compares two colors via CSS `color-mix()`/gradients in multiple interpolation spaces, resolved by `WebColorRenderer` (an offscreen `WKWebView` that does only the color math; results are drawn natively). A Mix swatch taps into its details; a Gradient row gets a copy button instead, since a gradient is the one thing here that isn't a color — it copies `linear-gradient(in <space>, …)`, which reproduces the bar's colors exactly because the sampled stops take CSS's same default `shorter hue` path. No direction is emitted — where the gradient points is the caller's decision, not the bar's.

## DisplayView

`DisplayView` (`Shared/Views/Display/`) renders and edits one palette's colors. It takes the generator, a `Binding` to the palette's colors, the CSS text binding, and an `onManualEdit` callback. It owns the toolbar's Add Color button, which belongs to the palette rather than to any one mode. Three display modes:
- `sphere` — `PaletteSphereView`, a RealityKit `RealityView` placing a sphere entity per color at its visualized 3D position (`.orbit` camera controls except on visionOS). Positions are plotted as-is — the model sphere's surface *is* Display P3, so a palette below 100% chroma reads as a smaller sphere and one above it breaks out; don't reintroduce a normalization that cancels the chroma parameter. Tapping a sphere opens that color's details. The same view backs the visionOS `.volumetric` window (`VolumetricDisplayView`, which looks the palette up live from SwiftData by `PersistentIdentifier`).
- `grid` — `PaletteGridView`, a pinch-zoomable `LazyVGrid` of swatches (larger sizes reveal name, then hex). Supports drag-to-reorder (iOS 27 `reorderable()`; applied via `ReorderDifference.apply(to:)` in `Shared/Utilities/`), dragging swatches out as colors (`DraggableColor`), dropping colors in, context-menu delete, and a gamut filter that flags colors clamped on the current display.
- `text` — a `TextEditor` of CSS color strings. This mode is **bidirectional**: editing text re-parses colors via `PaletteColor(css:)`. Only `lch()` and `oklch()` are parseable as input; `lab`, `oklab`, and P3 are output-only (an alert warns the user). Grid/sphere edits sync back into the text unless it's focused.

Tapping a color opens `ColorDetailsView` (`Shared/Views/ColorDetail/`) — preview, color picker, and the color's value in every `ColorRepresentation` with copy. Its **`Provenance`** decides the chrome, and is explicit rather than inferred because two of its three cases have no `onDelete` and the closures alone can't tell them apart: `.palette` gets the name field (the only case with somewhere to keep a name), Done, and Delete; `.derived` (a ramp swatch or a pair's mix, no palette row behind it) gets Close/Add; `.scratch` (the Color tab) gets no dismissal at all. `onAdd` is handed down from `DisplayView` to append a derived color to the palette.

Any color on screen is inspectable, however deep: `InspectedColor` + the `inspectingColor(_:colorSpace:onAdd:)` modifier (`Shared/Views/ColorDetail/`) present a `.derived` details sheet, and the presented view applies the same modifier to *its* ramps, so the sheets just stack. `InspectedColor` carries a `UUID` because `PaletteColor`'s own `id` is its value — editing the color inside the sheet would otherwise re-present it.

Two ramps sit below the formats, both resolved by `WebColorRenderer`, both draggable, and both tapping into a `.derived` `ColorDetailsView`. `ShadesView` mixes the color toward white and black in several CSS spaces. `ComplementsView` steps it around the hue wheel — a stepper picks 1–15 rotations beside the original, so `total = count + 1` colors divide the wheel evenly (2/3/4 being Complementary/Triadic/Square, which it names). It rotates via CSS relative color syntax, `oklch(from … l c calc(h + 360 * i / n))`, in the three spaces that have a hue channel: `oklab`/`lab`/`srgb` have none, and `hwb` is omitted because it shares sRGB's hue definition with `hsl` and so rotates identically. The rotation stays an exact CSS expression rather than a formatted number — `360 / 7` has no short decimal, and a locale's decimal comma would reach the CSS parser. `AddColorView` composes a new color from a picker, a dropped color, or an image/photo sampled with `ImageColorPickerView`'s eyedropper loupe. Every mutation path calls `onManualEdit`, so editing any color locks a perfect palette's parameters.

**CSS / P3:** PaletteKit's `cssString(...)` emits `lch()`/`lab()`/`oklch()`/`oklab()` functional notation, or `color(display-p3 ...)` when converting to P3 (gamut-mapped via ChromaKit, inside the package).

## Platform structure

- `Shared/` — all app code; cross-platform via `#if os(...)` / `#if canImport(...)` checks. `SystemColor` is typealiased to `NSColor`/`UIColor`.
- `macOS/` — macOS entitlements.
- visionOS diverges in the editor: the inspector panel sits beside the display (no `.inspector` there), and an "Open in Volume" toolbar button opens the palette's sphere in a `.volumetric` window.
