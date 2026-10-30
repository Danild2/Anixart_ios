import XCTest
@testable import AnixartPort

final class AniLibriaResolverTests: XCTestCase {
    func testOnlyTheRequestedEpisodeIsSelectedAndQualityURLsPreserved() throws {
        let data = Data(#"{"episodes":[{"ordinal":1,"hls_1080":"https://example.test/one.m3u8"},{"ordinal":2,"hls_1080":"https://example.test/two.m3u8?signature=a%2Bb&expires=1","hls_480":"https://example.test/two-480.m3u8"}]}"#.utf8)
        let variants = try AniLibriaResolver.parse(data, ordinal: 2)
        XCTAssertEqual(variants.map(\.height), [1080, 480])
        XCTAssertEqual(variants.first?.url.absoluteString, "https://example.test/two.m3u8?signature=a%2Bb&expires=1")
        XCTAssertThrowsError(try AniLibriaResolver.parse(data, ordinal: 3))
    }
    func testReferencesMustUseAPKProviderHostsAndUniquePositiveIDs() throws {
        XCTAssertEqual(try AniLibriaResolver.reference(URL(string: "https://anixart.libria.fun/player.php?id=100&ep=2")!), .init(release: 100, ordinal: 2))
        for value in ["https://example.test/?id=100&ep=2", "https://anixart.libria.fun/?id=100&ep=-1", "https://anixart.libria.fun/?id=100&id=200&ep=2"] {
            XCTAssertThrowsError(try AniLibriaResolver.reference(URL(string: value)!))
        }
    }
}
