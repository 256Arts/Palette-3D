import WebKit
import ChromaKit

@MainActor
final class WebColorRenderer: NSObject, WKNavigationDelegate {

    private let webView = WKWebView(frame: .zero)

    /// Whether the bootstrap page has finished loading and `window.resolveColors` is callable.
    private var isReady = false
    /// Callers awaiting the first load; all resumed together in `didFinish`.
    private var waiters: [CheckedContinuation<Void, Never>] = []

    override init() {
        super.init()
        webView.navigationDelegate = self
        webView.loadHTMLString(Self.bootstrapHTML, baseURL: nil)
    }

    /// Resolves each CSS color string to its Display-P3 value. Order matches the input; empty on failure.
    func resolve(_ cssColors: [String]) async -> [P3] {
        guard !cssColors.isEmpty else { return [] }
        await waitUntilReady()

        guard let argument = try? String(decoding: JSONEncoder().encode(cssColors), as: UTF8.self),
              let result = try? await webView.evaluateJavaScript("window.resolveColors(\(argument))"),
              let rows = result as? [[Double]], rows.count == cssColors.count
        else { return [] }

        return rows.map { P3(r: $0[0], g: $0[1], b: $0[2]) }
    }

    private func waitUntilReady() async {
        guard !isReady else { return }
        await withCheckedContinuation { waiters.append($0) }
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        isReady = true
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
    </script>
    """
}
