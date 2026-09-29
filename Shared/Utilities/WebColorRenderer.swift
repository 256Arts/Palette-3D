import SwiftUI
import WebKit

@MainActor
final class WebColorRenderer: NSObject, WKNavigationDelegate {

    /// One bootstrapped web view for the whole app — every color-math caller shares it.
    static let shared = WebColorRenderer()

    private let webView = WKWebView(frame: .zero)

    /// Whether the bootstrap page has finished loading and `window.resolveColors` is callable.
    private var isReady = false
    /// Callers awaiting the load; all resumed together in `didFinish`.
    private var waiters: [CheckedContinuation<Void, Never>] = []
    /// Consecutive failed loads. A page built from a string has nothing to fetch, so it shouldn't fail at
    /// all — but a caller suspended on one that never lands would wait forever, so the count is capped.
    private var failures = 0
    private static let maximumFailures = 2

    override init() {
        super.init()
        webView.navigationDelegate = self
        bootstrap()
    }

    /// Resolves each CSS color string to a Display-P3 `Color`. Order matches the input; empty on failure.
    func resolve(_ cssColors: [String]) async -> [Color] {
        guard !cssColors.isEmpty,
              let argument = try? String(decoding: JSONEncoder().encode(cssColors), as: UTF8.self),
              let rows = await evaluate("window.resolveColors(\(argument))") as? [[Double]],
              rows.count == cssColors.count
        else { return [] }

        return rows.map { Color(.displayP3, red: $0[0], green: $0[1], blue: $0[2]) }
    }

    /// Resolves a single, possibly user-typed CSS color, or `nil` if it isn't a color CSS understands.
    /// The batch call can't report that: the canvas silently keeps its previous fill for anything it
    /// fails to parse, so unparseable text comes back as black rather than as a failure.
    func resolve(_ cssColor: String) async -> Color? {
        guard let argument = try? String(decoding: JSONEncoder().encode(cssColor), as: UTF8.self),
              let channels = await evaluate("window.resolveColor(\(argument))") as? [Double],
              channels.count == 3
        else { return nil }

        return Color(.displayP3, red: channels[0], green: channels[1], blue: channels[2])
    }

    /// Evaluates once the page is up, and once more if that throws.
    ///
    /// The second attempt is the point: WebKit reclaims the content process of a backgrounded app, and the
    /// call that discovers the page is gone is also the one that triggers rebuilding it. Without a retry,
    /// that caller is the one whose ramp stays empty — with nothing on screen to say why, or to ask again.
    private func evaluate(_ javaScript: String) async -> Any? {
        for attempt in 0..<2 {
            await waitUntilReady()
            if let result = try? await webView.evaluateJavaScript(javaScript) { return result }
            if attempt == 0 { reload() }
        }
        return nil
    }

    private func waitUntilReady() async {
        guard !isReady else { return }
        await withCheckedContinuation { waiters.append($0) }
    }

    private func bootstrap() {
        webView.loadHTMLString(Self.bootstrapHTML, baseURL: nil)
    }

    /// Drops the page and builds it again. Anyone waiting stays waiting — the new load will resume them.
    private func reload() {
        isReady = false
        bootstrap()
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        isReady = true
        failures = 0
        resumeWaiters()
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        loadFailed()
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        loadFailed()
    }

    /// WebKit reclaims a backgrounded app's content process: the web view outlives the page, and
    /// `window.resolveColors` goes with it. Left alone, every later call throws and every ramp, wheel, and
    /// pair bar comes back empty until the app is relaunched — so the page is rebuilt the moment it's lost.
    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        reload()
    }

    /// Retries a failed load, then gives up and lets the callers through: an empty ramp is recoverable —
    /// the next `.task` asks again — where a suspended one never is.
    private func loadFailed() {
        failures += 1
        if failures <= Self.maximumFailures {
            bootstrap()
        } else {
            resumeWaiters()
        }
    }

    private func resumeWaiters() {
        waiters.forEach { $0.resume() }
        waiters.removeAll()
    }

    /// A blank page whose `resolveColors` paints each color into a Display-P3 canvas and reads it back,
    /// returning `[r, g, b]` channels in 0…1 (gamma-encoded, as `Color(.displayP3, …)` expects).
    private static let bootstrapHTML = """
    <!doctype html><meta charset="utf-8">
    <script>
    const ctx = document.createElement('canvas').getContext('2d', { colorSpace: 'display-p3' });
    window.resolveColors = (colors) => colors.map((css) => {
        ctx.fillStyle = '#000';
        ctx.fillStyle = css;
        ctx.fillRect(0, 0, 1, 1);
        const [r, g, b] = ctx.getImageData(0, 0, 1, 1, { colorSpace: 'display-p3' }).data;
        return [r / 255, g / 255, b / 255];
    });
    // Validating single resolve: the canvas ignores a fill it can't parse, so ask CSS first.
    window.resolveColor = (css) => CSS.supports('color', css) ? window.resolveColors([css])[0] : null;
    </script>
    """
}
