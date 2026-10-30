import Foundation

final class StubURLProtocol: URLProtocol, @unchecked Sendable {
    struct Reply { let status: Int; let body: String }
    final class Storage: @unchecked Sendable {
        private let lock = NSLock()
        private var replies: [Reply] = []
        private var requests: [URLRequest] = []
        func configure(_ replies: [Reply]) { lock.lock(); defer { lock.unlock() }; self.replies = replies; requests = [] }
        func next(_ request: URLRequest) -> Reply {
            lock.lock(); defer { lock.unlock() }; requests.append(request)
            return replies.isEmpty ? Reply(status: 500, body: "") : replies.removeFirst()
        }
        func captured() -> [URLRequest] { lock.lock(); defer { lock.unlock() }; return requests }
    }
    static let storage = Storage()
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        var captured = request
        if captured.httpBody == nil, let stream = captured.httpBodyStream {
            stream.open()
            defer { stream.close() }
            var body = Data()
            var buffer = [UInt8](repeating: 0, count: 4096)
            while stream.hasBytesAvailable {
                let count = stream.read(&buffer, maxLength: buffer.count)
                guard count > 0 else { break }
                body.append(contentsOf: buffer.prefix(count))
            }
            captured.httpBody = body
        }
        let reply = Self.storage.next(captured)
        let response = HTTPURLResponse(url: request.url!, statusCode: reply.status, httpVersion: nil, headerFields: ["Content-Type":"application/json"])!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(reply.body.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
    static func session() -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StubURLProtocol.self]
        return URLSession(configuration: config)
    }
}
