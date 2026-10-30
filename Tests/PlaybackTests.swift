import XCTest
@testable import AnixartPort

@MainActor final class PlaybackTests: XCTestCase {
    func testLiveEpisodeShapeDoesNotRequireLocalDatabaseID() throws {
        let data = Data(#"{"code":0,"episodes":[{"position":1,"name":"Серия 1","iframe":true,"url":"https://example.test/embed/1","is_watched":false}]}"#.utf8)
        let response = try APIClient.decoder().decode(EpisodesResponse.self, from: data)
        XCTAssertEqual(response.episodes.first?.id, 1)
        XCTAssertNil(response.episodes.first?.serverID)
        XCTAssertEqual(response.episodes.first?.isWatched, false)
    }
    func testNativeAndEmbeddedSelection() throws {
        let native = Episode(id: 1, position: 1, url: "https://example.test/video.m3u8?quality=720", iframe: false)
        let embedded = Episode(id: 2, position: 2, url: "https://example.test/embed/2", iframe: true)
        XCTAssertEqual(try SourceResolver().resolve(native), .native(URL(string: native.url!)!))
        XCTAssertEqual(try SourceResolver().resolve(embedded), .embedded(URL(string: embedded.url!)!))
    }
    func testUnknownProviderAndUnsafeSchemeAreRejected() {
        XCTAssertThrowsError(try SourceResolver().resolve(Episode(id: 1, position: 1, url: "https://example.test/watch/1", iframe: false)))
        XCTAssertThrowsError(try SourceResolver().resolve(Episode(id: 1, position: 1, url: "javascript:alert(1)", iframe: true)))
        XCTAssertThrowsError(try SourceResolver().resolve(Episode(id: 1, position: 1, url: "https://user:password@example.test/video.mp4")))
    }
    func testEpisodeAndSourceProgressAreIsolatedAndPersisted() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let key = PlaybackKey(account: "1", releaseID: 10, typeID: 2, sourceID: 3, position: 1)
        let source2 = PlaybackKey(account: "1", releaseID: 10, typeID: 2, sourceID: 4, position: 1)
        let episode2 = PlaybackKey(account: "1", releaseID: 10, typeID: 2, sourceID: 3, position: 2)
        let account2 = PlaybackKey(account: "2", releaseID: 10, typeID: 2, sourceID: 3, position: 1)
        let store = ProgressStore(directory: directory)
        try store.save(key: key, seconds: 90, duration: 1440)
        let restored = ProgressStore(directory: directory)
        XCTAssertEqual(restored.progress(for: key)?.resumeSeconds, 90)
        XCTAssertNil(restored.progress(for: source2)); XCTAssertNil(restored.progress(for: episode2)); XCTAssertNil(restored.progress(for: account2))
    }
    func testFinishedEpisodeRestartsAndInvalidProgressIsIgnored() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let key = PlaybackKey(account: "guest", releaseID: 1, typeID: 1, sourceID: 1, position: 1)
        let store = ProgressStore(directory: directory)
        try store.save(key: key, seconds: .nan, duration: .infinity)
        XCTAssertNil(store.progress(for: key))
        try store.save(key: key, seconds: 99, duration: 100)
        XCTAssertEqual(store.progress(for: key)?.resumeSeconds, 0)
    }
}
