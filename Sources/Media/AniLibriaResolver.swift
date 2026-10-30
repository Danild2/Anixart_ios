import Foundation

/// APK 10.5 AniLibriaParser uses this public API, without partner keys or account tokens.
struct AniLibriaResolver: Sendable {
    static let hosts: Set<String> = ["anilibria.tv", "new.anilib.one", "anixart.libria.fun", "anilibria.top"]
    struct Reference: Equatable, Sendable { let release: Int; let ordinal: Int }
    static func reference(_ url: URL) throws -> Reference {
        guard url.scheme == "https", hosts.contains(url.host?.lowercased() ?? ""), url.user == nil, url.password == nil,
              let query = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems else { throw APIError.unsupportedMedia }
        let ids = query.filter { $0.name == "id" }, episodes = query.filter { $0.name == "ep" }
        guard ids.count == 1, episodes.count == 1, let release = ids[0].value.flatMap(Int.init), release > 0,
              let ordinal = episodes[0].value.flatMap(Int.init), ordinal > 0 else { throw APIError.invalidURL }
        return Reference(release: release, ordinal: ordinal)
    }
    static func parse(_ data: Data, ordinal: Int) throws -> [SourceVariant] {
        struct Response: Decodable {
            struct Episode: Decodable {
                let ordinal: Int
                let hls480: String?
                let hls720: String?
                let hls1080: String?
                enum CodingKeys: String, CodingKey { case ordinal; case hls480 = "hls_480", hls720 = "hls_720", hls1080 = "hls_1080" }
            }
            let episodes: [Episode]
        }
        let response = try JSONDecoder().decode(Response.self, from: data)
        guard let episode = response.episodes.first(where: { $0.ordinal == ordinal }) else { throw APIError.unsupportedMedia }
        let values: [(Int, String?)] = [(1080, episode.hls1080), (720, episode.hls720), (480, episode.hls480)]
        let variants = values.compactMap { height, raw -> SourceVariant? in
            guard let raw, let url = URL(string: raw), url.scheme == "https", url.host != nil,
                  url.user == nil, url.password == nil else { return nil }
            return SourceVariant(url: url, height: height)
        }
        guard !variants.isEmpty else { throw APIError.unsupportedMedia }
        return variants
    }
    func resolve(_ url: URL) async throws -> [SourceVariant] {
        let reference = try Self.reference(url)
        let endpoint = URL(string: "https://anilibria.top/api/v1/anime/releases/\(reference.release)")!
        var request = URLRequest(url: endpoint); request.timeoutInterval = 25
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let configuration = URLSessionConfiguration.ephemeral; configuration.urlCache = nil
        let session = URLSession(configuration: configuration)
        defer { session.invalidateAndCancel() }
        let (bytes, response) = try await session.bytes(for: request)
        guard let response = response as? HTTPURLResponse else { throw APIError.malformed }
        guard response.statusCode == 200 else { throw APIError.http(response.statusCode) }
        let limit = 8_000_000
        guard response.expectedContentLength <= limit else { throw APIError.malformed }
        var data = Data()
        for try await byte in bytes {
            guard data.count < limit else { throw APIError.malformed }
            data.append(byte)
        }
        return try Self.parse(data, ordinal: reference.ordinal)
    }
}
