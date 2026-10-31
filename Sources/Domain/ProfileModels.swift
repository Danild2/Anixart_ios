import Foundation

struct HistoryEpisode: Codable, Hashable, Sendable { var name: String?; var position: Int? }
struct ProfileRole: Codable, Hashable, Identifiable, Sendable { let id: Int64; var name: String?; var color: String? }
struct ProfileBadge: Codable, Hashable, Identifiable, Sendable {
    let id: Int64
    var name: String?
    var type: Int?
    var imageUrl: String?
    var imageSmallUrl: String?
    var imageMediumUrl: String?
    var imagePreviewUrl: String?
    var description: String?
    var ownershipPercentage: Double?
    var rarity: String?
    var timestamp: Int64?
    var isShowcased: Bool?
    var isSelected: Bool?
    var isOwned: Bool?
    var thumbnail: URL? { (imagePreviewUrl ?? imageMediumUrl ?? imageSmallUrl ?? (type == 1 ? nil : imageUrl)).flatMap(URL.init(string:)) }
}
struct ProfileComment: Codable, Hashable, Identifiable, Sendable {
    let id: Int64
    var message: String?
    var profile: Profile?
    var release: Release?
    var collection: CollectionSummary?
    var article: ProfileArticle?
    var isSpoiler: Bool?
    var isDeleted: Bool?
    var isEdited: Bool?
    var voteCount: Int?
    var replyCount: Int?
    var timestamp: Int64?
}
struct ProfileVideo: Codable, Hashable, Identifiable, Sendable {
    let id: Int64
    var title: String?
    var image: String?
    var url: String?
    var playerUrl: String?
    var release: Release?
    var profile: Profile?
    var timestamp: Int64?
    var category: NamedProfileItem?
    var hosting: NamedProfileItem?
}
struct NamedProfileItem: Codable, Hashable, Sendable { var id: Int64?; var name: String?; var icon: String? }
struct ProfileChannel: Codable, Hashable, Identifiable, Sendable {
    let id: Int64
    var title: String?
    var avatar: String?
    var cover: String?
    var description: String?
    var articleCount: Int?
    var isBlog: Bool?
    var blogProfileId: Int64?
}
struct ProfileArticle: Codable, Hashable, Identifiable, Sendable {
    let id: Int64
    var channel: ProfileChannel?
    var author: Profile?
    var payload: ArticlePayload?
    var creationDate: Int64?
    var commentCount: Int?
    var voteCount: Int?
    var repostCount: Int?
    var isPinned: Bool?
    var isDeleted: Bool?
}
// Block data is heterogeneous in the original Editor.js payload. Preserve it to
// render each block without discarding text or failing an entire profile page.
indirect enum ArticleValue: Codable, Hashable, Sendable {
    case text(String), number(Double), bool(Bool), object([String: ArticleValue]), array([ArticleValue]), null
    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if c.decodeNil() { self = .null }
        else if let v = try? c.decode(String.self) { self = .text(v) }
        else if let v = try? c.decode(Bool.self) { self = .bool(v) }
        else if let v = try? c.decode(Double.self) { self = .number(v) }
        else if let v = try? c.decode([String: ArticleValue].self) { self = .object(v) }
        else { self = .array(try c.decode([ArticleValue].self)) }
    }
    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self {
        case .text(let v): try c.encode(v)
        case .number(let v): try c.encode(v)
        case .bool(let v): try c.encode(v)
        case .object(let v): try c.encode(v)
        case .array(let v): try c.encode(v)
        case .null: try c.encodeNil()
        }
    }
    var string: String? { if case .text(let s) = self { s } else { nil } }
    var items: [ArticleValue] { if case .array(let a) = self { a } else { [] } }
    subscript(_ key: String) -> ArticleValue { if case .object(let o) = self { o[key] ?? .null } else { .null } }
}
struct ArticlePayload: Codable, Hashable, Sendable { var blocks: [ArticleBlock]?; var version: String?; var time: Int64? }
struct ArticleBlock: Codable, Hashable, Sendable { var id: String?; var type: String; var data: ArticleValue }
struct ProfileBadgeSection: Codable, Sendable, Identifiable { let id: Int64; var title: String?; var count: Int?; var content: [ProfileBadge]? }
struct ProfileBadgesResponse: ServiceResponse { let code: Int; var sections: [ProfileBadgeSection]?; var showcased: [ProfileBadge]?; var recent: [ProfileBadge]? }
struct ProfileChannelResponse: ServiceResponse { let code: Int; var channel: ProfileChannel? }
struct ProfileArticleResponse: ServiceResponse { let code: Int; let article: ProfileArticle }
