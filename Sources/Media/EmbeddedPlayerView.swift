import SwiftUI
import WebKit

struct EmbeddedPlayerView: UIViewRepresentable {
    let url: URL
    let playback: EmbeddedPlayback
    @Binding var error: String?
    func makeCoordinator() -> Coordinator { Coordinator(self) }
    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .nonPersistent()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        config.userContentController.add(context.coordinator, name: "anixartPlayback")
        config.userContentController.addUserScript(WKUserScript(source: EmbeddedPlayback.observerScript, injectionTime: .atDocumentEnd, forMainFrameOnly: false))
        let view = WKWebView(frame: .zero, configuration: config)
        view.navigationDelegate = context.coordinator
        view.uiDelegate = context.coordinator
        playback.attach(view)
        view.load(URLRequest(url: url))
        return view
    }
    func updateUIView(_ view: WKWebView, context: Context) { context.coordinator.parent = self }
    static func dismantleUIView(_ view: WKWebView, coordinator: Coordinator) { coordinator.parent.playback.pause(); view.configuration.userContentController.removeScriptMessageHandler(forName: "anixartPlayback"); view.stopLoading(); view.loadHTMLString("", baseURL: nil); view.navigationDelegate = nil; view.uiDelegate = nil }

    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate, WKScriptMessageHandler {
        var parent: EmbeddedPlayerView
        init(_ parent: EmbeddedPlayerView) { self.parent = parent }
        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            let origin = message.frameInfo.securityOrigin.host.lowercased().replacingOccurrences(of: "www.", with: "")
            let expected = (parent.url.host ?? "").lowercased().replacingOccurrences(of: "www.", with: "")
            guard !expected.isEmpty, origin == expected, let values = message.body as? [String: Any] else { return }
            parent.playback.receive(values, frame: message.frameInfo)
        }
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) { parent.playback.loaded() }
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
