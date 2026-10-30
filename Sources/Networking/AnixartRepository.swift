import Foundation

struct AnixartRepository: Sendable {
    let client: APIClient
    init(client: APIClient = APIClient()) { self.client = client }

    func catalog(page: Int, filter: CatalogFilter, token: String?) async throws -> Page<Release> {
        try await client.request(Endpoint(path: "filter/\(page)", method: "POST", query: ["extended_mode":"true"],
            body: JSONEncoder().encode(filter)), token: token)
    }
    func search(_ query: String, page: Int, token: String?) async throws -> [Release] {
        struct Body: Encodable { let query: String; let searchBy = 0 }
        let result: SearchResponse = try await client.request(Endpoint(path: "search/releases/\(page)", method: "POST",
            body: JSONEncoder().encode(Body(query: query)), apiVersion: "v2"), token: token)
        return result.releases
    }
    func discover(page: Int, recommendations: Bool, token: String?) async throws -> Page<Release> {
        try await client.request(Endpoint(path: "discover/\(recommendations ? "recommendations" : "watching")/\(page)",
            method: "POST", query: recommendations ? ["previous_page": String(page - 1)] : [:]), token: token)
    }
    func release(_ id: Int64, token: String?) async throws -> Release {
        let response: ReleaseResponse = try await client.request(Endpoint(path: "release/\(id)", query: ["extended_mode":"true"]), token: token)
        return response.release
    }
    func signIn(login: String, password: String) async throws -> LoginResponse {
        try await client.request(Endpoint(path: "auth/signIn", method: "POST",
            body: APIClient.form(["login": login, "password": password]),
            contentType: "application/x-www-form-urlencoded", isReadOnly: false))
    }
    func profile(_ id: Int64, token: String) async throws -> Profile {
        let response: ProfileResponse = try await client.request(Endpoint(path: "profile/\(id)"), token: token)
        return response.profile
    }
    func library(path: String, page: Int, token: String) async throws -> Page<Release> {
        try await client.request(Endpoint(path: "\(path)/\(page)"), token: token)
    }
    func setFavorite(_ id: Int64, enabled: Bool, token: String) async throws {
        let _: Acknowledgement = try await client.request(Endpoint(path: "favorite/\(enabled ? "add" : "delete")/\(id)", isReadOnly: false), token: token)
    }
    func setStatus(_ id: Int64, status: WatchStatus, remove: Bool = false, token: String) async throws {
        let _: Acknowledgement = try await client.request(Endpoint(path: "profile/list/\(remove ? "delete" : "add")/\(status.rawValue)/\(id)", isReadOnly: false), token: token)
    }
    func vote(_ id: Int64, value: Int, token: String) async throws {
        let _: Acknowledgement = try await client.request(Endpoint(path: "release/vote/add/\(id)/\(value)", isReadOnly: false), token: token)
    }
    func types(_ id: Int64, token: String?) async throws -> [Translation] {
        let response: TypesResponse = try await client.request(Endpoint(path: "episode/\(id)"), token: token)
        return response.types
    }
    func sources(_ id: Int64, type: Int64) async throws -> [VideoSource] {
        let response: SourcesResponse = try await client.request(Endpoint(path: "episode/\(id)/\(type)"))
        return response.sources
    }
    func episodes(_ id: Int64, type: Int64, source: Int64, token: String?) async throws -> [Episode] {
        let response: EpisodesResponse = try await client.request(Endpoint(path: "episode/\(id)/\(type)/\(source)", query: ["sort":"0"]), token: token)
        return response.episodes
    }
    func target(_ id: Int64, source: Int64, position: Int) async throws -> Episode {
        let response: TargetResponse = try await client.request(Endpoint(path: "episode/target/\(id)/\(source)/\(position)"))
        return response.episode
    }
    func recordHistory(_ id: Int64, source: Int64, position: Int, token: String) async throws {
        let _: Acknowledgement = try await client.request(Endpoint(path: "history/add/\(id)/\(source)/\(position)", isReadOnly: false), token: token)
    }
    func setEpisodeWatched(_ id: Int64, source: Int64, position: Int? = nil, watched: Bool, token: String) async throws {
        let suffix = position.map { "/\($0)" } ?? ""
        let _: Acknowledgement = try await client.request(Endpoint(path: "episode/\(watched ? "watch" : "unwatch")/\(id)/\(source)\(suffix)",
            method: "POST", isReadOnly: false), token: token)
    }
    func comments(_ id: Int64, page: Int, token: String?) async throws -> Page<ReleaseComment> {
        try await client.request(Endpoint(path: "release/comment/all/\(id)/\(page)", query: ["sort":"0"]), token: token)
    }
    func addComment(_ id: Int64, message: String, spoiler: Bool, token: String) async throws {
        struct Body: Encodable { let message: String; let spoiler: Bool }
        let _: Acknowledgement = try await client.request(Endpoint(path: "release/comment/add/\(id)", method: "POST",
            body: JSONEncoder().encode(Body(message: message, spoiler: spoiler)), isReadOnly: false), token: token)
    }
    func collections(page: Int, token: String?) async throws -> Page<CollectionSummary> {
        try await client.request(Endpoint(path: "collection/all/\(page)", query: ["previous_page":String(page - 1),"where":"0","sort":"0"]), token: token)
    }
    func collectionReleases(_ id: Int64, page: Int, token: String?) async throws -> Page<Release> {
        try await client.request(Endpoint(path: "collection/\(id)/releases/\(page)"), token: token)
    }
    func schedule() async throws -> ScheduleResponse {
        try await client.request(Endpoint(path: "schedule"))
    }
}
