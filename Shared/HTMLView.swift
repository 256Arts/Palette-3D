//
//  HTMLView.swift
//  Palette 3D
//
//  A minimal cross-platform `WKWebView` wrapper that renders a static HTML string.
//  Used by ``DuoView`` to display CSS `color-mix()` and gradient interpolation, which SwiftUI can't draw natively.
//

import SwiftUI
import WebKit

struct HTMLView {

    let html: String

    /// Remembers the last HTML we loaded so repeated SwiftUI updates don't reload (and flash) an unchanged page.
    final class Coordinator {
        var loadedHTML: String?
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    private func makeWebView() -> WKWebView {
        let webView = WKWebView()
        #if canImport(UIKit)
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear
        #elseif canImport(AppKit)
        webView.setValue(false, forKey: "drawsBackground")
        #endif
        return webView
    }

    private func load(into webView: WKWebView, coordinator: Coordinator) {
        guard coordinator.loadedHTML != html else { return }
        coordinator.loadedHTML = html
        webView.loadHTMLString(html, baseURL: nil)
    }
}

#if canImport(UIKit)
extension HTMLView: UIViewRepresentable {
    func makeUIView(context: Context) -> WKWebView { makeWebView() }
    func updateUIView(_ webView: WKWebView, context: Context) { load(into: webView, coordinator: context.coordinator) }
}
#elseif canImport(AppKit)
extension HTMLView: NSViewRepresentable {
    func makeNSView(context: Context) -> WKWebView { makeWebView() }
    func updateNSView(_ webView: WKWebView, context: Context) { load(into: webView, coordinator: context.coordinator) }
}
#endif
