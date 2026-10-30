import XCTest
@testable import AnixartPort

@MainActor final class SessionTests: XCTestCase {
    final class MemoryVault: SessionVault {
        var data: Data?
        func read() throws -> Data? { data }
        func write(_ data: Data) throws { self.data = data }
        func delete() throws { data = nil }
    }
    func testLoginRestoreAndLogout() async throws {
        StubURLProtocol.storage.configure([.init(status: 200, body: #"{"code":0,"profile":{"id":7,"login":"Fixture"},"profileToken":{"token":"test-only-token"}}"#)])
        let vault = MemoryVault()
        let store = SessionStore(vault: vault)
        await store.signIn(login: "fixture", password: "test-only-password", repository: AnixartRepository(client: APIClient(session: StubURLProtocol.session())))
        XCTAssertEqual(store.token, "test-only-token")
        let restored = SessionStore(vault: vault)
        XCTAssertEqual(restored.session?.profile.id, 7)
        let encoded = try XCTUnwrap(vault.data)
        XCTAssertFalse(String(decoding: encoded, as: UTF8.self).contains("test-only-password"))
        restored.signOut()
        XCTAssertNil(vault.data); XCTAssertNil(restored.token)
    }
    func testFailedLoginDoesNotCreateSession() async {
        StubURLProtocol.storage.configure([.init(status: 200, body: #"{"code":2}"#)])
        let vault = MemoryVault()
        let store = SessionStore(vault: vault)
        await store.signIn(login: "fixture", password: "invalid", repository: AnixartRepository(client: APIClient(session: StubURLProtocol.session())))
        XCTAssertNil(store.token); XCTAssertNotNil(store.error); XCTAssertNil(vault.data)
    }
    func testExpiredRequestCannotLogOutTheNewSession() throws {
        let vault = MemoryVault(); let store = SessionStore(vault: vault)
        let old = try APIClient.decoder().decode(LoginResponse.self, from: Data(#"{"code":0,"profile":{"id":1},"profileToken":{"token":"old-test-token"}}"#.utf8))
        let next = try APIClient.decoder().decode(LoginResponse.self, from: Data(#"{"code":0,"profile":{"id":2},"profileToken":{"token":"new-test-token"}}"#.utf8))
        try store.accept(old); try store.accept(next)
        store.invalidate(ifMatching: "old-test-token")
        XCTAssertEqual(store.session?.profile.id, 2); XCTAssertNotNil(vault.data)
        store.invalidate(ifMatching: "new-test-token")
        XCTAssertNil(store.session); XCTAssertNil(vault.data)
    }
}
