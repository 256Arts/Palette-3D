# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

Palette 3D is a multiplatform SwiftUI app (iOS, macOS, visionOS) that procedurally generates color palettes and visualizes them in 3D. Colors are positioned inside a sphere whose axes are perceptual color dimensions (lightness, chroma, hue).

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

The app has two layers: an abstract palette model (resolution-independent fractions) and per-color-space realization (actual displayable/CSS colors). Keeping these separate is the core design idea.

**Generation pipeline** (`PaletteGenerator` → `[PaletteColor]` → views):
- `PaletteGenerator` (`@Observable`) holds all palette parameters and `generate()` produces the colors. It works purely in **normalized fractions** (lightness, chroma, hue) and is unaware of any concrete color space. It models the palette as a sphere: lightness is the vertical axis, and each lightness layer is a disc whose radius (`sqrt(1 - (lightness*2-1)^2)`) shrinks toward the poles; chroma is radial distance, hue is the angle around the disc.
- `PaletteColor` is one color as `lightnessFraction` / `chromaFraction` / `hueAngle`. It is **color-space agnostic** until `color(colorSpace:)` or `cssString(colorSpace:convertedToP3:)` is called — only then are fractions mapped to absolute values (e.g. `chromaFraction * maxChromaP3` for Oklch) and converted via ChromaKit. The `visualizedX/Y/Z` properties map a color to 3D sphere coordinates for the RealityKit view.

**State flow:** `Palette3DApp` owns the single source of truth (`generator`, `paletteColors`, `paletteText`, `convertCSSToP3`) and passes them down. `ParametersView` edits `generator` and calls `regenerate()` on every parameter change, which repopulates both `paletteColors` and `paletteText`. `DisplayView` renders the result.

**DisplayView** has three display modes:
- `sphere` — RealityKit `RealityView` placing a sphere entity per color at its visualized 3D position (uses `.orbit` camera controls except on visionOS). Rebuilds entities only when `sphereNeedsRefresh` is set.
- `grid` — a `LazyVGrid` of color swatches.
- `text` — a `TextEditor` of CSS color strings. This mode is **bidirectional**: editing text re-parses colors via `PaletteColor(css:)`. Only `lch()` and `oklch()` are parseable as input; `lab`, `oklab`, and P3 are output-only (an alert warns the user).

**CSS / P3:** `cssString(...)` emits `lch()`/`lab()`/`oklch()`/`oklab()` functional notation, or `color(display-p3 ...)` when `convertCSSToP3` is on (gamut-mapped through ChromaKit's `.p3`).

## Platform structure

- `Shared/` — all app code; cross-platform via `#if os(...)` / `#if canImport(...)` checks. `SystemColor` is typealiased to `NSColor`/`UIColor`.
- `macOS/` — macOS entitlements.
- visionOS uses a separate scene layout: parameters in a standard window plus a `.volumetric` window for the 3D display, instead of the inspector layout used on iOS/macOS.
