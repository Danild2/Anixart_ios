import SwiftUI
import WebKit

struct EmbeddedPlayerView: UIViewRepresentable {
    let url: URL
    let playback: EmbeddedPlayback
    var configuration: PublicConfiguration? = nil
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
        config.userContentController.addUserScript(WKUserScript(source: EmbeddedPlayback.observerScript(externalMedia:playback.prefersExternalMedia), injectionTime: .atDocumentEnd, forMainFrameOnly: false))
        let view = WKWebView(frame: .zero, configuration: config)
        view.navigationDelegate = context.coordinator
        view.uiDelegate = context.coordinator
        playback.attach(view)
        if ProviderPage.requiresAdvertisement(url,configuration:configuration) { playback.beginAdvertisement() }
        if let initial = ProviderPage.initial(url,configuration:configuration) { view.load(URLRequest(url:initial)) }
        return view
    }
    func updateUIView(_ view: WKWebView, context: Context) { context.coordinator.parent = self }
    static func dismantleUIView(_ view: WKWebView, coordinator: Coordinator) { coordinator.parent.playback.pause(); view.configuration.userContentController.removeScriptMessageHandler(forName: "anixartPlayback"); view.configuration.userContentController.removeScriptMessageHandler(forName:"anixartKodikAd"); view.stopLoading(); view.loadHTMLString("", baseURL: nil); view.navigationDelegate = nil; view.uiDelegate = nil }

    @MainActor final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate, WKScriptMessageHandler {
        var parent: EmbeddedPlayerView
        private var advertPending: Bool
        private var advertisementPlayerURL: URL?
        private var contentTransitionPending = false
        init(_ parent: EmbeddedPlayerView) { self.parent = parent; advertPending = ProviderPage.requiresAdvertisement(parent.url,configuration:parent.configuration) }
        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            let origin = message.frameInfo.securityOrigin.host.lowercased().replacingOccurrences(of: "www.", with: "")
            if message.name == "anixartKodikAd" {
                guard advertPending, let event = message.body as? String,
                      ProviderPage.permitsAdCallback(origin:origin,expected:parent.url) else { return }
                switch event {
                case "playControlReady": parent.playback.advertisementControl(true)
                case "playControlHidden": parent.playback.advertisementControl(false)
                case "advertEnded": completeAdvertisement()
                default: break
                }
                return
            }
            let expected = (parent.url.host ?? "").lowercased().replacingOccurrences(of: "www.", with: "")
            let kodikOrigins = ProviderPage.kodikHosts
            let permitted = origin == expected || origin == "anixmirai.com" || (kodikOrigins.contains(origin) && kodikOrigins.contains(expected))
            guard !expected.isEmpty, permitted, let values = message.body as? [String: Any] else { return }
            if advertPending {
                if values["event"] as? String == "playing" || ((values["seconds"] as? Double ?? 0) > 0.2 && values["paused"] as? Bool == false) {
                    parent.playback.advertisementControl(false)
                }
                return
            }
            guard !contentTransitionPending, !ProviderPage.isAdvertisementDocument(message.frameInfo.request.url) else { return }
            parent.playback.receive(values, frame: message.frameInfo)
        }
        func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) { contentTransitionPending = false }
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) { parent.playback.loaded() }
        func webView(_ webView: WKWebView, decidePolicyFor action: WKNavigationAction) async -> WKNavigationActionPolicy {
            guard let url = action.request.url, ["https", "about"].contains(url.scheme ?? ""), action.targetFrame != nil else {
                return .cancel
            }
            if advertPending, ProviderPage.contentAfterAdvertisement(parent.url,advertisement:url) != nil {
                advertisementPlayerURL = url
            }
            return .allow
        }
        private func completeAdvertisement() {
            guard advertPending else { return }
            guard let content = ProviderPage.contentAfterAdvertisement(parent.url,advertisement:advertisementPlayerURL),
                  let page = ProviderPage.iframe(content) else {
                let message = "Источник не передал адрес плеера после рекламы. Повторите загрузку."
                parent.error = message; parent.playback.fail(message); return
            }
            advertPending = false; contentTransitionPending = true
            parent.error = nil; parent.playback.openContentPage(page)
        }
        private func navigationFailed(_ error: Error) {
            let failure = error as NSError
            guard failure.domain != NSURLErrorDomain || failure.code != NSURLErrorCancelled else { return }
            parent.error = error.localizedDescription; parent.playback.fail(error.localizedDescription)
        }
        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) { navigationFailed(error) }
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) { navigationFailed(error) }
        func webView(_ webView: WKWebView, decidePolicyFor response: WKNavigationResponse) async -> WKNavigationResponsePolicy {
            if advertPending, let http = response.response as? HTTPURLResponse,
               ProviderPage.isOriginalAdServerFailure(http.url,status:http.statusCode) {
                completeAdvertisement(); return .cancel
            }
            let host = response.response.url?.host?.lowercased() ?? ""
            let sourceFrame = host == parent.url.host?.lowercased() || ProviderPage.kodikHosts.contains(host)
            if let http = response.response as? HTTPURLResponse, http.statusCode >= 400, response.isForMainFrame || sourceFrame {
                let message = "Веб-источник вернул HTTP \(http.statusCode)."; parent.error = message; parent.playback.fail(message)
            }
            return response.canShowMIMEType ? .allow : .cancel
        }
        func webViewWebContentProcessDidTerminate(_ webView: WKWebView) { parent.error = "Веб-плеер остановлен системой. Повторите загрузку." }
    }
}
