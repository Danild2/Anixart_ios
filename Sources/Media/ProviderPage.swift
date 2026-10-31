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
    static func contentAfterAdvertisement(_ source: URL, advertisement: URL?) -> URL? {
        guard let canonical = canonicalKodik(source), let advertisement,
              isKodik(advertisement), advertisement.scheme == "https",
              advertisement.user == nil, advertisement.password == nil,
              advertisement.path == source.path,
              var context = URLComponents(url:advertisement,resolvingAgainstBaseURL:false) else { return nil }
        // Keep the public embed context supplied by the actual advertisement
        // iframe. Removing its uid loses the provider's player context on iOS.
        let items = (context.queryItems ?? []).filter { !["only_a","advert_debug"].contains($0.name) }
        guard items.contains(where:{ $0.name == "uid" && $0.value?.isEmpty == false }) else { return nil }
        context.percentEncodedQuery = (context.percentEncodedQuery ?? "").split(separator:"&",omittingEmptySubsequences:false).filter {
            let key = String($0.split(separator:"=",maxSplits:1,omittingEmptySubsequences:false).first ?? "").removingPercentEncoding ?? ""
            return !["only_a","advert_debug"].contains(key)
        }.joined(separator:"&")
        context.fragment = canonical.fragment
        return context.url
    }
    static func isAdvertisementDocument(_ url: URL?) -> Bool {
        guard let url else { return false }
        if url.host?.lowercased() == "anixmirai.com", url.path == "/iframe/ad" { return true }
        guard isKodik(url), let query = URLComponents(url:url,resolvingAgainstBaseURL:false)?.queryItems else { return false }
        return query.contains { $0.name == "only_a" && ["true","1"].contains($0.value?.lowercased() ?? "") }
    }
    static func initial(_ url: URL, configuration: PublicConfiguration? = nil) -> URL? {
        guard url.scheme == "https", url.user == nil, url.password == nil else { return nil }
        let kodik = canonicalKodik(url)
        if let kodik, !requiresAdvertisement(url,configuration:configuration) { return kodik }
        return iframe(kodik ?? url,advertisement:kodik != nil)
    }
    static func iframe(_ url: URL, advertisement: Bool = false) -> URL? {
        guard url.scheme == "https", url.user == nil, url.password == nil else { return nil }
        var wrapper = URLComponents(string:advertisement ? "https://anixmirai.com/iframe/ad" : "https://anixmirai.com/iframe")!
        let unreserved = CharacterSet(charactersIn:"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~")
        wrapper.percentEncodedQuery = "url=" + (url.absoluteString.addingPercentEncoding(withAllowedCharacters:unreserved) ?? "")
            + (advertisement ? "&v=26101718" : "")
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
