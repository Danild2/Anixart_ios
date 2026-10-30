import Foundation
import Observation

enum ReleaseFeed: Hashable {
    case catalog, watching, recommendations, library(String), collection(Int64)
}

@MainActor @Observable final class CatalogModel {
    private(set) var releases: [Release] = []
    private(set) var loading = false
    private(set) var hasMore = true
    private(set) var cachedAt: Date?
    var error: String?
    private var page = 0
    private var generation = UUID()
    private let cache = CatalogCache()

    func load(repository: AnixartRepository, feed: ReleaseFeed, query: String = "", filter: CatalogFilter = CatalogFilter(),
              token: String?, reset: Bool) async {
        if reset { generation = UUID(); page = 0; releases = []; hasMore = true; cachedAt = nil }
        else if loading || !hasMore { return }
        let generation = self.generation
        loading = true; error = nil
        defer { if generation == self.generation { loading = false } }
        do {
            let content: [Release]
            var totalPages: Int?
            if !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                // Global search is offered only by the catalog screen.
                content = try await repository.search(query, page: page, token: token)
            } else {
                let response: Page<Release>
                switch feed {
                case .catalog: response = try await repository.catalog(page: page, filter: filter, token: token)
                case .watching: response = try await repository.discover(page: page, recommendations: false, token: token)
                case .recommendations: response = try await repository.discover(page: page, recommendations: true, token: token)
                case .library(let path):
                    guard let token else { throw APIError.unauthorized }
                    response = try await repository.library(path: path, page: page, token: token)
                case .collection(let id): response = try await repository.collectionReleases(id, page: page, token: token)
                }
                content = response.content; totalPages = response.totalPageCount
            }
            try Task.checkCancellation()
            guard generation == self.generation else { return }
            var seen = Set(releases.map(\.id))
            let fresh = content.filter { seen.insert($0.id).inserted }
            releases += fresh
            page += 1
            hasMore = !fresh.isEmpty && totalPages.map { page < $0 } != false
            if reset, feed == .catalog, query.isEmpty, filter == CatalogFilter(), token == nil { await cache.write(content) }
        } catch is CancellationError { }
        catch let error as URLError where error.code == .cancelled { }
        catch {
            guard generation == self.generation else { return }
            self.error = error.localizedDescription
            if reset, feed == .catalog, query.isEmpty, filter == CatalogFilter(), token == nil,
               let snapshot = await cache.read(), generation == self.generation {
                releases = snapshot.releases; cachedAt = snapshot.savedAt; hasMore = false
            }
        }
    }
}
