import Foundation

protocol ServiceResponse: Decodable, Sendable { var code: Int { get } }
struct Acknowledgement: ServiceResponse { let code: Int }
struct Page<T: Decodable & Sendable>: ServiceResponse {
    let code: Int
    let content: [T]
    var currentPage: Int?
    var totalPageCount: Int?
    var totalCount: Int?
}
struct SearchResponse: ServiceResponse {
    let code: Int
    let releases: [Release]
}
struct ReleaseResponse: ServiceResponse { let code: Int; let release: Release }
struct ProfileResponse: ServiceResponse { let code: Int; let profile: Profile }
struct LoginResponse: ServiceResponse {
    let code: Int
    var profile: Profile?
    var profileToken: ProfileToken?
}
struct ProfileToken: Codable, Sendable { let token: String }
struct TypesResponse: ServiceResponse { let code: Int; let types: [Translation] }
struct SourcesResponse: ServiceResponse { let code: Int; let sources: [VideoSource] }
struct EpisodesResponse: ServiceResponse { let code: Int; let episodes: [Episode] }
struct TargetResponse: ServiceResponse { let code: Int; let episode: Episode }

enum APIError: LocalizedError, Equatable {
    case http(Int), service(Int), schema(String), malformed, unauthorized, invalidURL, unsupportedMedia
    var errorDescription: String? {
        switch self {
        case .http(403): "Сервер отказал в доступе (HTTP 403). Проверьте VPN и доступность оригинального приложения."
        case .http(let code): "Ошибка сервера: HTTP \(code)."
        case .service(let code): "Anixart отклонил запрос: код \(code)."
        case .unauthorized: "Сессия завершилась. Войдите повторно."
        case .malformed: "Ответ сервера не соответствует ожидаемому формату."
        case .schema(let field): "Неожиданный формат поля ответа: \(field)."
        case .invalidURL: "Некорректный адрес сервера или видео."
        case .unsupportedMedia: "Для этого источника пока нет проверенного адаптера iOS."
        }
    }
}
