//
//  Palette3DApp.swift
//  Palette 3D
//
//  Created by 256 Arts Developer on 2022-08-15.
//

import SwiftUI

@main
struct Palette3DApp: App {
    
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    @Environment(\.openWindow) private var openWindow
    
    @StateObject var generator = PaletteGenerator()
    @State var convertCSSToP3 = false
    @State var paletteColors: [PaletteColor] = []
    @State var paletteText = ""
    @State var showingInspector = true
    @State var selectedDetent: PresentationDetent = .medium
    
    #if canImport(UIKit)
    let isPhone = UIDevice.current.userInterfaceIdiom == .phone
    #else
    let isPhone = false
    #endif
    
    var body: some Scene {
        #if os(visionOS)
        WindowGroup {
            NavigationStack {
                ParametersView(generator: generator, convertCSSToP3: $convertCSSToP3, paletteColors: $paletteColors, paletteText: $paletteText)
                    .toolbar {
                        Button("Open Display") {
                            openWindow(id: "display")
                        }
                    }
            }
        }
        .defaultSize(width: 500, height: 750)
        
        WindowGroup("Display", id: "display") {
            DisplayView(generator: generator, convertCSSToP3: $convertCSSToP3, paletteColors: $paletteColors, paletteText: $paletteText)
        }
        .windowStyle(.volumetric)
        .defaultSize(width: 1, height: 1, depth: 1, in: .meters)
        #else
        WindowGroup {
            NavigationStack {
                DisplayView(generator: generator, convertCSSToP3: $convertCSSToP3, paletteColors: $paletteColors, paletteText: $paletteText)
                    .safeAreaPadding(.bottom, selectedDetent == .height(64) || horizontalSizeClass == .regular || !isPhone ? 0 : 400)
                    .toolbar {
                        if !showingInspector {
                            Button {
                                showingInspector = true
                            } label: {
                                Image(systemName: "sidebar.trailing")
                            }
                        }
                    }
            }
            .inspector(isPresented: $showingInspector) {
                ParametersView(generator: generator, convertCSSToP3: $convertCSSToP3, paletteColors: $paletteColors, paletteText: $paletteText)
                    .presentationDetents([.height(64), .medium, .large], selection: $selectedDetent)
                    .presentationBackgroundInteraction(.enabled)
                    .interactiveDismissDisabled(isPhone)
            }
        }
        #endif
    }
}
