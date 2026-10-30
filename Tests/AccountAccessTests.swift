import XCTest
@testable import AnixartPort

@MainActor final class AccountAccessTests: XCTestCase {
    private func repository(_ replies: [StubURLProtocol.Reply]) -> AnixartRepository {
        StubURLProtocol.storage.configure(replies)
        return AnixartRepository(client: APIClient(session: StubURLProtocol.session()))
    }
    private func flow(_ mode: AccountAccessMode) -> AccountAccess {
        let flow = AccountAccess(mode: mode)
        flow.login = "fixture"; flow.email = "fixture@example.test"; flow.password = "test-only-password"
        flow.repeatedPassword = flow.password; flow.termsAccepted = true; flow.disseminationAccepted = true
        return flow
    }
    func testAlreadySentChallengeAdvancesWithoutCreatingASessionOrSendingAgain() async {
        let repo = repository([.init(status: 200, body: #"{"code":7,"hash":"test-hash","code_length":5,"code_time_left":60}"#)])
        let flow = flow(.registration)
        await flow.start(repository: repo)
        XCTAssertEqual(flow.challenge?.inputLength, 5); XCTAssertNil(flow.error)
        await flow.resend(repository: repo)
        XCTAssertEqual(StubURLProtocol.storage.captured().count, 1)
        XCTAssertEqual(StubURLProtocol.storage.captured().first?.value(forHTTPHeaderField: "X-Long-Code"), "1")
        flow.code = "1234"; XCTAssertFalse(flow.canVerify)
        flow.code = "12345"; XCTAssertTrue(flow.canVerify)
        flow.clearSecrets(); XCTAssertTrue(flow.password.isEmpty); XCTAssertNil(flow.challenge)
    }
    func testRestoreWrongCodeDoesNotCreateSessionThenSuccessfulCodeClearsSecrets() async throws {
        let repo = repository([
            .init(status: 200, body: #"{"code":3,"hash":"test-hash","code_length":4}"#),
            .init(status: 200, body: #"{"code":4}"#),
            .init(status: 200, body: #"{"code":0,"profile":{"id":7,"login":"Fixture"},"profileToken":{"token":"test-token"}}"#)
        ])
        let flow = flow(.restore)
        let vault = SessionTests.MemoryVault(); let session = SessionStore(vault: vault)
        await flow.start(repository: repo); flow.code = "1234"
        let wrong = await flow.verify(repository: repo, session: session)
        XCTAssertFalse(wrong); XCTAssertNil(session.token); XCTAssertNil(vault.data); XCTAssertNotNil(flow.error)
        let accepted = await flow.verify(repository: repo, session: session)
        XCTAssertTrue(accepted); XCTAssertEqual(session.token, "test-token")
        XCTAssertTrue(flow.password.isEmpty); XCTAssertTrue(flow.code.isEmpty); XCTAssertNil(flow.challenge)
        let encoded = String(decoding: try XCTUnwrap(vault.data), as: UTF8.self)
        XCTAssertFalse(encoded.contains("test-only-password")); XCTAssertFalse(encoded.contains("test-hash"))
    }
    func testTakenLoginOffersServerSuggestionsWithoutEnteringCodeStage() async {
        let repo = repository([.init(status: 200, body: #"{"code":5,"suggested_logins":["fixture2","fixture3"]}"#)])
        let flow = flow(.registration)
        await flow.start(repository: repo)
        XCTAssertNil(flow.challenge); XCTAssertNotNil(flow.error); XCTAssertEqual(flow.suggestions, ["fixture2", "fixture3"])
    }
    func testUnknownCodeLengthFallsBackToTheOriginalFourDigits() throws {
        let response = try APIClient.decoder().decode(AuthChallengeResponse.self, from: Data(#"{"code":0,"code_length":99}"#.utf8))
        XCTAssertEqual(response.inputLength, 4)
    }
    func testSendingEmailIsNeverAutomaticallyRetriedAfterServerFailure() async {
        let repo = repository([.init(status: 503, body: ""), .init(status: 200, body: #"{"code":0,"hash":"test-hash"}"#)])
        let flow = flow(.restore)
        await flow.start(repository: repo)
        XCTAssertNil(flow.challenge); XCTAssertNotNil(flow.error)
        XCTAssertEqual(StubURLProtocol.storage.captured().count, 1)
    }
}
