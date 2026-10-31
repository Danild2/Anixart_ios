import Foundation
import Observation
import WebKit

@MainActor @Observable final class EmbeddedPlayback {
    enum Phase: String { case loading = "Загрузка плеера…", advertisement = "Реклама источника", ready = "Источник загружен", playing = "Воспроизводится", paused = "Пауза", ended = "Просмотр завершён", failed = "Источник недоступен" }
    private(set) var phase = Phase.loading
    private(set) var seconds: Double = 0
    private(set) var duration: Double?
    private(set) var renderedVideo = false
    private(set) var canControl = false
    private(set) var error: String?
    private(set) var mediaURL: URL?
    private(set) var advertisementControlReady = false
    private weak var webView: WKWebView?
    private var frame: WKFrameInfo?
    private let key: PlaybackKey
    private let progress: ProgressStore
    private let resumeSeconds: Double
    private var restored = false
    private var lastSaved: Double = -10
    let prefersExternalMedia: Bool

    init(key: PlaybackKey, progress: ProgressStore = ProgressStore(), prefersExternalMedia: Bool = false) {
        self.key = key; self.progress = progress
        self.prefersExternalMedia = prefersExternalMedia
        resumeSeconds = progress.progress(for: key)?.resumeSeconds ?? 0
    }
    func loaded() { if phase == .loading { phase = .ready } }
    func fail(_ message: String) { error = message; phase = .failed }
    func attach(_ webView: WKWebView) { self.webView = webView }
    func beginAdvertisement() { phase = .advertisement }
    func advertisementControl(_ ready: Bool) { advertisementControlReady = ready }
    func openContentPage(_ url: URL) {
        phase = .loading; error = nil; mediaURL = nil; frame = nil; canControl = false; advertisementControlReady = false
        webView?.load(URLRequest(url:url))
    }
    func receive(_ values: [String: Any], frame: WKFrameInfo) {
        self.frame = frame
        canControl = true
        receive(values)
    }
    func receive(_ values: [String: Any]) {
        let event = values["event"] as? String ?? ""
        if let raw = values["media"] as? String, let url = URL(string:raw),
           ["https","http"].contains(url.scheme ?? ""), url.host != nil, url.user == nil, url.password == nil,
           prefersExternalMedia && ["m3u8","mp4"].contains(url.pathExtension.lowercased()) {
            mediaURL = url; StreamTestCapture.write(url,key:key,duration:duration)
        }
        if event == "error" {
            if prefersExternalMedia, values["code"] as? Int == 4, mediaURL != nil {
                // VLC compatibility does not depend on WebKit decoding the same
                // format. Keep the discovered URL, without claiming playback.
                error = nil; phase = .ready; canControl = false
            } else { fail("Видеоисточник сообщил об ошибке воспроизведения (\(values["code"] as? Int ?? 0)).") }
            return
        }
        guard let position = values["seconds"] as? Double, position.isFinite, position >= 0 else { return }
        let previous = seconds
        seconds = position
        if let value = values["duration"] as? Double, value.isFinite, value > 0 { duration = value }
        if let raw = values["media"] as? String, let url = URL(string: raw),
           ["https", "http"].contains(url.scheme ?? ""), url.host != nil, url.user == nil, url.password == nil {
            mediaURL = url
            StreamTestCapture.write(url, key: key, duration: duration)
        }
        if !restored, duration != nil {
            restored = true
            if resumeSeconds > 0 { command("seek", argument: resumeSeconds) }
        }
        renderedVideo = (values["width"] as? Int ?? 0) > 0 && (values["height"] as? Int ?? 0) > 0 && (values["ready"] as? Int ?? 0) >= 3
        if event == "ended" { phase = .ended }
        else if (values["paused"] as? Bool) == true { phase = .paused }
        else if renderedVideo, seconds >= 2, seconds > previous { phase = .playing }
        if abs(seconds - lastSaved) >= 5 || ["pause", "ended"].contains(event) { save() }
    }
    func play() { command("play") }
    func pause() { command("pause"); save() }
    func seek(by delta: Double) { command("seek", argument: max(0, min(seconds + delta, duration ?? Double.greatestFiniteMagnitude))) }
    func save() {
        guard seconds.isFinite, duration != nil else { return }
        do { try progress.save(key: key, seconds: seconds, duration: duration); lastSaved = seconds }
        catch { self.error = "Не удалось сохранить позицию: \(error.localizedDescription)" }
    }
    private func command(_ name: String, argument: Double? = nil) {
        guard let webView, let frame else { return }
        let value = argument.map { $0.isFinite ? String($0) : "0" } ?? ""
        webView.evaluateJavaScript("window.__anixartPlayback?.\(name)(\(value))", in: frame, in: .page, completionHandler: nil)
    }
    // Observe the provider's normally served HTML5 media; never extract keys or cookies.
    static func observerScript(externalMedia: Bool = false) -> String { #"""
    (() => {
      const externalMedia = \#(externalMedia ? "true" : "false");
      const seen = new WeakSet(); let active = null; let last = 0;
      const mediaURL = video => {
        if (/^https?:/i.test(video.currentSrc || '')) return video.currentSrc;
        const streams = performance.getEntriesByType('resource').map(item => item.name)
          .filter(url => /^https?:/i.test(url) && /\.(m3u8|mp4)(?:[?#]|$)/i.test(url));
        return streams.filter(url => /(?:master|manifest)\.m3u8(?:[?#]|$)/i.test(url)).pop() || streams.pop() || null;
      };
      const send = (video, event) => {
        active = video;
        if (event === 'timeupdate' && performance.now() - last < 900) return;
        last = performance.now();
        window.webkit.messageHandlers.anixartPlayback.postMessage({event,
          seconds: Number.isFinite(video.currentTime) ? video.currentTime : 0,
          duration: Number.isFinite(video.duration) ? video.duration : null,
          paused: video.paused, width: video.videoWidth, height: video.videoHeight,
          ready: video.readyState, code: video.error?.code || 0,
          media: externalMedia || (Number.isFinite(video.duration) && video.duration > 0) ? mediaURL(video) : null});
      };
      const scan = () => document.querySelectorAll('video').forEach(video => {
        if (seen.has(video)) return; seen.add(video); active = video;
        ['loadedmetadata','timeupdate','playing','pause','ended','error'].forEach(event =>
          video.addEventListener(event, () => send(video, event)));
        send(video, 'discovered');
      });
      window.__anixartPlayback = {
        play: () => active?.play().catch(() => {}), pause: () => active?.pause(),
        seek: seconds => { if (active && Number.isFinite(seconds)) { try { active.currentTime = seconds; } catch (_) {} } }
      };
      new MutationObserver(scan).observe(document.documentElement, {childList:true,subtree:true}); scan();
    })();
    """# }
}
