import SwiftUI

struct EpisodeScreen: View {
    let release: Release
    @Environment(\.repository) private var repository
    @Environment(SessionStore.self) private var session
    @State private var types: [Translation] = []
    @State private var error: String?
    @State private var loading = false
    var body: some View {
        List {
            if let error { FailureNotice(message: error) { Task { await load() } } }
            Section("Озвучка и субтитры") {
                ForEach(types) { type in
                    NavigationLink {
                        SourcesScreen(release: release, translation: type)
                    } label: {
                        VStack(alignment: .leading) {
                            Text(type.name)
                            if type.isSub == true { Text("Субтитры").font(.caption).foregroundStyle(.secondary) }
                            if let count = type.episodesCount { Text("Серий: \(count)").font(.caption).foregroundStyle(.secondary) }
                        }
                    }
                    .accessibilityIdentifier("translation.\(type.id)")
                }
            }
            if loading { ProgressView() }
            else if types.isEmpty && error == nil { Text(OriginalCopy.text("error_no_types")) }
        }.navigationTitle("Смотреть").task(id: session.identity) { await load() }
    }
    private func load() async {
        loading = true; error = nil; defer { loading = false }
        do { let next = try await repository.types(release.id, token: session.token); try Task.checkCancellation(); types = next }
        catch is CancellationError { }
        catch { self.error = error.localizedDescription }
    }
}

private struct SourcesScreen: View {
    let release: Release
    let translation: Translation
    @Environment(\.repository) private var repository
    @State private var sources: [VideoSource] = []
    @State private var error: String?
    @State private var loading = false
    var body: some View {
        List {
            if let error { FailureNotice(message: error) { Task { await load() } } }
            ForEach(sources) { source in
                NavigationLink { EpisodesListScreen(release: release, translation: translation, source: source) } label: {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(source.name)
                        if let quality = source.quality, quality > 0 { Text("Качество источника: \(quality)").font(.caption).foregroundStyle(.secondary) }
                    }
                }
                .accessibilityIdentifier("source.\(source.id)")
            }
            if loading { ProgressView() }
            else if sources.isEmpty && error == nil { Text(OriginalCopy.text("error_no_sources")) }
        }.navigationTitle(translation.name).task { await load() }
    }
    private func load() async {
        loading = true; error = nil; defer { loading = false }
        do { let next = try await repository.sources(release.id, type: translation.id); try Task.checkCancellation(); sources = next }
        catch is CancellationError { }
        catch { self.error = error.localizedDescription }
    }
}

private struct EpisodesListScreen: View {
    let release: Release
    let translation: Translation
    let source: VideoSource
    @Environment(\.repository) private var repository
    @Environment(SessionStore.self) private var session
    @State private var episodes: [Episode] = []
    @State private var error: String?
    @State private var loading = false
    @State private var updating = false
    var body: some View {
        List {
            if let error { FailureNotice(message: error) { Task { await load() } } }
            ForEach(episodes) { episode in
                NavigationLink {
                    PlaybackScreen(release: release, translation: translation, source: source, episode: episode,
                                   account: session.identity)
                } label: {
                    HStack {
                        VStack(alignment: .leading) {
                            Text(episode.title)
                            if episode.isFiller == true { Text("Филлер").font(.caption).foregroundStyle(.secondary) }
                        }
                        Spacer()
                        if episode.isWatched == true { Image(systemName: "checkmark.circle.fill").foregroundStyle(.secondary) }
                    }
                }
                .accessibilityIdentifier("episode.\(episode.position)")
                .contextMenu {
                    if session.token != nil {
                        Button(OriginalCopy.text(episode.isWatched == true ? "watch_mark_remove" : "watch_mark_add")) {
                            Task { await mark(position: episode.position, watched: episode.isWatched != true) }
                        }.disabled(updating)
                    }
                }
            }
            if loading { ProgressView() }
            else if episodes.isEmpty && error == nil { Text(OriginalCopy.text("error_no_episodes")) }
        }.navigationTitle(source.name)
            .toolbar {
                if session.token != nil {
                    Menu {
                        Button(OriginalCopy.text("watch_marks_add")) { Task { await mark(watched: true) } }
                        Button(OriginalCopy.text("watch_marks_remove")) { Task { await mark(watched: false) } }
                    } label: { Image(systemName: "checkmark.circle") }
                        .accessibilityLabel("Отметки просмотра").disabled(updating || episodes.isEmpty)
                }
            }.task(id: session.identity) { await load() }
    }
    private func mark(position: Int? = nil, watched: Bool) async {
        guard !updating, let token = session.token else { return }
        updating = true; error = nil
        defer { updating = false }
        do {
            try await repository.setEpisodeWatched(release.id, source: source.id, position: position, watched: watched, token: token)
            guard session.token == token else { return }
            await load()
        } catch is CancellationError { }
        catch { self.error = error.localizedDescription }
    }
    private func load() async {
        loading = true; error = nil; defer { loading = false }
        do {
            let next = try await repository.episodes(release.id, type: translation.id, source: source.id, token: session.token)
            try Task.checkCancellation(); episodes = next
        } catch is CancellationError { }
        catch { self.error = error.localizedDescription }
    }
}
