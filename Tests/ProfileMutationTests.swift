import XCTest
@testable import AnixartPort

@MainActor final class ProfileMutationTests: XCTestCase {
    private func repository(_ replies: [StubURLProtocol.Reply]) -> AnixartRepository {
        StubURLProtocol.storage.configure(replies)
        return AnixartRepository(client:APIClient(session:StubURLProtocol.session()))
    }
    func testAvatarUploadPreservesOriginalMultipartNamesAndBinaryData() async throws {
        let repo = repository([.init(status:200,body:#"{"code":0}"#)])
        let jpeg = Data([0xff,0xd8,0x00,0x0d,0x0a,0xff,0xd9])
        try await repo.editProfileAvatar(jpeg,token:"test-token")
        let request = try XCTUnwrap(StubURLProtocol.storage.captured().first)
        XCTAssertEqual(request.url?.path,"/profile/preference/avatar/edit")
        XCTAssertEqual(request.httpMethod,"POST")
        let data = try XCTUnwrap(request.httpBody)
        XCTAssertNotNil(data.range(of:jpeg))
        let text = String(decoding:data,as:UTF8.self)
        XCTAssertTrue(text.contains("name=\"name\"")); XCTAssertTrue(text.contains("name=\"image\"; filename=\"avatar.jpg\""))
        XCTAssertTrue(request.value(forHTTPHeaderField:"Content-Type")?.hasPrefix("multipart/form-data; boundary=Anixart-") == true)
    }
    func testPrivacyMutationsNeverRetryAndInvalidFieldsAreRejected() async {
        let repo = repository([.init(status:503,body:""),.init(status:200,body:#"{"code":0}"#)])
        do { try await repo.editProfilePrivacy("stats",permission:2,token:"test-token"); XCTFail("Expected service failure") }
        catch { XCTAssertEqual(error as? APIError,.http(503)) }
        XCTAssertEqual(StubURLProtocol.storage.captured().count,1)
        do { try await repo.editProfilePrivacy("other",permission:2,token:"test-token"); XCTFail("Invalid privacy field") }
        catch { XCTAssertEqual(error as? APIError,.invalidURL) }
        XCTAssertEqual(StubURLProtocol.storage.captured().count,1)
    }
    func testSocialEditUsesOriginalCamelCaseBodyAndUnicode() async throws {
        let repo = repository([.init(status:200,body:#"{"code":0}"#)])
        let social = ProfileSocialEdit(vkPage:"https://vk.com/имя",tgPage:"example",instPage:"",ttPage:"",discordPage:"")
        try await repo.editProfileSocial(social,token:"test-token")
        let data = try XCTUnwrap(StubURLProtocol.storage.captured().first?.httpBody)
        let body = try JSONSerialization.jsonObject(with:data) as? [String:String]
        XCTAssertEqual(body?["vkPage"],social.vkPage); XCTAssertEqual(body?["tgPage"],"example")
        XCTAssertNil(body?["vk_page"])
    }
}
