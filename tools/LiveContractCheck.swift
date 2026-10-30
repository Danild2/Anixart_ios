import Foundation
import Darwin

// Compiled with the exact production Domain/Networking/SourceResolver files.
// Guest requests only; no credentials, URL dumping, fixtures, or media downloads.
@main struct LiveContractCheck {
    static func main() async {
        do { try await run() }
        catch { print("contract_failure=\(error.localizedDescription)"); fflush(nil); exit(1) }
    }
    static func run() async throws {
        let repository = AnixartRepository()
        let catalog = try await repository.catalog(page: 0, filter: CatalogFilter(), token: nil)
        guard let sample = catalog.content.first else { throw APIError.malformed }
        print("catalog_decoded count=\(catalog.content.count) sample_id=\(sample.id)")
        let query = sample.titleRu ?? sample.titleOriginal ?? String(sample.id)
        let search = try await repository.search(query, page: 0, token: nil)
        print("search_decoded count=\(search.count)")
        let detail = try await repository.release(sample.id, token: nil)
        print("detail_decoded id=\(detail.id)")
        let watching = try await repository.discover(page: 0, recommendations: false, token: nil)
        print("watching_decoded count=\(watching.content.count)")
        let schedule = try await repository.schedule()
        print("schedule_decoded days=\(schedule.days.count) releases=\(schedule.days.reduce(0) { $0 + $1.releases.count })")
        let libertyEpisode = try await repository.target(20290, source: 413, position: 1)
        let liberty = try await SourceResolver().resolveForPlayback(libertyEpisode, externalVLC: true)
        print("liberty_public_api_resolved variants=\(liberty.variants.count); actual playback checked separately in VLC")
        let collections = try await repository.collections(page: 0, token: nil)
        print("collections_decoded count=\(collections.content.count)")
        if let collection = collections.content.first {
            let content = try await repository.collectionReleases(collection.id, page: 0, token: nil)
            print("collection_releases_decoded count=\(content.content.count)")
        }
        let candidates = catalog.content.filter { ($0.episodesReleased ?? 0) > 0 && $0.isPlayDisabled != true && $0.isViewBlocked != true }
        var testedChain = false
        // Bounded to two releases, two translations, two sources and one episode per source.
        for release in candidates.prefix(2) {
            let comments = try await repository.comments(release.id, page: 0, token: nil)
            print("comments_decoded release_id=\(release.id) count=\(comments.content.count)")
            let types = try await repository.types(release.id, token: nil)
            print("types_decoded release_id=\(release.id) count=\(types.count)")
            for type in types.prefix(2) {
                let sources = try await repository.sources(release.id, type: type.id)
                print("sources_decoded type_id=\(type.id) count=\(sources.count)")
                for source in sources.prefix(2) {
                    let episodes = try await repository.episodes(release.id, type: type.id, source: source.id, token: nil)
                    print("episodes_decoded source_id=\(source.id) count=\(episodes.count)")
                    guard let episode = episodes.first else { continue }
                    let target = try await repository.target(release.id, source: source.id, position: episode.position)
                    testedChain = true
                    do {
                        switch try SourceResolver().resolve(target) {
                        case .native: print("target_decoded adapter=native; actual playback NOT tested")
                        case .embedded: print("target_decoded adapter=embedded; actual playback NOT tested")
                        }
                    } catch APIError.unsupportedMedia {
                        print("target_decoded adapter=unsupported; provider-specific parser remains unimplemented")
                    }
                }
            }
            if testedChain { break }
        }
        print("episode_chain_available=\(testedChain); auth/social mutations/iPhone/SideStore NOT tested")
    }
}
