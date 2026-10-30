import Foundation

enum PlaybackTarget: Equatable, Sendable {
    case native(URL)
    case embedded(URL)
}
struct SourceVariant: Sendable { let url: URL; let height: Int }
struct PlaybackResolution: Sendable { let target: PlaybackTarget; let variants: [SourceVariant] }

struct SourceResolver {
    func resolveForPlayback(_ episode: Episode, externalVLC: Bool = false, configuration: PublicConfiguration? = nil) async throws -> PlaybackResolution {
        if let raw = episode.url, let url = URL(string:raw), url.host?.lowercased() == "video.sibnet.ru" {
            let userAgent = configuration?.sibnetRandUserAgent == true ? configuration?.sibnetUserAgent : nil
            return PlaybackResolution(target:.native(try await SibnetResolver(userAgent:userAgent).resolve(url)),variants:[])
        }
        if episode.iframe != true, let raw = episode.url, let url = URL(string: raw),
           AniLibriaResolver.hosts.contains(url.host?.lowercased() ?? "") {
            let variants = try await AniLibriaResolver().resolve(url)
            guard let best = variants.first else { throw APIError.unsupportedMedia }
            return PlaybackResolution(target: .native(best.url), variants: variants)
        }
        return PlaybackResolution(target: try resolve(episode, externalVLC: externalVLC), variants: [])
    }
    func resolve(_ episode: Episode, externalVLC: Bool = false) throws -> PlaybackTarget {
        guard let raw = episode.url, let url = URL(string: raw), let host = url.host, !host.isEmpty,
              ["https", "http"].contains(url.scheme?.lowercased() ?? ""), url.user == nil, url.password == nil else {
            throw APIError.invalidURL
        }
        if episode.iframe == true {
            guard url.scheme == "https" else { throw APIError.unsupportedMedia }
            return .embedded(url)
        }
        if ["m3u8", "mp4", "m4v", "mov"].contains(url.pathExtension.lowercased()) { return .native(url) }
        if externalVLC, ["mkv", "webm", "avi", "ts", "m2ts", "mpeg", "mpg", "ogv"].contains(url.pathExtension.lowercased()) { return .native(url) }
        // Do not misrepresent a provider HTML page as an AVPlayer stream.
        // Provider-specific non-iframe parsers require their own validated adapters.
        throw APIError.unsupportedMedia
    }
}
