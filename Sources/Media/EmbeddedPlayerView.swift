import SwiftUI
import WebKit

struct EmbeddedPlayerView: UIViewRepresentable {
    let url: URL
    @Binding var error: String?
    func makeCoordinator() -> Coordinator { Coordinator(self) }
    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .nonPersistent()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = .all
        let view = WKWebView(frame: .zero, configuration: config)
        view.navigationDelegate = context.coordinator
        view.uiDelegate = context.coordinator
        view.load(URLRequest(url: url))
        return view
    }
    func updateUIView(_ view: WKWebView, context: Context) { context.coordinator.parent = self }
    static func dismantleUIView(_ view: WKWebView, coordinator: Coordinator) { view.stopLoading(); view.loadHTMLString("", baseURL: nil); view.navigationDelegate = nil; view.uiDelegate = nil }

    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
        var parent: EmbeddedPlayerView
        init(_ parent: EmbeddedPlayerView) { self.parent = parent }
        func webView(_ webView: WKWebView, decidePolicyFor action: WKNavigationAction) async -> WKNavigationActionPolicy {
            guard let url = action.request.url, ["https", "about"].contains(url.scheme ?? ""), action.targetFrame != nil else {
                return .cancel
            }
            return .allow
        }
        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) { parent.error = error.localizedDescription }
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) { parent.error = error.localizedDescription }
        func webView(_ webView: WKWebView, decidePolicyFor response: WKNavigationResponse) async -> WKNavigationResponsePolicy {
            if let http = response.response as? HTTPURLResponse, http.statusCode >= 400 { parent.error = "Веб-источник вернул HTTP \(http.statusCode)." }
            return response.canShowMIMEType ? .allow : .cancel
        }
        func webViewWebContentProcessDidTerminate(_ webView: WKWebView) { parent.error = "Веб-плеер остановлен системой. Повторите загрузку." }
    }
}
