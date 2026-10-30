import XCTest
@testable import AnixartPort

final class HLSQualitiesTests: XCTestCase {
    func testActualManifestAttributesAndRelativeURLs() throws {
        let data = Data("""
        #EXTM3U
        #EXT-X-STREAM-INF:BANDWIDTH=1800000,RESOLUTION=1280x720,CODECS="avc1.4d401f,mp4a.40.2"
        720/index.m3u8
        #EXT-X-STREAM-INF:BANDWIDTH=4500000,RESOLUTION=1920x1080
        /1080/index.m3u8
        """.utf8)
        let variants = try HLSQualities.parse(data, baseURL: URL(string: "https://example.test/anime/master.m3u8")!)
        XCTAssertEqual(variants.map(\.height), [1080, 720])
        XCTAssertEqual(variants.last?.url.absoluteString, "https://example.test/anime/720/index.m3u8")
        XCTAssertEqual(variants.first?.bandwidth, 4_500_000)
    }
    func testMediaPlaylistDoesNotInventQualities() throws {
        let data = Data("#EXTM3U\n#EXTINF:6,\nsegment.ts\n".utf8)
        XCTAssertTrue(try HLSQualities.parse(data, baseURL: URL(string: "https://example.test/index.m3u8")!).isEmpty)
    }
    func testHTMLAndUnsafeVariantAreRejected() throws {
        let url = URL(string: "https://example.test/master.m3u8")!
        XCTAssertThrowsError(try HLSQualities.parse(Data("<html>Forbidden</html>".utf8), baseURL: url))
        XCTAssertTrue(try HLSQualities.parse(Data("#EXTM3U\n#EXT-X-STREAM-INF:BANDWIDTH=1\nfile:///private/video\n".utf8), baseURL: url).isEmpty)
    }
}
