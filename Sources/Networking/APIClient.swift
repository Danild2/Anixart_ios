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
}

extension Notification.Name {
    static let sessionUnauthorized = Notification.Name("Anixart.SessionUnauthorized")
}

actor APIClient {
    static let primaryURL = URL(string: "https://api-s.anixsekai.com/")!
    static let regionalURL = URL(string: "https://api.anixsekai.com/")!
    private let session: URLSession
    private let baseURL: URL

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
        let attempts = endpoint.isReadOnly ? 2 : 1
        for attempt in 0..<attempts {
            try Task.checkCancellation()
            do {
                let (data, response) = try await session.data(for: request)
                guard let http = response as? HTTPURLResponse else { throw APIError.malformed }
                if http.statusCode == 401 {
                    if token != nil { NotificationCenter.default.post(name: .sessionUnauthorized, object: nil) }
                    throw APIError.unauthorized
                }
                if [502, 503, 504].contains(http.statusCode), attempt + 1 < attempts {
                    try await Task.sleep(for: .milliseconds(500)); continue
                }
                guard (200..<300).contains(http.statusCode) else { throw APIError.http(http.statusCode) }
                // Inspect code before decoding success-only fields of an error envelope.
                let acknowledgement: Acknowledgement
                do { acknowledgement = try Self.decoder().decode(Acknowledgement.self, from: data) }
                catch { throw Self.decodingFailure(error) }
                guard acknowledgement.code == 0 else { throw APIError.service(acknowledgement.code) }
                do { return try Self.decoder().decode(T.self, from: data) }
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
