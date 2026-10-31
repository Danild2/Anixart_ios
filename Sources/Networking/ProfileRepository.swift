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
}
struct ProfileSocialEdit: Codable, Equatable, Sendable {
    var vkPage: String; var tgPage: String; var instPage: String; var ttPage: String; var discordPage: String
}
struct ProfileSocialResponse: ServiceResponse {
    let code: Int
    var vkPage: String?; var tgPage: String?; var instPage: String?; var ttPage: String?; var discordPage: String?
    var isSocialHidden: Bool?
}
