//
//  PaletteImage.swift
//  Palette 3D
//
//  Bridges palettes to/from palette images — Sprite Pencil's interchange format: a 1px-tall
//  image encoding one fully-opaque color per pixel.
//

import CoreGraphics
import Foundation
import ImageIO
import SwiftUI
import UniformTypeIdentifiers

/// A failure encoding a palette to a palette image.
enum PaletteImageError: LocalizedError {
    case empty
    case encodingFailed

    var errorDescription: String? {
        switch self {
        case .empty: "The palette has no colors to export."
        case .encodingFailed: "Could not encode the palette image."
        }
    }
}

extension Array where Element == PaletteColor {

    /// Loads a palette from a palette-image file, or `nil` if it isn't a valid palette image.
    /// Decodes the exact pixels (no downsampling), since every pixel is one palette entry.
    init?(paletteImageFile url: URL, colorSpace: ColorSpace) {
        let didAccess = url.startAccessingSecurityScopedResource()
        defer { if didAccess { url.stopAccessingSecurityScopedResource() } }

        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else { return nil }
        self.init(paletteImage: image, colorSpace: colorSpace)
    }

    /// Loads a palette from an image encoding one color per pixel. Returns `nil` unless the
    /// image is 1px tall with no clear pixels — Sprite Pencil's palette-image rules.
    init?(paletteImage image: CGImage, colorSpace: ColorSpace) {
        guard image.height == 1, 0 < image.width else { return nil }

        // Redraw into a known sRGB RGBA8 buffer so any source pixel format reads uniformly.
        var pixels = [UInt8](repeating: 0, count: image.width * 4)
        guard let srgb = CGColorSpace(name: CGColorSpace.sRGB),
              let context = pixels.withUnsafeMutableBytes({ raw in
                  CGContext(
                    data: raw.baseAddress,
                    width: image.width,
                    height: 1,
                    bitsPerComponent: 8,
                    bytesPerRow: image.width * 4,
                    space: srgb,
                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
              }) else { return nil }
        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: 1))

        var colors: [PaletteColor] = []
        for x in 0 ..< image.width {
            let i = x * 4
            guard pixels[i + 3] == 255, // A clear pixel invalidates the whole image.
                  let color = PaletteColor(sRGB8BitRed: Int(pixels[i]), green: Int(pixels[i + 1]), blue: Int(pixels[i + 2]), colorSpace: colorSpace) else { return nil }
            colors.append(color)
        }
        self = colors
    }

    /// Renders the palette as a 1px-tall image, one fully-opaque sRGB pixel per color — the
    /// palette-image interchange format, re-importable by `init?(paletteImage:colorSpace:)`.
    func paletteImage(colorSpace: ColorSpace) -> CGImage? {
        guard !isEmpty else { return nil }

        var pixels = [UInt8](repeating: 0, count: count * 4)
        for (x, color) in enumerated() {
            let (r, g, b) = color.srgb8Bit(colorSpace: colorSpace) // Already gamut-clamped to 0–255.
            let i = x * 4
            pixels[i] = UInt8(r)
            pixels[i + 1] = UInt8(g)
            pixels[i + 2] = UInt8(b)
            pixels[i + 3] = 255
        }

        return CGColorSpace(name: CGColorSpace.sRGB).flatMap { srgb in
            pixels.withUnsafeMutableBytes { raw in
                CGContext(
                    data: raw.baseAddress,
                    width: count,
                    height: 1,
                    bitsPerComponent: 8,
                    bytesPerRow: count * 4,
                    space: srgb,
                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)?
                    .makeImage()
            }
        }
    }

    /// Encodes the palette as PNG palette-image data. Throws if the palette is empty or can't be encoded.
    func paletteImagePNGData(colorSpace: ColorSpace) throws -> Data {
        guard let image = paletteImage(colorSpace: colorSpace) else { throw PaletteImageError.empty }
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data, UTType.png.identifier as CFString, 1, nil) else {
            throw PaletteImageError.encodingFailed
        }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else { throw PaletteImageError.encodingFailed }
        return data as Data
    }
}

/// A value-type snapshot of a palette for sharing out as a 1px-tall PNG palette image.
/// Cross-platform and re-importable by Palette 3D and Sprite Pencil.
struct PaletteImageExport: Transferable {

    let name: String
    let colors: [PaletteColor]
    let colorSpace: ColorSpace

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(exportedContentType: .png) { export in
            let safeName = export.name.replacingOccurrences(of: "/", with: "-")
            let url = URL.temporaryDirectory.appending(component: "\(safeName).png")
            try export.colors.paletteImagePNGData(colorSpace: export.colorSpace).write(to: url)
            return SentTransferredFile(url)
        }
    }
}
