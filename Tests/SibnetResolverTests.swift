import XCTest
@testable import AnixartPort

@MainActor final class SibnetResolverTests: XCTestCase {
    func testPageRedirectsProduceTheFinalSignedMediaURL() async throws {
        StubURLProtocol.storage.configure([
            .init(status:200,body:#"player.src([{src: "/v/fixture.mp4",type:"video/mp4"}]);"#),
            .init(status:302,body:"",headers:["Location":"//provider-cdn.example.test:443/fixture.mp4?signature=test%2Bvalue"]),
            .init(status:206,body:"",headers:["Content-Type":"video/mp4"])
        ])
        let page = URL(string:"https://video.sibnet.ru/shell.php?videoid=123")!
        let media = try await SibnetResolver(userAgent:"Original-App-Configured-Agent/1",session:StubURLProtocol.session()).resolve(page)
        XCTAssertEqual(media.absoluteString,"https://provider-cdn.example.test/fixture.mp4?signature=test%2Bvalue")
        let requests = StubURLProtocol.storage.captured()
        XCTAssertTrue(requests.allSatisfy { $0.value(forHTTPHeaderField:"User-Agent") == "Original-App-Configured-Agent/1" })
        XCTAssertEqual(requests[1].value(forHTTPHeaderField:"Referer"),page.absoluteString)
        XCTAssertNil(requests[2].value(forHTTPHeaderField:"Referer"))
        XCTAssertEqual(requests[2].value(forHTTPHeaderField:"Range"),"bytes=0-1")
    }
    func testUnrelatedScriptsAndUnsafeMediaAreNotResolved() {
        let page = URL(string:"https://video.sibnet.ru/shell.php?videoid=123")!
        XCTAssertThrowsError(try SibnetResolver.mediaURL(in:#"src:"https://example.test/advert.mp4""#,page:page))
        XCTAssertThrowsError(try SibnetResolver.mediaURL(in:#"src:"javascript:alert(1)""#,page:page))
    }
}
