//
//  PaletteImage.swift
//  Palette 3D
//
//  Bridges palettes from palette images — Sprite Pencil's interchange format: a 1px-tall
//  image encoding one fully-opaque color per pixel.
//

import CoreGraphics
import Foundation
import ImageIO

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
}
