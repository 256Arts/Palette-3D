# Palette Studio

<img src="https://www.256arts.com/palette3d/icon_palette3d.webp" alt="Palette Studio icon" width="128" align="right">

Design color palettes by moving colors through a 3D sphere, then check that they actually work together.

[Download on the App Store](https://apps.apple.com/app/palette-3d/id6670776239) · [256arts.com/palette3d](https://www.256arts.com/palette3d/)

<img src="https://www.256arts.com/palette3d/shot1.webp" alt="A palette's colors positioned inside a 3D sphere by lightness, chroma, and hue" width="300">

## Features

- **3D color sphere** — colors sit inside a sphere by lightness, chroma, and hue, so you can see and adjust how a palette relates in space, not just as a row of swatches.
- **Perfect palette generator** — a tap creates a balanced palette, which you can then lock, reorder, or hand-edit.
- **Grid and text editing** — arrange colors in a grid or edit them as CSS color strings (`lch()`, `oklch()`), with edits syncing both ways.
- **Contrast and accessibility analysis** — WCAG contrast ratios, perceptual difference (ΔE₀₀) between every pair, and how the palette looks under color vision deficiencies like deuteranopia and protanopia.
- **Shades, complements, and pairs** — generate tints and shades toward white and black, step around the color wheel for complementary and triadic schemes, and compare any two colors side by side.
- **Import and export** — bring in GIMP palettes, palette images, or lospec.com palettes; export to GIMP, macOS color lists, palette images, or CSS/hex/HSL and other text formats.
- **iCloud sync** — your palette library follows you across your devices.
- iPhone, iPad, Mac, and Apple Vision Pro.

## Building

Open `Palette 3D.xcodeproj` in the latest Xcode and run the `Palette 3D` scheme (the app ships as Palette Studio). The color model, generator, and file formats live in the separate PaletteKit package. See [`AGENTS.md`](AGENTS.md) for architecture and testing details.
