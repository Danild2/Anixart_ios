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
        config.userContentController.add(context.coordinator, name: "anixartKodikAd")
        config.userContentController.addUserScript(WKUserScript(source: ProviderPage.adBridge, injectionTime: .atDocumentStart, forMainFrameOnly: false))
        config.userContentController.addUserScript(WKUserScript(source: EmbeddedPlayback.observerScript, injectionTime: .atDocumentEnd, forMainFrameOnly: false))
        let view = WKWebView(frame: .zero, configuration: config)
        view.navigationDelegate = context.coordinator
        view.uiDelegate = context.coordinator
        playback.attach(view)
        if ProviderPage.isKodik(url) { playback.beginAdvertisement() }
        if let initial = ProviderPage.initial(url) { view.load(URLRequest(url:initial)) }
        return view
    }
    func updateUIView(_ view: WKWebView, context: Context) { context.coordinator.parent = self }
    static func dismantleUIView(_ view: WKWebView, coordinator: Coordinator) { coordinator.parent.playback.pause(); view.configuration.userContentController.removeScriptMessageHandler(forName: "anixartPlayback"); view.configuration.userContentController.removeScriptMessageHandler(forName:"anixartKodikAd"); view.stopLoading(); view.loadHTMLString("", baseURL: nil); view.navigationDelegate = nil; view.uiDelegate = nil }

    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate, WKScriptMessageHandler {
        var parent: EmbeddedPlayerView
        private var advertPending: Bool
        init(_ parent: EmbeddedPlayerView) { self.parent = parent; advertPending = ProviderPage.isKodik(parent.url) }
        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            let origin = message.frameInfo.securityOrigin.host.lowercased().replacingOccurrences(of: "www.", with: "")
            if message.name == "anixartKodikAd" {
                guard advertPending, message.body as? String == "advertEnded",
                      ProviderPage.permitsAdCallback(origin:origin,expected:parent.url),
                      let content = ProviderPage.canonicalKodik(parent.url) else { return }
                advertPending = false
                parent.playback.openContentPage(content)
                return
            }
            guard !advertPending else { return }
            let expected = (parent.url.host ?? "").lowercased().replacingOccurrences(of: "www.", with: "")
            let kodikOrigins = ProviderPage.kodikHosts
            let permitted = origin == expected || origin == "anixmirai.com" || (kodikOrigins.contains(origin) && kodikOrigins.contains(expected))
            guard !expected.isEmpty, permitted, let values = message.body as? [String: Any] else { return }
            parent.playback.receive(values, frame: message.frameInfo)
        }
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) { parent.playback.loaded() }
        func webView(_ webView: WKWebView, decidePolicyFor action: WKNavigationAction) async -> WKNavigationActionPolicy {
            guard let url = action.request.url, ["https", "about"].contains(url.scheme ?? ""), action.targetFrame != nil else {
                return .cancel
            }
            return .allow
        }
        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) { parent.error = error.localizedDescription; parent.playback.fail(error.localizedDescription) }
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) { parent.error = error.localizedDescription; parent.playback.fail(error.localizedDescription) }
        func webView(_ webView: WKWebView, decidePolicyFor response: WKNavigationResponse) async -> WKNavigationResponsePolicy {
            if let http = response.response as? HTTPURLResponse, http.statusCode >= 400 { let message = "Веб-источник вернул HTTP \(http.statusCode)."; parent.error = message; parent.playback.fail(message) }
            return response.canShowMIMEType ? .allow : .cancel
        }
        func webViewWebContentProcessDidTerminate(_ webView: WKWebView) { parent.error = "Веб-плеер остановлен системой. Повторите загрузку." }
    }
}
