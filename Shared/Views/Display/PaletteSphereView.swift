//
//  PaletteSphereView.swift
//  Palette 3D
//
//  RealityKit sphere visualization of a palette, shared by the inline display and the visionOS volume.
//  Each color is one sphere entity positioned at its perceptual 3D coordinate. When `onSelect` is set,
//  the spheres become tappable so a color can be edited by tapping it.
//

import SwiftUI
import RealityKit

struct PaletteSphereView: View {

    let colors: [PaletteColor]
    let colorSpace: ColorSpace
    let chromaMultiplier: Double

    /// Called with the tapped color's index. When non-nil, spheres get collision + input components so they can be hit-tested.
    var onSelect: ((Int) -> Void)? = nil

    var body: some View {
        RealityView { _ in
            // Entities are built in the update closure so they stay in sync with `colors`.
        } update: { content in
            while let first = content.entities.first {
                content.remove(first)
            }
            for (index, pColor) in colors.enumerated() {
                let model = ModelEntity(
                    mesh: .generateSphere(radius: Float(0.1 * Self.scale)),
                    materials: [SimpleMaterial(color: SystemColor(pColor.color(colorSpace: colorSpace)), isMetallic: false)])
                model.name = String(index)
                model.position = SIMD3(
                    Float((pColor.visualizedX * Self.scale) / chromaMultiplier),
                    Float(pColor.visualizedY * Self.scale),
                    Float((pColor.visualizedZ * Self.scale) / chromaMultiplier))
                if onSelect != nil {
                    model.generateCollisionShapes(recursive: false)
                    model.components.set(InputTargetComponent())
                }
                content.add(model)
            }
        }
        .realityViewLayoutBehavior(.centered)
        #if !os(visionOS)
        .realityViewCameraControls(.orbit)
        #endif
        .modifier(SphereTapModifier(onSelect: onSelect))
    }

    nonisolated static var scale: Double {
        // Slightly smaller than the container so edge spheres don't clip.
        #if os(visionOS)
        0.46
        #else
        0.98
        #endif
    }
}

private struct SphereTapModifier: ViewModifier {

    let onSelect: ((Int) -> Void)?

    func body(content: Content) -> some View {
        if let onSelect {
            content.gesture(
                SpatialTapGesture()
                    .targetedToAnyEntity()
                    .onEnded { value in
                        if let index = Int(value.entity.name) {
                            onSelect(index)
                        }
                    }
            )
        } else {
            content
        }
    }
}
