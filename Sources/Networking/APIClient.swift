import Foundation

struct Endpoint: Sendable {
    let path: String
    var method = "GET"
    var query: [String: String] = [:]
    var body: Data?
    var contentType = "application/json"
    var apiVersion: String?
    // Some APK mutations use GET. HTTP verb is not a sufficient retry policy.
    var isReadOnly = true
    var headers: [String: String] = [:]
    var acceptedCodes: Set<Int> = [0]
}

extension Notification.Name {
    static let sessionUnauthorized = Notification.Name("Anixart.SessionUnauthorized")
}

actor APIClient {
    static let primaryURL = URL(string: "https://api-s.anixsekai.com/")!
    static let regionalURL = URL(string: "https://api.anixsekai.com/")!
    private let session: URLSession
    private let baseURL: URL
    private var publicConfigurationCache: (value: PublicConfiguration, expires: Date)?

    init(baseURL: URL = primaryURL, session: URLSession? = nil) {
        self.baseURL = baseURL
        if let session { self.session = session } else {
            let config = URLSessionConfiguration.ephemeral
            config.timeoutIntervalForRequest = 25
            config.timeoutIntervalForResource = 45
            config.urlCache = nil // Auth tokens are query parameters in the original protocol.
            self.session = URLSession(configuration: config, delegate: SameOriginRedirects(), delegateQueue: nil)
        }
    }

    static func decoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return decoder
    }

    func publicConfiguration() async throws -> PublicConfiguration {
        if let cached = publicConfigurationCache, cached.expires > Date() { return cached.value }
        let value: PublicConfiguration = try await request(Endpoint(path:"config/toggles", query:[
            "version_code":"26101718", "is_beta":"false", "is_api_alt":baseURL == Self.regionalURL ? "true" : "false"
        ]))
        publicConfigurationCache = (value,Date().addingTimeInterval(300))
        return value
    }

    static func form(_ fields: [String: String]) -> Data {
        var components = URLComponents()
        components.queryItems = fields.sorted { $0.key < $1.key }.map { URLQueryItem(name: $0.key, value: $0.value) }
        // URLComponents keeps '+' unescaped; form parsers interpret it as a space.
        return Data((components.percentEncodedQuery ?? "").replacingOccurrences(of: "+", with: "%2B").utf8)
    }

    private static func decodingFailure(_ error: Error) -> APIError {
        let path: [any CodingKey]
        switch error {
        case DecodingError.keyNotFound(let key, let context): path = context.codingPath + [key]
        case DecodingError.typeMismatch(_, let context), DecodingError.valueNotFound(_, let context), DecodingError.dataCorrupted(let context): path = context.codingPath
        default: return .malformed
        }
        // Only schema key names/indices; never raw response values or credentials.
        return .schema(path.map(\.stringValue).joined(separator: "."))
    }

    func request<T: ServiceResponse>(_ endpoint: Endpoint, token: String? = nil) async throws -> T {
        guard [Self.primaryURL.host, Self.regionalURL.host].contains(baseURL.host), baseURL.scheme == "https",
              !endpoint.path.contains(".."), !endpoint.path.contains(":") else { throw APIError.invalidURL }
        var components = URLComponents(url: baseURL.appendingPathComponent(endpoint.path), resolvingAgainstBaseURL: false)!
        var query = endpoint.query
        if let token, !token.isEmpty { query["token"] = token }
        components.queryItems = query.sorted { $0.key < $1.key }.map { URLQueryItem(name: $0.key, value: $0.value) }
        guard let url = components.url else { throw APIError.invalidURL }
        var request = URLRequest(url: url)
        request.httpMethod = endpoint.method
        request.httpBody = endpoint.body
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if endpoint.body != nil { request.setValue(endpoint.contentType, forHTTPHeaderField: "Content-Type") }
        if let version = endpoint.apiVersion { request.setValue(version, forHTTPHeaderField: "API-Version") }
        for (name, value) in endpoint.headers { request.setValue(value, forHTTPHeaderField: name) }
        let attempts = endpoint.isReadOnly ? 2 : 1
        for attempt in 0..<attempts {
            try Task.checkCancellation()
            do {
                let (data, response) = try await session.data(for: request)
                guard let http = response as? HTTPURLResponse else { throw APIError.malformed }
                if http.statusCode == 401 {
                    if let token { NotificationCenter.default.post(name: .sessionUnauthorized, object: token) }
                    throw APIError.unauthorized
                }
                if [502, 503, 504].contains(http.statusCode), attempt + 1 < attempts {
                    try await Task.sleep(for: .milliseconds(500)); continue
                }
                guard (200..<300).contains(http.statusCode) else { throw APIError.http(http.statusCode) }
                // Inspect code before decoding success-only fields of an error envelope.
                let acknowledgement: Acknowledgement
                do {
                    if endpoint.path == "config/toggles", endpoint.method == "GET", token == nil {
                        // The official public configuration omits code on success.
                        let configuration = try Self.decoder().decode(PublicConfiguration.self,from:data)
                        acknowledgement = Acknowledgement(code:configuration.code)
                    } else { acknowledgement = try Self.decoder().decode(Acknowledgement.self, from: data) }
                }
                catch { throw Self.decodingFailure(error) }
                if acknowledgement.code == 401 {
                    if let token { NotificationCenter.default.post(name: .sessionUnauthorized, object: token) }
                    throw APIError.unauthorized
                }
                guard endpoint.acceptedCodes.contains(acknowledgement.code) else { throw APIError.service(acknowledgement.code) }
                do { return try Self.decoder().decode(T.self, from: IdentityJSON.expand(data)) }
                catch { throw Self.decodingFailure(error) }
            } catch let error as URLError {
                if attempt + 1 < attempts, [.timedOut, .networkConnectionLost].contains(error.code) {
                    try await Task.sleep(for: .milliseconds(500)); continue
                }
                throw error
            }
        }
        throw APIError.malformed
    }
}

