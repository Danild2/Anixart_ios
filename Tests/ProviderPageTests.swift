import XCTest
@testable import AnixartPort

final class ProviderPageTests: XCTestCase {
    func testKodikUsesOriginalAdPageBeforeCanonicalPlayer() throws {
        let source = URL(string:"https://kodikplayer.com/seria/123/example/720p?d=example.test&s=fixture")!
        let initial = try XCTUnwrap(ProviderPage.initial(source))
        let components = try XCTUnwrap(URLComponents(url:initial,resolvingAgainstBaseURL:false))
        XCTAssertEqual(components.path,"/iframe/ad")
        XCTAssertEqual(components.queryItems?.first(where:{$0.name == "url"})?.value,"https://kodikplayer.com/seria/123/example/720p")
        XCTAssertEqual(components.queryItems?.first(where:{$0.name == "v"})?.value,"26101718")
        XCTAssertTrue(ProviderPage.permitsAdCallback(origin:"anixmirai.com",expected:source))
        XCTAssertFalse(ProviderPage.permitsAdCallback(origin:"example.test",expected:source))
        XCTAssertFalse(ProviderPage.permitsAdCallback(origin:"kodikplayer.com.evil.test",expected:source))
    }
    func testOtherProvidersKeepTheirQueryAndCannotCompleteKodikAds() throws {
        let source = URL(string:"https://example.test/embed?id=123&signed=a%2Bb")!
        let initial = try XCTUnwrap(ProviderPage.initial(source))
        let components = try XCTUnwrap(URLComponents(url:initial,resolvingAgainstBaseURL:false))
        XCTAssertEqual(components.path,"/iframe")
        XCTAssertEqual(components.queryItems?.first?.value,source.absoluteString)
        XCTAssertFalse(ProviderPage.permitsAdCallback(origin:"anixmirai.com",expected:source))
        XCTAssertNil(ProviderPage.initial(URL(string:"https://user:password@example.test/")!))
    }
    func testOnlyTheOriginalFtor500FailureCanAdvanceTheAdFlow() {
        XCTAssertTrue(ProviderPage.isOriginalAdServerFailure(URL(string:"https://kodikplayer.com/ftor"),status:500))
        XCTAssertFalse(ProviderPage.isOriginalAdServerFailure(URL(string:"https://kodikplayer.com/ftor"),status:403))
        XCTAssertFalse(ProviderPage.isOriginalAdServerFailure(URL(string:"https://kodikplayer.com/seria/123/example/720p"),status:500))
        XCTAssertFalse(ProviderPage.isOriginalAdServerFailure(URL(string:"https://example.test/ftor"),status:500))
    }
    func testOnlyExplicitPublicConfigurationCanDisableTheAdStage() throws {
        let source = URL(string:"https://kodikplayer.com/seria/123/example/720p?d=example.test&s=fixture")!
        let disabled = try APIClient.decoder().decode(PublicConfiguration.self,from:Data(#"{"kodikIframeAd":false}"#.utf8))
        XCTAssertFalse(ProviderPage.requiresAdvertisement(source,configuration:disabled))
        XCTAssertEqual(ProviderPage.initial(source,configuration:disabled)?.absoluteString,"https://kodikplayer.com/seria/123/example/720p")
        XCTAssertTrue(ProviderPage.requiresAdvertisement(source,configuration:nil))
        let enabled = try APIClient.decoder().decode(PublicConfiguration.self,from:Data(#"{"kodikIframeAd":true}"#.utf8))
        XCTAssertTrue(ProviderPage.requiresAdvertisement(source,configuration:enabled))
    }
}
