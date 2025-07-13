//
//  DisplayView.swift
//  Palette 3D
//
//  Created by 256 Arts Developer on 2024-09-05.
//

import SwiftUI
import RealityKit

#if canImport(AppKit)
typealias SystemColor = NSColor
#else
typealias SystemColor = UIColor
#endif

struct DisplayView: View {
    
    enum DisplayMode: Identifiable {
        case grid, sphere, text
        
        var id: Self { self }
    }
    
    @Bindable var generator: PaletteGenerator
    @Binding var convertCSSToP3: Bool
    @Binding var paletteColors: [PaletteColor]
    @Binding var paletteText: String
    
    @State var displayMode: DisplayMode = .sphere
    @State var sphereNeedsRefresh = true
    @State var canShowTextInputWarning = true
    @State var showingTextInputWarning = false
    @FocusState var textIsFocused: Bool
    
    @Environment(\.accessibilityAssistiveAccessEnabled) private var isAssistiveAccessEnabled
    
    private var colorCountPlacement: ToolbarItemPlacement {
        #if os(macOS)
        .primaryAction
        #else
        .navigationBarLeading
        #endif
    }
    
    var body: some View {
        VStack {
            switch displayMode {
            case .grid:
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 24, maximum: 24))], content: {
                    ForEach(paletteColors) { pColor in
                        RoundedRectangle(cornerRadius: 4)
                            .fill(pColor.color(colorSpace: generator.colorSpace))
                            .frame(width: 24, height: 24)
                    }
                })
                .scenePadding()
            case .sphere:
                RealityView { content in
                    //
                } update: { content in
                    guard sphereNeedsRefresh else { return }
                    
                    while !content.entities.isEmpty {
                        content.remove(content.entities[0])
                    }
                    
                    for pColor in paletteColors {
                        let model = ModelEntity(
                            mesh: .generateSphere(radius: Float(0.1 * Self.scale)),
                            materials: [SimpleMaterial(color: SystemColor(pColor.color(colorSpace: generator.colorSpace)), isMetallic: false)])
                        model.position.x = Float((pColor.visualizedX * Self.scale) / generator.chromaMultiplier)
                        model.position.y = Float(pColor.visualizedY * Self.scale)
                        model.position.z = Float((pColor.visualizedZ * Self.scale) / generator.chromaMultiplier)
                        content.add(model)
                    }
                }
                .realityViewLayoutBehavior(.centered)
                #if !os(visionOS)
                .realityViewCameraControls(.orbit)
                #endif
            case .text:
                TextEditor(text: $paletteText)
                    .autocorrectionDisabled()
                    .focused($textIsFocused)
                    #if os(macOS)
                    .overlay(alignment: .topTrailing) {
                        Toggle("P3", isOn: $convertCSSToP3)
                            .padding()
                    }
                    #else
                    .textInputAutocapitalization(.never)
                    #endif
                    .onChange(of: paletteText) { _, newValue in
                        guard textIsFocused else {
                            canShowTextInputWarning = true
                            return
                        }
                        
                        let cssStrings = newValue.components(separatedBy: "\n")
                        paletteColors = cssStrings.compactMap { PaletteColor(css: $0) }
                        
                        if newValue.contains("lab(") /* Matches lab and oklab */ {
                            showingTextInputWarning = true
                            canShowTextInputWarning = false
                        }
                    }
            }
        }
        #if !os(macOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: colorCountPlacement) {
                Text("\(paletteColors.count) Colors")
                    .foregroundStyle(.secondary)
                    .fixedSize()
            }
            .sharedBackgroundVisibility(.hidden)
            
            ToolbarItem(placement: .principal) {
                Picker("Display Mode", selection: $displayMode) {
                    Image(systemName: "rotate.3d")
                        .tag(DisplayMode.sphere)
                    Image(systemName: "square.grid.3x3")
                        .tag(DisplayMode.grid)
                    Image(systemName: "text.alignleft")
                        .tag(DisplayMode.text)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(maxWidth: 140)
            }
            
            #if !os(macOS)
            if displayMode == .text {
//                ToolbarItem(placement: .primaryAction) {
//                    ShareLink(item: paletteText)
//                }
                
                ToolbarItem(placement: .primaryAction) {
                    Toggle("P3", isOn: $convertCSSToP3)
                }
            }
            
            if !isAssistiveAccessEnabled {
                ToolbarItemGroup(placement: .secondaryAction) {
                    Link(destination: URL(string: "https://www.256arts.com/")!) {
                        Label("Developer Website", systemImage: "safari")
                    }
                    Link(destination: URL(string: "https://www.256arts.com/joincommunity/")!) {
                        Label("Join Community", systemImage: "bubble.left.and.bubble.right")
                    }
                    Link(destination: URL(string: "https://github.com/256Arts/Palette-3D")!) {
                        Label("Contribute on GitHub", systemImage: "chevron.left.forwardslash.chevron.right")
                    }
                }
            }
            
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                
                Button("Done") {
                    textIsFocused = false
                }
            }
            #endif
        }
        .onChange(of: paletteColors) {
            sphereNeedsRefresh = true
        }
        .onChange(of: convertCSSToP3) { _, newValue in
            paletteText = paletteColors.map({ $0.cssString(colorSpace: generator.colorSpace, convertedToP3: newValue) }).joined(separator: "\n") + "\n\n" // To fix layout when inspector is collapsed
        }
        .alert("Text Input Not Supported", isPresented: $showingTextInputWarning) {
            Button("OK") { }
        } message: {
            Text("Only Lch and Oklch support text input. Lab, Oklab, and P3 are output only.")
        }
    }
    
    nonisolated static var scale: Double {
        // Make scales slightly smaller to prevent balls on the edge from clipping
        #if os(visionOS)
        0.46
        #else
        0.98
        #endif
    }
    
}

#Preview {
    NavigationStack {
        DisplayView(generator: PaletteGenerator(), convertCSSToP3: .constant(false), paletteColors: .constant([]), paletteText: .constant(""))
    }
}
