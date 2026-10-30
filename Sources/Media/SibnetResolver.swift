import Foundation

struct SibnetResolver: Sendable {
    static let userAgent = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/86.0.4240.198 Safari/537.36"
    private let session: URLSession
    init(session: URLSession? = nil) {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.urlCache = nil; configuration.httpShouldSetCookies = false
        configuration.timeoutIntervalForRequest = 20; configuration.timeoutIntervalForResource = 30
        self.session = session ?? URLSession(configuration:configuration,delegate:ProviderNoRedirects(),delegateQueue:nil)
    }
    static func mediaURL(in html: String, page: URL) throws -> URL {
        let expression = try NSRegularExpression(pattern:#"\bsrc\s*:\s*["']([^"']+)["']"#)
        for match in expression.matches(in:html,range:NSRange(html.startIndex..<html.endIndex,in:html)) {
            guard let range = Range(match.range(at:1),in:html) else { continue }
            let raw = String(html[range]).replacingOccurrences(of:#"\/"#,with:"/")
            guard let url = URL(string:raw,relativeTo:page)?.absoluteURL, url.host == "video.sibnet.ru",
                  url.path.hasPrefix("/v/") || ["mp4","m3u8"].contains(url.pathExtension.lowercased()) else { continue }
            return try validated(url)
        }
        throw APIError.unsupportedMedia
    }
    private static func validated(_ url: URL) throws -> URL {
        guard url.scheme == "https", let host = url.host?.lowercased(), host == "video.sibnet.ru" || host.hasSuffix(".sibnet.ru"),
              url.user == nil, url.password == nil else { throw APIError.invalidURL }
        var components = URLComponents(url:url,resolvingAgainstBaseURL:false)!
        if components.port == 443 { components.port = nil }
        guard let result = components.url else { throw APIError.invalidURL }; return result
    }
    func resolve(_ page: URL) async throws -> URL {
        guard page.host?.lowercased() == "video.sibnet.ru" else { throw APIError.unsupportedMedia }
        _ = try Self.validated(page)
        defer { session.invalidateAndCancel() }
        var request = URLRequest(url:page)
        request.setValue(Self.userAgent,forHTTPHeaderField:"User-Agent")
        request.setValue("text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",forHTTPHeaderField:"Accept")
        let (bytes, response) = try await session.bytes(for:request)
        guard let response = response as? HTTPURLResponse else { throw APIError.malformed }
        guard response.statusCode == 200 else { throw APIError.http(response.statusCode) }
        var data = Data()
        for try await byte in bytes {
            guard data.count < 2_000_000 else { throw APIError.malformed }; data.append(byte)
        }
        guard let html = String(data:data,encoding:.utf8) ?? String(data:data,encoding:.windowsCP1251) else { throw APIError.malformed }
        var current = try Self.mediaURL(in:html,page:page)
        // The original parser supplies Referer while obtaining the first signed redirect,
        // then follows the provider's media redirects without forwarding page credentials.
        for hop in 0..<5 {
            var media = URLRequest(url:current)
            media.setValue(Self.userAgent,forHTTPHeaderField:"User-Agent")
            media.setValue("bytes=0-1",forHTTPHeaderField:"Range")
            if hop == 0 { media.setValue(page.absoluteString,forHTTPHeaderField:"Referer") }
            let (_, response) = try await session.bytes(for:media)
            guard let response = response as? HTTPURLResponse else { throw APIError.malformed }
            if [301,302,303,307,308].contains(response.statusCode),
               let location = response.value(forHTTPHeaderField:"Location"), let next = URL(string:location,relativeTo:current)?.absoluteURL {
                current = try Self.validated(next); continue
            }
            guard [200,206].contains(response.statusCode) else { throw APIError.http(response.statusCode) }
            let mime = response.mimeType?.lowercased() ?? ""
            guard mime.hasPrefix("video/") || mime == "application/octet-stream" || mime.contains("mpegurl") else { throw APIError.unsupportedMedia }
            return current
        }
        throw APIError.unsupportedMedia
    }
}

private final class ProviderNoRedirects: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    func urlSession(_ session: URLSession,task: URLSessionTask,willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest,completionHandler: @escaping (URLRequest?) -> Void) { completionHandler(nil) }
}
