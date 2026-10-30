import SwiftUI

struct PlaybackScreen: View {
    let release: Release
    let translation: Translation
    let source: VideoSource
    let episode: Episode
    let account: String
    @Environment(\.repository) private var repository
    @Environment(SessionStore.self) private var session
    @Environment(\.scenePhase) private var scenePhase
    @State private var native: NativePlayback
    @State private var target: PlaybackTarget?
    @State private var error: String?
    @State private var syncError: String?
    @State private var loading = false
    @State private var attempt = 0
    init(release: Release, translation: Translation, source: VideoSource, episode: Episode, account: String) {
        self.release = release; self.translation = translation; self.source = source; self.episode = episode; self.account = account
        let key = PlaybackKey(account: account, releaseID: release.id, typeID: translation.id, sourceID: source.id, position: episode.position)
        _native = State(initialValue: NativePlayback(key: key))
    }
    var body: some View {
        VStack(spacing: 12) {
            if loading { ProgressView("Загрузка источника…") }
            switch target {
            case .native:
                if let player = native.player { NativePlayerView(player: player).frame(maxHeight: .infinity).background(.black) }
            case .embedded(let url):
                EmbeddedPlayerView(url: url, error: $error).id(attempt)
                Text("Позиция и качество управляются веб-источником. Нативное сохранение секунд для iframe пока недоступно.")
                    .font(.caption).foregroundStyle(.secondary).padding(.horizontal)
            case nil: Spacer()
            }
            if let message = error ?? native.error { FailureNotice(message: message) { attempt += 1 } }
            if let syncError { Text(syncError).font(.caption).foregroundStyle(.secondary).padding(.horizontal) }
            Text("\(translation.name) · \(source.name)").font(.caption).foregroundStyle(.secondary)
        }.navigationTitle(episode.title)
            .task(id: attempt) { await load() }
            .onDisappear { native.stop() }
            .onChange(of: scenePhase) { _, phase in if phase != .active { native.save() } }
    }
    private func load() async {
        native.stop(); target = nil; error = nil; syncError = nil; loading = true
        defer { loading = false }
        do {
            let resolved = try await repository.target(release.id, source: source.id, position: episode.position)
            try Task.checkCancellation()
            let next = try SourceResolver().resolve(resolved)
            target = next
            if case .native(let url) = next { native.start(url: url) }
            if let token = session.token {
                do { try await repository.recordHistory(release.id, source: source.id, position: episode.position, token: token) }
                catch { syncError = "История не синхронизирована: \(error.localizedDescription)" }
            }
        } catch is CancellationError { }
        catch { self.error = error.localizedDescription }
    }
}
