import XCTest
@testable import AnixartPort

@MainActor final class EmbeddedVLCCompatibilityTests: XCTestCase {
    private let key = PlaybackKey(account:"guest",releaseID:841,typeID:1,sourceID:8,position:1)
    func testUnsupportedWebKitCodecCanStillProvideAnExternalVLCURLWithoutFakePlayback() {
        let state = EmbeddedPlayback(key:key,prefersExternalMedia:true)
        state.receive(["event":"error","code":4,"media":"https://example.test/series/1.mp4?signature=a%2Bb"])
        XCTAssertEqual(state.mediaURL?.absoluteString,"https://example.test/series/1.mp4?signature=a%2Bb")
        XCTAssertNil(state.error); XCTAssertEqual(state.phase,.ready)
        XCTAssertFalse(state.renderedVideo); XCTAssertFalse(state.canControl); XCTAssertNil(state.duration)
    }
    func testInAppModeStillReportsUnsupportedVideoAndNeverInventsExternalPlayback() {
        let state = EmbeddedPlayback(key:key)
        state.receive(["event":"error","code":4,"media":"https://example.test/series/1.mp4"])
        XCTAssertNotNil(state.error); XCTAssertEqual(state.phase,.failed); XCTAssertNil(state.mediaURL)
    }
    func testHTMLAndBlobURLsCannotTurnAnErrorIntoAVLCStream() {
        for raw in ["https://example.test/error.html","blob:https://example.test/fixture","file:///tmp/series.mp4"] {
            let state = EmbeddedPlayback(key:key,prefersExternalMedia:true)
            state.receive(["event":"error","code":4,"media":raw])
            XCTAssertNotNil(state.error); XCTAssertNil(state.mediaURL)
        }
    }
}
