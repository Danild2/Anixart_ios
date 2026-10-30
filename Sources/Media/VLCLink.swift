import Foundation

/// Parameters supported by VideoLAN's current XCallbackURLHandler.
struct VLCLink {
    static func stream(media: URL, title: String, subtitles: URL? = nil, requestID: UUID) throws -> URL {
        guard ["https", "http"].contains(media.scheme ?? ""), media.host != nil, media.user == nil, media.password == nil else { throw APIError.invalidURL }
        var url = URLComponents()
        url.scheme = "vlc-x-callback"; url.host = "x-callback-url"; url.path = "/stream"
        var items = [URLQueryItem(name: "url", value: media.absoluteString), URLQueryItem(name: "filename", value: title)]
        if let subtitles {
            guard ["https", "http"].contains(subtitles.scheme ?? ""), subtitles.host != nil, subtitles.user == nil, subtitles.password == nil else { throw APIError.invalidURL }
            items.append(URLQueryItem(name: "sub", value: subtitles.absoluteString))
        }
        for outcome in ["success", "error"] {
            var callback = URLComponents()
            callback.scheme = "anixartport"; callback.host = "vlc-return"
            callback.queryItems = [URLQueryItem(name: "request", value: requestID.uuidString), URLQueryItem(name: "outcome", value: outcome)]
            items.append(URLQueryItem(name: "x-\(outcome)", value: callback.string))
        }
        // VideoLAN's parser decodes a nested URL only when its :// is escaped too.
        let unreserved = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~")
        url.percentEncodedQuery = try items.map { item in
            guard let value = (item.value ?? "").addingPercentEncoding(withAllowedCharacters: unreserved) else { throw APIError.invalidURL }
            return item.name + "=" + value
        }.joined(separator: "&")
        guard let result = url.url else { throw APIError.invalidURL }
        return result
    }
}
