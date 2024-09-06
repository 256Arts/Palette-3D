//
//  ParametersView.swift
//  Palette3D
//
//  Created by 256 Arts Developer on 2022-08-15.
//

import SwiftUI
import RealityKit

struct ParametersView: View {

    @ObservedObject var generator: PaletteGenerator

    @Binding var paletteColors: [PaletteColor]
    @Binding var paletteText: String

    var body: some View {
        Form {
            Picker("Color Space", selection: $generator.colorSpace) {
                ForEach(ColorSpace.allCases) { space in
                    Text(space.rawValue)
                        .tag(space)
                }
            }
            
            LabeledContent("Lightness Levels") {
                HStack(spacing: 8) {
                    Text(String(generator.lightnessLevels))
                    Stepper("Lightness Levels", value: $generator.lightnessLevels)
                        .labelsHidden()
                }
            }
            
            Toggle("Lightness Twist", isOn: $generator.lightnessTwist)
            
            LabeledContent("Chroma Levels") {
                HStack(spacing: 8) {
                    Text(String(generator.chromaLevels))
                    Stepper("Chroma Levels", value: $generator.chromaLevels)
                        .labelsHidden()
                }
            }
            
            Toggle("Chroma Starts at Zero", isOn: $generator.chromaStartsAtZero)
            
            Toggle("Chroma Twist", isOn: $generator.chromaTwist)
            
            LabeledContent("Max Hue Segments") {
                HStack(spacing: 8) {
                    Text(String(generator.maxHueSegments))
                    Stepper("Max Hue Segments", value: $generator.maxHueSegments)
                        .labelsHidden()
                }
            }
            
            Toggle("Continuous Hues", isOn: $generator.continuousHues)
            
            LabeledContent("Starting Hue Offset") {
                HStack(spacing: 8) {
                    Text(String(generator.startingHueOffset))
                    Stepper(
                        "Starting Hue Offset",
                        value: $generator.startingHueOffset,
                        in: 0...(1 / Double(generator.maxHueSegments)),
                        step: 0.01)
                    .labelsHidden()
                }
            }
        }
        .navigationTitle("Palette Parameters")
        .onAppear {
            regenerate()
        }
        .onChange(of: generator.colorSpace) {
            regenerate()
        }
        .onChange(of: generator.lightnessLevels) {
            regenerate()
        }
        .onChange(of: generator.lightnessTwist) {
            regenerate()
        }
        .onChange(of: generator.chromaLevels) {
            regenerate()
        }
        .onChange(of: generator.chromaStartsAtZero) {
            regenerate()
        }
        .onChange(of: generator.chromaTwist) {
            regenerate()
        }
        .onChange(of: generator.maxHueSegments) {
            regenerate()
        }
        .onChange(of: generator.continuousHues) {
            regenerate()
        }
        .onChange(of: generator.startingHueOffset) {
            regenerate()
        }
    }
    
    func regenerate() {
        paletteColors = generator.generate()
        paletteText = paletteColors.map({ $0.cssString(colorSpace: generator.colorSpace) }).joined(separator: "\n") + "\n\n" // To fix layout when inspector is collapsed
    }
}

#Preview {
    NavigationStack {
        ParametersView(generator: PaletteGenerator(), paletteColors: .constant([]), paletteText: .constant(""))
    }
}
