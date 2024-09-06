//
//  Palette3DApp.swift
//  Shared
//
//  Created by 256 Arts Developer on 2022-08-15.
//

import SwiftUI

@main
struct Palette3DApp: App {
    
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    
    @StateObject var generator = PaletteGenerator()
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
        WindowGroup {
            NavigationStack {
                DisplayView(generator: generator, paletteColors: $paletteColors, paletteText: $paletteText)
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
                ParametersView(generator: generator, paletteColors: $paletteColors, paletteText: $paletteText)
                    .presentationDetents([.height(64), .medium, .large], selection: $selectedDetent)
                    .presentationBackgroundInteraction(.enabled)
                    .interactiveDismissDisabled(isPhone)
            }
        }
    }
}
