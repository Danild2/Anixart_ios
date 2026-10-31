import Foundation
import Observation

@MainActor @Observable final class ProfilePageState<Item: Identifiable & Sendable> {
    private(set) var items: [Item] = []
    private(set) var page = 0
    private(set) var more = true
    private(set) var loading = false
    private(set) var error: String?
    private var generation = UUID()

    func load(reset: Bool, fetch: @Sendable (Int) async throws -> Page<Item>) async where Item: Decodable {
        if reset { generation = UUID(); page = 0; items = []; more = true }
        else if loading || !more { return }
        let requestGeneration = generation, requestPage = page
        loading = true; error = nil
        defer { if generation == requestGeneration { loading = false } }
        do {
            let result = try await fetch(requestPage)
            try Task.checkCancellation()
            guard generation == requestGeneration else { return }
            var seen = Set(items.map(\.id))
            let fresh = result.content.filter { seen.insert($0.id).inserted }
            items += fresh; page += 1
            more = !fresh.isEmpty && result.totalPageCount.map { page < $0 } != false
        } catch is CancellationError { }
        catch let e as URLError where e.code == .cancelled { }
        catch { if generation == requestGeneration { self.error = error.localizedDescription } }
    }
}
