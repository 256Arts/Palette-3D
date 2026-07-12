# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

Palette 3D is a multiplatform SwiftUI app (iOS, macOS, visionOS) that procedurally generates color palettes and visualizes them in 3D. Colors are positioned inside a sphere whose axes are perceptual color dimensions (lightness, chroma, hue). Palettes are saved to a SwiftData library, and can also be imported from and exported to standard formats (.gpl, .clr, palette images, lospec.com).

## Build & Test

The project is an Xcode project (`Palette 3D.xcodeproj`) with one app target (`Palette 3D`) and one test target (`Palette 3DTests`). Tests use Swift Testing (`import Testing` / `@Test`), not XCTest.

```sh
# Build (let xcodebuild pick a destination, or use Xcode directly)
xcodebuild -scheme "Palette 3D" build

# Run all tests
xcodebuild -scheme "Palette 3D" test

# Run a single test
xcodebuild -scheme "Palette 3D" test -only-testing:"Palette 3DTests/PaletteTests/testCSS"
```

Note: destinations/platforms are intentionally not pinned here — choose a current simulator or device at build time, as available SDKs change with Xcode updates.

## Dependencies

- **ChromaKit** (https://github.com/256Arts/ChromaKit) — Swift Package providing color-space types (`Lab`, `Lch`, `Oklab`, `Oklch`), the `XYZConvertable` protocol, and P3 conversion. All color math conversions go through this package.

## Architecture

The app has two layers: an abstract palette model (resolution-independent fractions) and per-color-space realization (actual displayable/CSS colors). Keeping these separate is the core design idea. On top sits a SwiftData palette library.

**Palette library** (`Shared/Model/Palette.swift`):
- `Palette` is a SwiftData `@Model`: `name`, optional `parameters` (a `PaletteGenerator.Parameters`), `colors`, `isCustomized`, `dateModified`. A **perfect palette** keeps its generator parameters (created via `Palette.perfect(...)`); a **plain palette** is just a color list with `parameters == nil` (created via `Palette.plain(...)`, e.g. imports).
- Once the user manually edits a color, `isCustomized` locks generation (`canEditParameters` becomes false) so parameter changes can't overwrite their work. Generation is deterministic, so "Discard Manual Edits" exactly reproduces the perfect palette and unlocks the parameters again.
- `Palette3DApp` creates one shared `ModelContainer` used by every window (including the visionOS volume).

**Generation pipeline** (`PaletteGenerator` → `[PaletteColor]`):
- `PaletteGenerator` (`@Observable`) wraps a `Parameters` struct (Codable/Equatable — this is what `Palette` persists) and `generate()` produces the colors. It works purely in **normalized fractions** (lightness, chroma, hue) and is unaware of any concrete color space. It models the palette as a sphere: lightness is the vertical axis, and each lightness layer is a disc whose radius (`sqrt(1 - (lightness*2-1)^2)`) shrinks toward the poles; chroma is radial distance, hue is the angle around the disc.
- `PaletteColor` is one color as `lightnessFraction` / `chromaFraction` / `hueAngle` plus an optional user-facing `name`. It is **color-space agnostic** until realized — `color(colorSpace:)`, `cssString(...)`, `hexString(...)`, etc. map fractions to absolute values (e.g. `chromaFraction * maxChromaP3` for Oklch) and convert via ChromaKit. It also parses inbound colors (`init(css:)`, `init(hex:colorSpace:)`, `init(sRGB8BitRed:...)`, `init(_ p3:colorSpace:)`). The `visualizedX/Y/Z` properties map a color to 3D sphere coordinates for the RealityKit view.
- `ColorRepresentation` + `Gamut` (in `PaletteColor.swift`) enumerate the text formats a color can be expressed in (CSS notations, RGB/Hex/HSL/HSB/HWB, SwiftUI/UIKit/AppKit/Java/Android snippets), grouped by gamut with clamping detection — used by the color detail rows and the export menu.

**Navigation & state flow:** the root view is `PaletteListView` (`Shared/Views/Library/`), a `NavigationStack` over a `@Query` of saved palettes, sorted by `dateModified`. Selecting one pushes `PaletteEditorView`, which owns a transient `PaletteGenerator` + `paletteText` (seeded from the palette in `load()`). `ParametersView` edits the generator (shown in an `.inspector`, or side-by-side on visionOS, only while `canEditParameters`); each parameter change triggers `regenerate(...)`, which writes `parameters`/`colors` back to the model. Any manual color edit flows through `onManualEdit` → `markCustomized()`.

**Import/Export** (`Shared/ImportExport/`) — all imports land as plain palettes, realized into the current color space on the way in:
- `PaletteGPL.swift` — GIMP palette (`.gpl`) text format, cross-platform. `GIMPPalette` parses; `GIMPPaletteExport` is a `Transferable` for ShareLink.
- `PaletteColorList.swift` (macOS only) — `NSColorList` (`.clr`) read/write, plus `PaletteExport`, the `Transferable` used to drag a palette row out to Finder.
- `PaletteImage.swift` — Sprite Pencil-style palette images: a 1px-tall image, one fully-opaque color per pixel.
- `PaletteLospec.swift` — handles lospec.com's `lospec-palette://<slug>` URL scheme (registered in `Palette-3D-Info.plist`) by fetching the palette JSON from the site's API.
- `PaletteListView` funnels all of these: import menu, drop onto the list (macOS), and `onOpenURL`.

**Analysis** (`Shared/Views/Analysis/`): `PaletteAnalysisView` is a read-only modal with pairwise ΔE₀₀ / WCAG contrast statistics and coverage, computed by `ColorMetrics` (`Shared/Model/`). `DuoView` compares two colors via CSS `color-mix()`/gradients in multiple interpolation spaces, resolved by `WebColorRenderer` (an offscreen `WKWebView` that does only the color math; results are drawn natively).

## DisplayView

`DisplayView` (`Shared/Views/Display/`) renders and edits one palette's colors. It takes the generator, a `Binding` to the palette's colors, the CSS text binding, and an `onManualEdit` callback. Three display modes:
- `sphere` — `PaletteSphereView`, a RealityKit `RealityView` placing a sphere entity per color at its visualized 3D position (`.orbit` camera controls except on visionOS). Tapping a sphere opens that color's details. The same view backs the visionOS `.volumetric` window (`VolumetricDisplayView`, which looks the palette up live from SwiftData by `PersistentIdentifier`).
- `grid` — `PaletteGridView`, a pinch-zoomable `LazyVGrid` of swatches (larger sizes reveal name, then hex). Supports drag-to-reorder (iOS 27 `reorderable()`; applied via `ReorderDifference.apply(to:)` in `Shared/Utilities/`), dragging swatches out as colors (`DraggableColor`), dropping colors in, context-menu delete, an add button, and a gamut filter that flags colors clamped on the current display.
- `text` — a `TextEditor` of CSS color strings. This mode is **bidirectional**: editing text re-parses colors via `PaletteColor(css:)`. Only `lch()` and `oklch()` are parseable as input; `lab`, `oklab`, and P3 are output-only (an alert warns the user). Grid/sphere edits sync back into the text unless it's focused.

Tapping a color opens `ColorDetailsView` (`Shared/Views/ColorDetail/`) — preview, editable name, color picker, and the color's value in every `ColorRepresentation` with copy. `AddColorView` composes a new color from a picker, a dropped color, or an image/photo sampled with `ImageColorPickerView`'s eyedropper loupe. Every mutation path calls `onManualEdit`, so editing any color locks a perfect palette's parameters.

**CSS / P3:** `cssString(...)` emits `lch()`/`lab()`/`oklch()`/`oklab()` functional notation, or `color(display-p3 ...)` when converting to P3 (gamut-mapped through ChromaKit's `.p3`).

## Platform structure

- `Shared/` — all app code; cross-platform via `#if os(...)` / `#if canImport(...)` checks. `SystemColor` is typealiased to `NSColor`/`UIColor`.
- `macOS/` — macOS entitlements.
- visionOS diverges in the editor: parameters sit beside the display (no `.inspector` there), and an "Open in Volume" toolbar button opens the palette's sphere in a `.volumetric` window.
