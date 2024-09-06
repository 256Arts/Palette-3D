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
    
    @ObservedObject var generator: PaletteGenerator
    
    @Binding var paletteColors: [PaletteColor]
    @Binding var paletteText: String
    
    @State var displayMode: DisplayMode = .sphere
    @State var sphereNeedsRefresh = true
    @State var canShowTextInputWarning = true
    @State var showingTextInputWarning = false
    @State var showingHelp = false
    @FocusState var textIsFocused: Bool
    
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
                            mesh: .generateSphere(radius: 0.1),
                            materials: [SimpleMaterial(color: SystemColor(pColor.color(colorSpace: generator.colorSpace)), isMetallic: false)])
                        model.position.x = pColor.visualizedX
                        model.position.y = pColor.visualizedY
                        model.position.z = pColor.visualizedZ
                        content.add(model)
                    }
                }
                .realityViewCameraControls(.orbit)
                .aspectRatio(1, contentMode: .fit)
            case .text:
                TextEditor(text: $paletteText)
                    .autocorrectionDisabled()
                    #if !os(macOS)
                    .textInputAutocapitalization(.never)
                    #endif
                    .focused($textIsFocused)
                    .contentMargins(16, for: .scrollContent)
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
            ToolbarItem(placement: .navigation) {
                Button {
                    showingHelp = true
                } label: {
                    Image(systemName: "questionmark.circle")
                }
            }
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
            
            ToolbarItem(placement: .primaryAction) {
                Text("\(paletteColors.count) Colors")
            }
        }
        .sheet(isPresented: $showingHelp) {
            NavigationStack {
                HelpView()
            }
        }
        .onChange(of: paletteColors) {
            sphereNeedsRefresh = true
        }
        .alert("Text Input Not Supported", isPresented: $showingTextInputWarning) {
            Button("OK") { }
        } message: {
            Text("Only Lch and Oklch support text input. Lab and Oklab are output only.")
        }

    }
}

#Preview {
    NavigationStack {
        DisplayView(generator: PaletteGenerator(), paletteColors: .constant([]), paletteText: .constant(""))
    }
}