// Jackson's @JsonIdentityInfo serializes repeated entities as an integer @id
// reference. A comments page can contain the same release dozens of times.
// Expand only entity relationships; ordinary numeric IDs/counts stay numeric.
enum IdentityJSON {
    private static let relationships: Set<String> = ["release","profile","author","collection","article","channel","repost_article","last_view_episode","content","history","votes","friends_preview","comments_preview","collections_preview","release_videos_preview","related_releases","recommended_releases"]
    static func expand(_ data: Data) throws -> Data {
        guard data.range(of:Data("\"@id\"".utf8)) != nil else { return data }
        let root = try JSONSerialization.jsonObject(with:data)
        var identities: [Int: [String:Any]] = [:]
        func collect(_ value: Any, depth: Int) {
            guard depth < 40 else { return }
            if let object = value as? [String:Any] {
                if let id = object["@id"] as? Int { identities[id] = object }
                for child in object.values { collect(child,depth:depth + 1) }
            } else if let list = value as? [Any] { for child in list { collect(child,depth:depth + 1) } }
        }
        collect(root,depth:0)
        func compact(_ object: [String:Any]) -> [String:Any] {
            object.filter { !($0.value is [String:Any]) && !($0.value is [Any]) }
        }
        func resolve(_ value: Any, key: String?, seen: Set<Int>, depth: Int) -> Any {
            if let number = value as? Int, let key, relationships.contains(key), let target = identities[number] {
                if seen.contains(number) || depth >= 24 { return compact(target) }
                return resolve(target,key:nil,seen:seen,depth:depth + 1)
            }
            if let object = value as? [String:Any] {
                if depth >= 24 { return compact(object) }
                var visited = seen
                if let id = object["@id"] as? Int { visited.insert(id) }
                return object.reduce(into:[String:Any]()) { result, entry in
                    result[entry.key] = resolve(entry.value,key:entry.key,seen:visited,depth:depth + 1)
                }
            }
            if let list = value as? [Any] { return list.map { resolve($0,key:key,seen:seen,depth:depth + 1) } }
            return value
        }
        return try JSONSerialization.data(withJSONObject:resolve(root,key:nil,seen:[],depth:0))
    }
}

private final class SameOriginRedirects: NSObject, URLSessionTaskDelegate {
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
        // Never forward a query token or login body to a different origin.
        guard request.url?.scheme == "https", request.url?.host == task.originalRequest?.url?.host else {
            completionHandler(nil); return
        }
        completionHandler(request)
    }
}
