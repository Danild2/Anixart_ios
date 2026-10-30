import Foundation

enum ProviderPage {
    static let kodikHosts: Set<String> = ["kodik.cc", "kodik.info", "aniqit.com", "kodikplayer.com", "kodik-hd.com", "kodik.biz"]
    static func isKodik(_ url: URL) -> Bool { kodikHosts.contains(url.host?.lowercased() ?? "") }
    static func canonicalKodik(_ url: URL) -> URL? {
        guard isKodik(url), url.scheme == "https", url.user == nil, url.password == nil,
              var value = URLComponents(url:url,resolvingAgainstBaseURL:false) else { return nil }
        // This is the URI used by KodikAdActivity, not a fabricated media endpoint.
        value.query = nil
        return value.url
    }
    static func initial(_ url: URL) -> URL? {
        guard url.scheme == "https", url.user == nil, url.password == nil else { return nil }
        let kodik = canonicalKodik(url)
        var wrapper = URLComponents(string:kodik == nil ? "https://anixmirai.com/iframe" : "https://anixmirai.com/iframe/ad")!
        let unreserved = CharacterSet(charactersIn:"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~")
        wrapper.percentEncodedQuery = "url=" + ((kodik ?? url).absoluteString.addingPercentEncoding(withAllowedCharacters:unreserved) ?? "")
            + (kodik == nil ? "" : "&v=26101718")
        return wrapper.url
    }
    static func permitsAdCallback(origin: String, expected: URL) -> Bool {
        isKodik(expected) && (origin == "anixmirai.com" || kodikHosts.contains(origin))
    }
    // The provider calls its original Android interface after completing its ad flow.
    // There is no timer, synthetic completion, or extraction while the ad is active.
    static let adBridge = #"""
    (() => {
      const allowed = ['anixmirai.com','kodik.cc','kodik.info','aniqit.com','kodikplayer.com','kodik-hd.com','kodik.biz'];
      if (!allowed.includes(location.hostname)) return;
      window.KodikInterface = {advertEnded: () => window.webkit.messageHandlers.anixartKodikAd.postMessage('advertEnded')};
    })();
    """#
}
