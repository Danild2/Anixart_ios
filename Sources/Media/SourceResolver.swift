import Foundation

enum PlaybackTarget: Equatable, Sendable {
    case native(URL)
    case embedded(URL)
}

struct SourceResolver {
    func resolve(_ episode: Episode) throws -> PlaybackTarget {
        guard let raw = episode.url, let url = URL(string: raw), let host = url.host, !host.isEmpty,
              ["https", "http"].contains(url.scheme?.lowercased() ?? ""), url.user == nil, url.password == nil else {
            throw APIError.invalidURL
        }
        if episode.iframe == true {
            guard url.scheme == "https" else { throw APIError.unsupportedMedia }
            return .embedded(url)
        }
        if ["m3u8", "mp4", "m4v", "mov"].contains(url.pathExtension.lowercased()) { return .native(url) }
        // Do not misrepresent a provider HTML page as an AVPlayer stream.
        // Provider-specific non-iframe parsers require their own validated adapters.
        throw APIError.unsupportedMedia
    }
}
