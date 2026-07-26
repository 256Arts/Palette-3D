import PaletteKit
import SwiftUI
import RealityKit

struct PaletteSphereView: View {

    let colors: [PaletteColor]
    let colorSpace: ColorSpace

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
                // Unlit, so a swatch is its own color from every angle. A lit material would shade each
                // sphere by where the scene's light happens to sit — orbit round and half the graph falls
                // into a dark back side, and even face-on the color shown isn't the color measured.
                let model = ModelEntity(
                    mesh: .generateSphere(radius: Float(0.1 * Self.scale)),
                    materials: [UnlitMaterial(color: SystemColor(pColor.color(colorSpace: colorSpace)))])
                model.name = String(index)
                // Plotted as-is: the sphere's surface is Display P3, so a palette pulled below 100%
                // chroma should read as a smaller sphere, and one pushed past it should break out.
                model.position = SIMD3(
                    Float(pColor.visualizedX * Self.scale),
                    Float(pColor.visualizedY * Self.scale),
                    Float(pColor.visualizedZ * Self.scale))
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
