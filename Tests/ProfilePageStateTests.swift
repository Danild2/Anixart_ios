import XCTest
@testable import AnixartPort

@MainActor final class ProfilePageStateTests: XCTestCase {
    actor HeldResponse {
        private var response: CheckedContinuation<Page<Release>,Never>?
        private var observer: CheckedContinuation<Void,Never>?
        func wait() async -> Page<Release> {
            await withCheckedContinuation { response = $0; observer?.resume(); observer = nil }
        }
        func started() async {
            if response != nil { return }
            await withCheckedContinuation { observer = $0 }
        }
        func finish(_ value: Page<Release>) { response?.resume(returning:value); response = nil }
    }
    func testLatePreviousAccountResponseCannotReplaceNewAccountOrLoadingState() async {
        let model = ProfilePageState<Release>(), held = HeldResponse()
        let old = Task { await model.load(reset:true) { _ in await held.wait() } }
        await held.started()
        await model.load(reset:true) { _ in Page(code:0,content:[Release(id:200)]) }
        XCTAssertEqual(model.items.map(\.id),[200]); XCTAssertFalse(model.loading)
        await held.finish(Page(code:0,content:[Release(id:100)])); await old.value
        XCTAssertEqual(model.items.map(\.id),[200]); XCTAssertFalse(model.loading); XCTAssertNil(model.error)
    }
    func testPaginationDeduplicatesBothWithinAndAcrossPages() async {
        let model = ProfilePageState<Release>()
        await model.load(reset:true) { _ in Page(code:0,content:[Release(id:7),Release(id:7)]) }
        await model.load(reset:false) { page in
            XCTAssertEqual(page,1)
            return Page(code:0,content:[Release(id:7),Release(id:9)])
        }
        XCTAssertEqual(model.items.map(\.id),[7,9])
    }
}
