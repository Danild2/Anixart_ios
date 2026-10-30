import XCTest
@testable import AnixartPort

@MainActor final class PublicConfigurationTests: XCTestCase {
    func testOfficialConfigurationMayOmitCodeAndIsCached() async throws {
        StubURLProtocol.storage.configure([.init(status:200,body:#"{"sibnetRandUserAgent":true,"sibnetUserAgent":"Original-App-Configured-Agent/1","kodikIframeAd":true,"consentRequired":false}"#)])
        let client = APIClient(session:StubURLProtocol.session())
        let config = try await client.publicConfiguration()
        XCTAssertEqual(config.code,0); XCTAssertEqual(config.sibnetRandUserAgent,true)
        XCTAssertEqual(config.sibnetUserAgent,"Original-App-Configured-Agent/1")
        XCTAssertEqual(config.kodikIframeAd,true); XCTAssertEqual(config.consentRequired,false)
        _ = try await client.publicConfiguration()
        let requests = StubURLProtocol.storage.captured()
        XCTAssertEqual(requests.count,1)
        let query = URLComponents(url:requests[0].url!,resolvingAgainstBaseURL:false)?.queryItems
        XCTAssertEqual(query?.first(where:{$0.name == "version_code"})?.value,"26101718")
        XCTAssertNil(query?.first(where:{$0.name == "token"}))
    }
    func testOmittedCodeIsStillRejectedForAuthentication() async {
        StubURLProtocol.storage.configure([.init(status:200,body:#"{"profile":{"id":7},"profile_token":{"token":"fixture"}}"#)])
        do {
            let _: LoginResponse = try await APIClient(session:StubURLProtocol.session()).request(Endpoint(path:"auth/signIn",method:"POST",isReadOnly:false))
            XCTFail("Only the confirmed public configuration route may omit its status code")
        } catch { XCTAssertEqual(error as? APIError,.schema("code")) }
    }
    func testConfigurationServiceErrorDoesNotBecomeACachedSuccess() async throws {
        StubURLProtocol.storage.configure([.init(status:200,body:#"{"code":401}"#),.init(status:200,body:#"{"kodikIframeAd":true}"#)])
        let client = APIClient(session:StubURLProtocol.session())
        do { _ = try await client.publicConfiguration(); XCTFail("Service failure must be respected") }
        catch { XCTAssertEqual(error as? APIError,.unauthorized) }
        let next = try await client.publicConfiguration(); XCTAssertEqual(next.kodikIframeAd,true)
        XCTAssertEqual(StubURLProtocol.storage.captured().count,2)
    }
}
