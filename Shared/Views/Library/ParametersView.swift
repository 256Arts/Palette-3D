import PaletteKit
import SwiftUI

struct ParametersView: View {

    @Bindable var generator: PaletteGenerator

    var body: some View {
        Form {
            Group {
                Picker("Color Space", selection: $generator.parameters.colorSpace) {
                    ForEach(ColorSpace.allCases) { space in
                        Text(space.name)
                            .tag(space)
                    }
                }

                LabeledContent("Lightness Levels") {
                    HStack(spacing: 8) {
                        Text(String(generator.parameters.lightnessLevels))
                        Stepper("Lightness Levels", value: $generator.parameters.lightnessLevels)
                            .labelsHidden()
                    }
                }

                Toggle("Lightness Twist", isOn: $generator.parameters.lightnessTwist)

                LabeledContent("Chroma Levels") {
                    HStack(spacing: 8) {
                        Text(String(generator.parameters.chromaLevels))
                        Stepper("Chroma Levels", value: $generator.parameters.chromaLevels)
                            .labelsHidden()
                    }
                }

                Toggle("Chroma Starts at Zero", isOn: $generator.parameters.chromaStartsAtZero)

                LabeledContent("Chroma Multiplier") {
                    HStack(spacing: 8) {
                        Text(generator.parameters.chromaMultiplier, format: .percent)
                        Stepper(
                            "Chroma Multiplier",
                            value: $generator.parameters.chromaMultiplier,
                            in: 0...1,
                            step: 0.01)
                        .labelsHidden()
                    }
                }

                Toggle("Chroma Twist", isOn: $generator.parameters.chromaTwist)

                LabeledContent("Max Hue Segments") {
                    HStack(spacing: 8) {
                        Text(String(generator.parameters.maxHueSegments))
                        Stepper("Max Hue Segments", value: $generator.parameters.maxHueSegments)
                            .labelsHidden()
                    }
                }
            }

            Toggle("Continuous Hues", isOn: $generator.parameters.continuousHues)

            LabeledContent("Starting Hue Offset") {
                HStack(spacing: 8) {
                    Text(Measurement(value: generator.parameters.startingHueOffset.degrees, unit: UnitAngle.degrees), format: .measurement(width: .narrow))
                    Stepper(
                        "Starting Hue Offset",
                        value: Binding(get: {
                            generator.parameters.startingHueOffset.degrees
                        }, set: { newValue in
                            generator.parameters.startingHueOffset = .degrees(newValue)
                        }),
                        in: 0...(360 / Double(generator.parameters.maxHueSegments)),
                        step: 1)
                    .labelsHidden()
                }
            }
        }
        .navigationTitle("Palette Parameters")
    }
}

#Preview {
    NavigationStack {
        ParametersView(generator: PaletteGenerator())
    }
}
