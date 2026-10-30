import Foundation

enum ProviderPage {
    static let kodikHosts: Set<String> = ["kodik.cc", "kodik.info", "aniqit.com", "kodikplayer.com", "kodik-hd.com", "kodik.biz"]
    static func isKodik(_ url: URL) -> Bool { kodikHosts.contains(url.host?.lowercased() ?? "") }
    static func requiresAdvertisement(_ url: URL, configuration: PublicConfiguration?) -> Bool {
        isKodik(url) && configuration?.kodikIframeAd != false
    }
    static func canonicalKodik(_ url: URL) -> URL? {
        guard isKodik(url), url.scheme == "https", url.user == nil, url.password == nil,
              var value = URLComponents(url:url,resolvingAgainstBaseURL:false) else { return nil }
        // This is the URI used by KodikAdActivity, not a fabricated media endpoint.
        value.query = nil
        return value.url
    }
    static func initial(_ url: URL, configuration: PublicConfiguration? = nil) -> URL? {
        guard url.scheme == "https", url.user == nil, url.password == nil else { return nil }
        let kodik = canonicalKodik(url)
        if let kodik, !requiresAdvertisement(url,configuration:configuration) { return kodik }
        var wrapper = URLComponents(string:kodik == nil ? "https://anixmirai.com/iframe" : "https://anixmirai.com/iframe/ad")!
        let unreserved = CharacterSet(charactersIn:"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~")
        wrapper.percentEncodedQuery = "url=" + ((kodik ?? url).absoluteString.addingPercentEncoding(withAllowedCharacters:unreserved) ?? "")
            + (kodik == nil ? "" : "&v=26101718")
        return wrapper.url
    }
    static func permitsAdCallback(origin: String, expected: URL) -> Bool {
        isKodik(expected) && (origin == "anixmirai.com" || kodikHosts.contains(origin))
    }
    static func isOriginalAdServerFailure(_ url: URL?, status: Int) -> Bool {
        guard let url else { return false }
        // KodikAdActivity's WebViewClient handles this specific provider failure.
        return status == 500 && isKodik(url) && url.path.contains("/ftor")
    }
    // The provider calls its original Android interface after completing its ad flow.
    // There is no timer, synthetic completion, or extraction while the ad is active.
    static let adBridge = #"""
    (() => {
      const allowed = ['anixmirai.com','kodik.cc','kodik.info','aniqit.com','kodikplayer.com','kodik-hd.com','kodik.biz'];
      if (!allowed.includes(location.hostname)) return;
      window.KodikInterface = {advertEnded: () => window.webkit.messageHandlers.anixartKodikAd.postMessage('advertEnded')};
      if (location.hostname === 'anixmirai.com') return;
      let last = null;
      const ready = () => {
        const target = document.querySelector('.play_background');
        const box = target?.getBoundingClientRect();
        const style = target ? getComputedStyle(target) : null;
        const visible = !!(box?.width && box?.height && style.display !== 'none' && style.visibility !== 'hidden' && Number(style.opacity) > 0);
        if (visible !== last) {
          last = visible;
          window.webkit.messageHandlers.anixartKodikAd.postMessage(visible ? 'playControlReady' : 'playControlHidden');
        }
      };
      const install = () => {
        new MutationObserver(ready).observe(document.documentElement, {subtree:true,childList:true,attributes:true,attributeFilter:['class','style','hidden']});
        requestAnimationFrame(() => requestAnimationFrame(ready));
        window.addEventListener('load', ready, {once:true});
      };
      if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', install, {once:true}); else install();
    })();
    """#
}
