import XCTest
@testable import AnixartPort

@MainActor final class ExternalPlaybackTests: XCTestCase {
    private let key = PlaybackKey(account: "guest", releaseID: 1, typeID: 2, sourceID: 3, position: 4)
    func testMissingVLCDoesNotStartAnExternalRequest() async {
        let opener = TestOpener(); opener.installed = false
        let playback = ExternalPlayback(opener: opener)
        let opened = await playback.open(media: URL(string: "https://example.test/video.m3u8")!, key: key, title: "Серия 4")
        XCTAssertFalse(opened); XCTAssertTrue(opener.urls.isEmpty); XCTAssertNil(playback.active); XCTAssertNotNil(playback.error)
    }
    func testRejectedOpenDoesNotBecomeSuccessfulHandoff() async {
        let opener = TestOpener(); opener.accepted = false
        let playback = ExternalPlayback(opener: opener)
        let opened = await playback.open(media: URL(string: "https://example.test/video.m3u8")!, key: key, title: "Серия 4")
        XCTAssertFalse(opened); XCTAssertNil(playback.active); XCTAssertNil(playback.message); XCTAssertNotNil(playback.error)
    }
    func testCallbackMustMatchActiveRequestAndCanOnlyBeConsumedOnce() async throws {
        let opener = TestOpener()
        let playback = ExternalPlayback(opener: opener)
        let opened = await playback.open(media: URL(string: "https://example.test/video.m3u8?signature=a%2Bb&expires=1")!, key: key, title: "Серия 4")
        XCTAssertTrue(opened); XCTAssertEqual(playback.active?.key, key)
        let url = try XCTUnwrap(opener.urls.first)
        let query = try XCTUnwrap(URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems)
        let callback = try XCTUnwrap(query.first { $0.name == "x-success" }?.value.flatMap(URL.init(string:)))
        XCTAssertFalse(playback.handleCallback(URL(string: "anixartport://vlc-return?request=wrong&outcome=success")!))
        XCTAssertNotNil(playback.active)
        XCTAssertTrue(playback.handleCallback(callback)); XCTAssertNil(playback.active); XCTAssertNil(playback.error)
        XCTAssertFalse(playback.handleCallback(callback))
    }
    private final class TestOpener: ExternalURLOpener {
        var installed = true
        var accepted = true
        var urls: [URL] = []
        func canOpen(_ url: URL) -> Bool { installed }
        func open(_ url: URL) async -> Bool { urls.append(url); return accepted }
    }
}
