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
    var myVote: Int?
    var votedAt: Int64?
    var lastViewTimestamp: Int64?
    var lastViewEpisode: HistoryEpisode?
    var title: String { titleRu ?? titleOriginal ?? "Релиз №\(id)" }
    var poster: URL? { image.flatMap(URL.init(string:)) }
}

struct Profile: Codable, Identifiable, Hashable, Sendable {
    let id: Int64
    var login: String?
    var avatar: String?
    var status: String?
    var watchingCount: Int?
    var planCount: Int?
    var completedCount: Int?
    var holdOnCount: Int?
    var droppedCount: Int?
    var watchedEpisodeCount: Int64?
    var watchedTime: Int64?
    var watchDynamics: [ProfileWatchDay]?
    var preferredGenres: [ProfileGenre]?
    var preferredAudiences: [ProfileGenre]?
    var preferredThemes: [ProfileGenre]?
    var isStatsHidden: Bool?
    var isCountsHidden: Bool?
    var ratingScore: Int?
    var registerDate: Int64?
    var lastActivityTime: Int64?
    var isOnline: Bool?
    var isVerified: Bool?
    var isSponsor: Bool?
    var isBanned: Bool?
    var isPermBanned: Bool?
    var banExpires: Int64?
    var banReason: String?
    var isDeleted: Bool?
    var isDeletionRequested: Bool?
    var isIncognito: Bool?
    var isBlocked: Bool?
    var isMeBlocked: Bool?
    var isFriendRequestsDisallowed: Bool?
    var isSocialHidden: Bool?
    var friendStatus: Int?
    var friendCount: Int?
    var friendsPreview: [Profile]?
    var roles: [ProfileRole]?
    var badge: ProfileBadge?
    var badgeId: Int64?
    var badgeName: String?
    var badgeType: Int?
    var badgeUrl: String?
    var badgeCount: Int?
    var badgesPreview: [ProfileBadge]?
    var collectionCount: Int?
    var commentCount: Int?
    var videoCount: Int?
    var votes: [Release]?
    var collectionsPreview: [CollectionSummary]?
    var commentsPreview: [ProfileComment]?
    var releaseVideosPreview: [ProfileVideo]?
    var history: [Release]?
    var pinnedSectionId: Int?
    var vkPage: String?
    var tgPage: String?
    var discordPage: String?
    var ttPage: String?
    var instPage: String?
    var themeEnabled: Bool?
    var themeGradientStartColor: String?
    var themeGradientEndColor: String?
    var themeGradientAngle: String?
    var themeIconResName: String?
    var themeIconUrl: String?
    var themeIconAlpha: Double?
    var themeIconColor: String?
    var themeIconSize: String?
    var themeIconDensity: String?
    var themeBackgroundUrl: String?
    var themeBackgroundAlpha: Double?
    var themeBackgroundMode: String?
    var hasStatistics: Bool { watchingCount != nil || completedCount != nil || watchedEpisodeCount != nil }
}

struct ProfileGenre: Codable, Hashable, Sendable {
    let name: String
    let percentage: Int
}
struct ProfileWatchDay: Codable, Hashable, Identifiable, Sendable {
    var serverID: Int64?
    let count: Int
    var day: Int?
    var timestamp: Int64?
    var id: Int64 { serverID.flatMap { $0 > 0 ? $0 : nil } ?? timestamp ?? Int64(day ?? 0) }
    enum CodingKeys: String, CodingKey { case serverID = "id", count, day, timestamp }
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

struct CollectionSummary: Codable, Identifiable, Hashable, Sendable {
    let id: Int64
    var title: String?
    var description: String?
    var image: String?
    var favoriteCount: Int?
    var commentCount: Int?
    var isPrivate: Bool?
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

struct CatalogFilter: Codable, Equatable, Sendable {
    var sort = 0
    var startYear: Int?
    var endYear: Int?
    var genres: [String] = []
    var country: String?
    var categoryId: Int64?
    var statusId: Int64?
    enum CodingKeys: String, CodingKey {
        case sort, genres, country
        case startYear = "start_year", endYear = "end_year"
        case categoryId = "category_id", statusId = "status_id"
    }
}
