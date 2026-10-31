import Foundation

extension AnixartRepository {
    func profilePage<T: Decodable & Sendable>(_ path: String, page: Int, query: [String:String] = [:], token: String?) async throws -> Page<T> {
        try await client.request(Endpoint(path:"\(path)/\(page)",query:query),token:token)
    }
    func profileBlog(_ id: Int64, token: String?) async throws -> ProfileChannel? {
        // Original code 2 means that the profile has not created a blog yet.
        let response: ProfileChannelResponse = try await client.request(Endpoint(path:"channel/blog/\(id)",acceptedCodes:[0,2]),token:token)
        return response.channel
    }
    func blogArticles(_ id: Int64, page: Int, token: String?) async throws -> Page<ProfileArticle> {
        try await client.request(Endpoint(path:"feed/all/\(page)",query:["channel_id":String(id),"date":"0"]),token:token)
    }
    func profileBadges(_ id: Int64, token: String?) async throws -> ProfileBadgesResponse {
        try await client.request(Endpoint(path:"profile/\(id)/badge/list",query:["recent":"true"]),token:token)
    }
    func article(_ id: Int64, token: String?) async throws -> ProfileArticle {
        let response: ProfileArticleResponse = try await client.request(Endpoint(path:"article/\(id)"),token:token)
        return response.article
    }
    func friend(_ id: Int64, action: String, token: String) async throws {
        guard ["send","remove","hide"].contains(action) else { throw APIError.invalidURL }
        let _: Acknowledgement = try await client.request(Endpoint(path:"profile/friend/request/\(action)/\(id)",isReadOnly:false),token:token)
    }
    func editProfileStatus(_ status: String, token: String) async throws {
        struct Body: Encodable { let status: String }
        let _: Acknowledgement = try await client.request(Endpoint(path:"profile/preference/status/edit",method:"POST",body:JSONEncoder().encode(Body(status:status)),isReadOnly:false),token:token)
    }
    func editProfileSocial(_ social: ProfileSocialEdit, token: String) async throws {
        let _: Acknowledgement = try await client.request(Endpoint(path:"profile/preference/social/edit",method:"POST",body:JSONEncoder().encode(social),isReadOnly:false),token:token)
    }
    func pinProfileSection(_ id: Int, token: String) async throws {
        struct Body: Encodable { let id: Int }
        let _: Acknowledgement = try await client.request(Endpoint(path:"profile/preference/section/edit",method:"POST",body:JSONEncoder().encode(Body(id:id)),isReadOnly:false),token:token)
    }
    func profileSocial(_ id: Int64, token: String?) async throws -> ProfileSocialResponse {
        try await client.request(Endpoint(path:"profile/social/\(id)"),token:token)
    }
    func profilePreferences(token: String) async throws -> ProfilePreferences {
        try await client.request(Endpoint(path:"profile/preference/my"),token:token)
    }
    func editProfilePrivacy(_ key: String, permission: Int, token: String) async throws {
        guard ["stats","counts","social","friendRequests"].contains(key), (0...2).contains(permission) else { throw APIError.invalidURL }
        struct Body: Encodable { let permission: Int }
        let _: Acknowledgement = try await client.request(Endpoint(path:"profile/preference/privacy/\(key)/edit",method:"POST",body:JSONEncoder().encode(Body(permission:permission)),isReadOnly:false),token:token)
    }
    func selectProfileTheme(_ id: Int64, token: String) async throws {
        struct Body: Encodable { let id: Int64 }
        let _: Acknowledgement = try await client.request(Endpoint(path:"profile/preference/themes/edit",method:"POST",body:JSONEncoder().encode(Body(id:id)),isReadOnly:false),token:token)
    }
    func toggleProfileIncognito(token: String) async throws {
        let _: Acknowledgement = try await client.request(Endpoint(path:"profile/preference/privacy/incognito/edit",isReadOnly:false),token:token)
    }
    func editProfileAvatar(_ jpeg: Data?, token: String) async throws {
        guard let jpeg else {
            let _: Acknowledgement = try await client.request(Endpoint(path:"profile/preference/avatar/delete",isReadOnly:false),token:token)
            return
        }
        guard !jpeg.isEmpty, jpeg.count <= 8_000_000 else { throw APIError.malformed }
        let boundary = "Anixart-\(UUID().uuidString)"
        var body = Data("--\(boundary)\r\nContent-Disposition: form-data; name=\"name\"\r\n\r\navatar.jpg\r\n--\(boundary)\r\nContent-Disposition: form-data; name=\"image\"; filename=\"avatar.jpg\"\r\nContent-Type: image/jpeg\r\n\r\n".utf8)
        body.append(jpeg); body.append(Data("\r\n--\(boundary)--\r\n".utf8))
        let _: Acknowledgement = try await client.request(Endpoint(path:"profile/preference/avatar/edit",method:"POST",body:body,contentType:"multipart/form-data; boundary=\(boundary)",isReadOnly:false),token:token)
    }
}
struct ProfileSocialEdit: Codable, Equatable, Sendable {
    var vkPage: String; var tgPage: String; var instPage: String; var ttPage: String; var discordPage: String
}
struct ProfileSocialResponse: ServiceResponse {
    let code: Int
    var vkPage: String?; var tgPage: String?; var instPage: String?; var ttPage: String?; var discordPage: String?
    var isSocialHidden: Bool?
}
struct ProfilePreferences: ServiceResponse {
    let code: Int
    var privacyStats: Int?
    var privacyCounts: Int?
    var privacySocial: Int?
    var privacyFriendRequests: Int?
    var isIncognito: Bool?
    var selectedThemeId: Int64?
    var availableThemes: [AvailableProfileTheme]?
    var isChangeAvatarBanned: Bool?
}
struct AvailableProfileTheme: Decodable, Identifiable, Sendable { let id: Int64; let name: String }
