import XCTest
import UIKit
@testable import AnixartPort

@MainActor final class ImagePipelineTests: XCTestCase {
    private func fixture() -> Data {
        let format = UIGraphicsImageRendererFormat(); format.scale = 1; format.opaque = true
        return UIGraphicsImageRenderer(size:CGSize(width:800,height:1200),format:format).pngData { context in
            UIColor.red.setFill(); context.fill(CGRect(x:0,y:0,width:800,height:1200))
        }
    }
    func testDownsampledBitmapAndConcurrentLoadsShareOneRequest() async throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at:folder) }
        StubURLProtocol.storage.configure([.init(status:200,body:"",data:fixture())])
        let pipeline = ImagePipeline(session:StubURLProtocol.session(),directory:folder)
        let url = URL(string:"https://example.test/poster.jpg")!
        async let first = pipeline.image(url,pixels:156)
        async let second = pipeline.image(url,pixels:156)
        let values = try await [first,second]
        XCTAssertLessThanOrEqual(values[0].image.height,156)
        XCTAssertGreaterThan(values[0].image.height,100)
        XCTAssertEqual(StubURLProtocol.storage.captured().count,1)
        _ = try await pipeline.image(url,pixels:156)
        let metrics = await pipeline.snapshot()
        XCTAssertGreaterThan(metrics.memoryHits,0)
        XCTAssertEqual(StubURLProtocol.storage.captured().count,1)
    }
    func testDiskCacheSurvivesPipelineRecreationWithoutNetwork() async throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at:folder) }
        StubURLProtocol.storage.configure([.init(status:200,body:"",data:fixture())])
        let first = ImagePipeline(session:StubURLProtocol.session(),directory:folder)
        let url = URL(string:"https://example.test/poster.jpg")!
        _ = try await first.image(url,pixels:156)
        StubURLProtocol.storage.configure([])
        let second = ImagePipeline(session:StubURLProtocol.session(),directory:folder)
        let image = try await second.image(url,pixels:300)
        XCTAssertGreaterThan(image.image.height,156)
        XCTAssertTrue(StubURLProtocol.storage.captured().isEmpty)
        let metrics = await second.snapshot(); XCTAssertEqual(metrics.diskHits,1)
    }
    func testHTMLResponseNeverBecomesAPersistentPoster() async {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at:folder) }
        StubURLProtocol.storage.configure([.init(status:200,body:"<html>Unavailable</html>"),.init(status:200,body:"<html>Unavailable</html>")])
        let pipeline = ImagePipeline(session:StubURLProtocol.session(),directory:folder)
        for _ in 0..<2 {
            do { _ = try await pipeline.image(URL(string:"https://example.test/a.jpg")!,pixels:156); XCTFail("HTML must not be cached as an image") } catch { }
        }
        XCTAssertEqual(StubURLProtocol.storage.captured().count,2)
    }
}
