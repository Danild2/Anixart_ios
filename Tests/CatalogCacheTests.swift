import XCTest
@testable import AnixartPort

@MainActor final class CatalogCacheTests: XCTestCase {
    private func release(_ id: Int64) throws -> Release {
        try JSONDecoder().decode(Release.self, from: Data("{\"id\":\(id)}".utf8))
    }
    func testHomeSectionsKeepTheirOwnOfflineCatalogs() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let cache = CatalogCache(directory: directory)
        let japan = CatalogFilter(country: "Япония"), china = CatalogFilter(country: "Китай")
        await cache.write([try release(1)], filter: japan)
        await cache.write([try release(2)], filter: china)
        let savedJapan = await cache.read(filter: japan), savedChina = await cache.read(filter: china)
        XCTAssertEqual(savedJapan?.releases.first?.id, 1); XCTAssertEqual(savedChina?.releases.first?.id, 2)
        let wrong = await cache.read(filter: CatalogFilter(statusId: 3))
        XCTAssertNil(wrong)
    }
    func testLegacyUnfilteredCacheCannotBecomeAFilteredSection() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let snapshot = CatalogCache.Snapshot(savedAt: Date(), releases: [try release(1)], filter: nil)
        try JSONEncoder().encode(snapshot).write(to: directory.appendingPathComponent("public-catalog-v1.json"))
        let cache = CatalogCache(directory: directory)
        let unfiltered = await cache.read(), filtered = await cache.read(filter: CatalogFilter(country: "Япония"))
        XCTAssertEqual(unfiltered?.releases.first?.id, 1); XCTAssertNil(filtered)
    }
    func testAuthenticatedFailureNeverShowsGuestOfflineCatalog() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let cache = CatalogCache(directory: directory)
        await cache.write([try release(1)])
        StubURLProtocol.storage.configure([.init(status: 403, body: "")])
        let model = CatalogModel(cache: cache)
        await model.load(repository: AnixartRepository(client: APIClient(session: StubURLProtocol.session())), feed: .catalog, token: "test-token", reset: true)
        XCTAssertTrue(model.releases.isEmpty); XCTAssertNil(model.cachedAt); XCTAssertNotNil(model.error)
    }
}
