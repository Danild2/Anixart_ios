import Foundation

struct Release: Codable, Identifiable, Hashable, Sendable {
    let id: Int64
    var titleRu: String?
    var titleOriginal: String?
    var image: String?
    var description: String?
    var year: String?
    var genres: String?
    var studio: String?
    var country: String?
    var grade: Double?
    var episodesReleased: Int?
    var episodesTotal: Int?
    var isFavorite: Bool?
    var profileListStatus: Int?
    var isPlayDisabled: Bool?
    var isViewBlocked: Bool?
    var relatedReleases: [Release]?
    var recommendedReleases: [Release]?
    var title: String { titleRu ?? titleOriginal ?? "Релиз №\(id)" }
    var poster: URL? { image.flatMap(URL.init(string:)) }
}

struct Profile: Codable, Identifiable, Hashable, Sendable {
    let id: Int64
    var login: String?
    var avatar: String?
    var status: String?
}

struct Translation: Codable, Identifiable, Hashable, Sendable {
    let id: Int64
    let name: String
    var isSub: Bool?
    var episodesCount: Int?
}

struct VideoSource: Codable, Identifiable, Hashable, Sendable {
    let id: Int64
    let name: String
    var quality: Int?
    var episodesCount: Int?
}

struct Episode: Codable, Identifiable, Hashable, Sendable {
    // APK entity id belongs to local persistence; live episode objects may omit it.
    var serverID: Int64?
    let position: Int
    var name: String?
    var url: String?
    var iframe: Bool?
    var quality: Int?
    var isWatched: Bool?
    var isFiller: Bool?
    var id: Int { position }
    var title: String { name?.isEmpty == false ? name! : "Серия \(position)" }
    enum CodingKeys: String, CodingKey { case serverID = "id", position, name, url, iframe, quality, isWatched, isFiller }
    init(id: Int64? = nil, position: Int, name: String? = nil, url: String? = nil, iframe: Bool? = nil,
         quality: Int? = nil, isWatched: Bool? = nil, isFiller: Bool? = nil) {
        serverID = id; self.position = position; self.name = name; self.url = url; self.iframe = iframe
        self.quality = quality; self.isWatched = isWatched; self.isFiller = isFiller
    }
}

struct ReleaseComment: Codable, Identifiable, Sendable {
    let id: Int64
    var message: String?
    var profile: Profile?
    var isSpoiler: Bool?
    var voteCount: Int?
}

struct CollectionSummary: Codable, Identifiable, Sendable {
    let id: Int64
    var title: String?
    var description: String?
    var image: String?
}

enum WatchStatus: Int, CaseIterable, Identifiable, Sendable {
    case watching = 1, planned = 2, completed = 3, onHold = 4, dropped = 5
    var id: Int { rawValue }
    var title: String {
        switch self {
        case .watching: "Смотрю"
        case .planned: "В планах"
        case .completed: "Просмотрено"
        case .onHold: "Отложено"
        case .dropped: "Брошено"
        }
    }
}

struct CatalogFilter: Encodable, Equatable, Sendable {
    var sort = 0
    var startYear: Int?
    var endYear: Int?
    var genres: [String] = []
    enum CodingKeys: String, CodingKey {
        case sort, genres
        case startYear = "start_year", endYear = "end_year"
    }
}
