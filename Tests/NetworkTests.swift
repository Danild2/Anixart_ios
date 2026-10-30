import XCTest
@testable import AnixartPort

@MainActor final class NetworkTests: XCTestCase {
    func testForbiddenHTMLIsReportedWithoutParsingOrRetrying() async {
        StubURLProtocol.storage.configure([.init(status: 403, body: "<html>Forbidden</html>")])
        let client = APIClient(session: StubURLProtocol.session())
        do { let _: Acknowledgement = try await client.request(Endpoint(path: "filter/0", method: "POST")); XCTFail("Expected HTTP failure") }
        catch { XCTAssertEqual(error as? APIError, .http(403)) }
        XCTAssertEqual(StubURLProtocol.storage.captured().count, 1)
    }
    func testApplicationErrorDoesNotRequireSuccessPayload() async {
        StubURLProtocol.storage.configure([.init(status: 200, body: #"{"code":2}"#)])
        let client = APIClient(session: StubURLProtocol.session())
        do { let _: ReleaseResponse = try await client.request(Endpoint(path: "release/1")); XCTFail("Expected service failure") }
        catch { XCTAssertEqual(error as? APIError, .service(2)) }
    }
    func testMalformedSuccessIsRejected() async {
        StubURLProtocol.storage.configure([.init(status: 200, body: #"{"code":0,"release":"invalid"}"#)])
        let client = APIClient(session: StubURLProtocol.session())
        do { let _: ReleaseResponse = try await client.request(Endpoint(path: "release/1")); XCTFail("Expected schema failure") }
        catch { XCTAssertEqual(error as? APIError, .malformed) }
    }
    func testReadRetriesOnceAfter503() async throws {
        StubURLProtocol.storage.configure([.init(status: 503, body: ""), .init(status: 200, body: #"{"code":0}"#)])
        let client = APIClient(session: StubURLProtocol.session())
        let _: Acknowledgement = try await client.request(Endpoint(path: "release/1"))
        XCTAssertEqual(StubURLProtocol.storage.captured().count, 2)
    }
    func testGetMutationNeverRetries() async {
        StubURLProtocol.storage.configure([.init(status: 503, body: ""), .init(status: 200, body: #"{"code":0}"#)])
        let client = APIClient(session: StubURLProtocol.session())
        do { let _: Acknowledgement = try await client.request(Endpoint(path: "favorite/add/1", isReadOnly: false), token: "test-token"); XCTFail("Expected failure") }
        catch { XCTAssertEqual(error as? APIError, .http(503)) }
        XCTAssertEqual(StubURLProtocol.storage.captured().count, 1)
    }
    func testSearchUsesAPKVersionAndBody() async throws {
        StubURLProtocol.storage.configure([.init(status: 200, body: #"{"code":0,"releases":[{"id":1,"title_ru":"Тест"}]}"#)])
        let repository = AnixartRepository(client: APIClient(session: StubURLProtocol.session()))
        let releases = try await repository.search("Тест", page: 0, token: nil)
        XCTAssertEqual(releases.first?.title, "Тест")
        let request = try XCTUnwrap(StubURLProtocol.storage.captured().first)
        XCTAssertEqual(request.value(forHTTPHeaderField: "API-Version"), "v2")
        XCTAssertEqual(request.url?.path, "/search/releases/0")
        let body = try JSONSerialization.jsonObject(with: XCTUnwrap(request.httpBody)) as? [String: Any]
        XCTAssertEqual(body?["query"] as? String, "Тест")
        XCTAssertEqual(body?["searchBy"] as? Int, 0)
    }
    func testCanceledRequestIsNotStarted() async {
        StubURLProtocol.storage.configure([])
        let client = APIClient(session: StubURLProtocol.session())
        let task = Task { () throws -> Acknowledgement in
            try await Task.sleep(for: .seconds(1))
            return try await client.request(Endpoint(path: "release/1"))
        }
        task.cancel()
        do { _ = try await task.value; XCTFail("Expected cancellation") } catch { }
        XCTAssertEqual(StubURLProtocol.storage.captured().count, 0)
    }
    func testLoginFormPreservesPlusAmpersandUnicode() throws {
        let data = APIClient.form(["login":"тест+user@example.com", "password":"p&+= x"])
        let string = try XCTUnwrap(String(data: data, encoding: .utf8))
        let components = try XCTUnwrap(URLComponents(string: "https://example.test/?" + string))
        XCTAssertEqual(components.queryItems?.first(where: { $0.name == "password" })?.value, "p&+= x")
        XCTAssertTrue(string.contains("%2B"))
    }
}
