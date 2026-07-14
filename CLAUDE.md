# CLAUDE.md

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
- `PaletteColor` is one color as `lightnessFraction` / `chromaFraction` / `hueAngle` plus an optional user-facing `name`. It is **color-space agnostic** until realized — `color(colorSpace:)`, `cssString(...)`, `hexString(...)`, etc. map fractions to absolute values (e.g. `chromaFraction * maxChromaP3` for Oklch) and convert via ChromaKit. It also parses inbound colors (`init(css:)`, `init(hex:colorSpace:)`, `init(sRGB8BitRed:...)`, `init(_ p3:colorSpace:)`). The `visualizedX/Y/Z` properties map a color to 3D sphere coordinates for the RealityKit view.
- `ColorRepresentation` + `Gamut` (PaletteKit) enumerate the text formats a color can be expressed in (CSS notations, RGB/Hex/HSL/HSB/HWB, SwiftUI/UIKit/AppKit/Java/Android snippets), grouped by gamut with clamping detection — used by the color detail rows and the export menu.

**Navigation & state flow:** the root view is `PaletteListView` (`Shared/Views/Library/`), a `NavigationStack` over a `@Query` of saved palettes, sorted by `dateModified`. Selecting one pushes `PaletteEditorView`, which owns a transient `PaletteGenerator` + `paletteText` (seeded from the palette in `load()`). `ParametersView` edits the generator (shown in an `.inspector`, or side-by-side on visionOS, only while `canEditParameters`); each parameter change triggers `regenerate(...)`, which writes `parameters`/`colors` back to the model. Any manual color edit flows through `onManualEdit` → `markCustomized()`.

**Import/Export** — the parsers and `Transferable`s (GIMP `.gpl`, `NSColorList` `.clr`, 1px palette images, lospec.com's `lospec-palette://` scheme registered in `Palette-3D-Info.plist`) all live in **PaletteKit**. The app only funnels: `PaletteListView.importFiles(_:)` hands any URL to `PaletteKit.Palette(file:colorSpace:)` — which picks the parser itself, so the app never switches on the file extension — and lands the result as a plain palette. Exports pass `palette.snapshot()` to PaletteKit's `GIMPPaletteExport` / `PaletteImageExport` / `PaletteColorListExport`.

**Analysis** (`Shared/Views/Analysis/`): `PaletteAnalysisView` is a read-only modal with pairwise ΔE₀₀ / WCAG contrast statistics and coverage, computed from PaletteKit's `ColorMetrics`. It converts each color to a `ColorMetrics.Sample` once and compares samples — the pairwise loop is O(n²) and must not re-convert. `DuoView` compares two colors via CSS `color-mix()`/gradients in multiple interpolation spaces, resolved by `WebColorRenderer` (an offscreen `WKWebView` that does only the color math; results are drawn natively).

## DisplayView

`DisplayView` (`Shared/Views/Display/`) renders and edits one palette's colors. It takes the generator, a `Binding` to the palette's colors, the CSS text binding, and an `onManualEdit` callback. Three display modes:
- `sphere` — `PaletteSphereView`, a RealityKit `RealityView` placing a sphere entity per color at its visualized 3D position (`.orbit` camera controls except on visionOS). Tapping a sphere opens that color's details. The same view backs the visionOS `.volumetric` window (`VolumetricDisplayView`, which looks the palette up live from SwiftData by `PersistentIdentifier`).
- `grid` — `PaletteGridView`, a pinch-zoomable `LazyVGrid` of swatches (larger sizes reveal name, then hex). Supports drag-to-reorder (iOS 27 `reorderable()`; applied via `ReorderDifference.apply(to:)` in `Shared/Utilities/`), dragging swatches out as colors (`DraggableColor`), dropping colors in, context-menu delete, an add button, and a gamut filter that flags colors clamped on the current display.
- `text` — a `TextEditor` of CSS color strings. This mode is **bidirectional**: editing text re-parses colors via `PaletteColor(css:)`. Only `lch()` and `oklch()` are parseable as input; `lab`, `oklab`, and P3 are output-only (an alert warns the user). Grid/sphere edits sync back into the text unless it's focused.

Tapping a color opens `ColorDetailsView` (`Shared/Views/ColorDetail/`) — preview, editable name, color picker, and the color's value in every `ColorRepresentation` with copy. `AddColorView` composes a new color from a picker, a dropped color, or an image/photo sampled with `ImageColorPickerView`'s eyedropper loupe. Every mutation path calls `onManualEdit`, so editing any color locks a perfect palette's parameters.

**CSS / P3:** PaletteKit's `cssString(...)` emits `lch()`/`lab()`/`oklch()`/`oklab()` functional notation, or `color(display-p3 ...)` when converting to P3 (gamut-mapped via ChromaKit, inside the package).

## Platform structure

- `Shared/` — all app code; cross-platform via `#if os(...)` / `#if canImport(...)` checks. `SystemColor` is typealiased to `NSColor`/`UIColor`.
- `macOS/` — macOS entitlements.
- visionOS diverges in the editor: parameters sit beside the display (no `.inspector` there), and an "Open in Volume" toolbar button opens the palette's sphere in a `.volumetric` window.
