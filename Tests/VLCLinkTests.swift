import XCTest
@testable import AnixartPort

final class VLCLinkTests: XCTestCase {
    func testSignedMediaQueryAndRussianTitleArePreserved() throws {
        let media = URL(string: "https://example.test/video/master.m3u8?signature=a+b%2Fc%3D&expires=123")!
        let request = UUID()
        let link = try VLCLink.stream(media: media, title: "Название — серия 2", requestID: request)
        let query = try XCTUnwrap(URLComponents(url: link, resolvingAgainstBaseURL: false)?.queryItems)
        XCTAssertEqual(query.first(where: { $0.name == "url" })?.value, media.absoluteString)
        XCTAssertEqual(query.first(where: { $0.name == "filename" })?.value, "Название — серия 2")
        XCTAssertEqual(link.scheme, "vlc-x-callback")
        XCTAssertEqual(link.host, "x-callback-url")
        XCTAssertEqual(link.path, "/stream")
        XCTAssertTrue(try XCTUnwrap(URLComponents(url: link, resolvingAgainstBaseURL: false)?.percentEncodedQuery).contains("url=https%3A%2F%2F"))
        let callback = try XCTUnwrap(query.first(where: { $0.name == "x-success" })?.value)
        XCTAssertTrue(callback.contains(request.uuidString))
        XCTAssertFalse(query.contains { ["position", "start-time", "options"].contains($0.name) })
    }
    func testCredentialsAndLocalFilesAreNotHandedToAnotherApp() {
        XCTAssertThrowsError(try VLCLink.stream(media: URL(string: "file:///private/data")!, title: "", requestID: UUID()))
        XCTAssertThrowsError(try VLCLink.stream(media: URL(string: "https://user:password@example.test/a.mp4")!, title: "", requestID: UUID()))
    }
}

