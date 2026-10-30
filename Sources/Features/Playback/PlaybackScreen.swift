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
    @State private var embedded: EmbeddedPlayback
    @State private var currentEpisode: Episode
    @State private var episodes: [Episode] = []
    @State private var chooseEpisode = false
    @State private var target: PlaybackTarget?
    @State private var error: String?
    @State private var syncError: String?
    @State private var loading = false
    @State private var attempt = 0
    init(release: Release, translation: Translation, source: VideoSource, episode: Episode, account: String) {
        self.release = release; self.translation = translation; self.source = source; self.episode = episode; self.account = account
        let key = PlaybackKey(account: account, releaseID: release.id, typeID: translation.id, sourceID: source.id, position: episode.position)
        _native = State(initialValue: NativePlayback(key: key))
        _embedded = State(initialValue: EmbeddedPlayback(key: key))
        _currentEpisode = State(initialValue: episode)
    }
    var body: some View {
        VStack(spacing: 12) {
            if loading { ProgressView("Загрузка источника…") }
            switch target {
            case .native:
                if let player = native.player { NativePlayerView(player: player).frame(maxHeight: .infinity).background(.black) }
            case .embedded(let url):
                EmbeddedPlayerView(url: url, playback: embedded, error: $error).id("\(currentEpisode.position)-\(attempt)")
                    .accessibilityIdentifier("embeddedPlayer")
                HStack {
                    Button { embedded.seek(by: -10) } label: { Image(systemName: "gobackward.10") }.accessibilityLabel("Назад на 10 секунд")
                    Button { embedded.play() } label: { Image(systemName: "play.fill") }.accessibilityLabel("Воспроизвести")
                    Button { embedded.pause() } label: { Image(systemName: "pause.fill") }.accessibilityLabel("Пауза")
                    Button { embedded.seek(by: 10) } label: { Image(systemName: "goforward.10") }.accessibilityLabel("Вперёд на 10 секунд")
                    Spacer()
                    Text(embedded.phase.rawValue).font(.caption).accessibilityIdentifier("playbackState")
                        .accessibilityValue(String(Int(embedded.seconds)))
                }.padding(.horizontal).disabled(!embedded.canControl)
            case nil: Spacer()
            }
            if let message = error ?? native.error ?? embedded.error { FailureNotice(message: message) { attempt += 1 } }
            if let syncError { Text(syncError).font(.caption).foregroundStyle(.secondary).padding(.horizontal) }
            Text("\(translation.name) · \(source.name)").font(.caption).foregroundStyle(.secondary)
            HStack {
                Button { moveEpisode(-1) } label: { Label("Предыдущая", systemImage: "backward.end") }.disabled(previousEpisode == nil)
                Spacer()
                Button("Серии") { chooseEpisode = true }.disabled(episodes.isEmpty)
                Spacer()
                Button { moveEpisode(1) } label: { Label("Следующая", systemImage: "forward.end") }.disabled(nextEpisode == nil)
            }.font(.caption).padding(.horizontal)
        }.navigationTitle(currentEpisode.title)
            .toolbar { NavigationLink { EpisodeScreen(release: release) } label: { Image(systemName: "waveform") }.accessibilityLabel("Сменить озвучку или источник") }
            .sheet(isPresented: $chooseEpisode) {
                NavigationStack {
                    List(episodes) { item in Button(item.title) { currentEpisode = item; chooseEpisode = false } }
                        .navigationTitle("Серии").toolbar { Button("Закрыть") { chooseEpisode = false } }
                }.presentationDetents([.medium, .large])
            }
            .task(id: "\(currentEpisode.position)-\(attempt)") { await load() }
            .onDisappear { native.stop(); embedded.pause() }
            .onChange(of: scenePhase) { _, phase in if phase != .active { native.save(); embedded.save() } }
    }
    private var currentIndex: Int? { episodes.firstIndex { $0.position == currentEpisode.position } }
    private var previousEpisode: Episode? { guard let i = currentIndex, i > 0 else { return nil }; return episodes[i - 1] }
    private var nextEpisode: Episode? { guard let i = currentIndex, i + 1 < episodes.count else { return nil }; return episodes[i + 1] }
    private func moveEpisode(_ delta: Int) { if let value = delta < 0 ? previousEpisode : nextEpisode { currentEpisode = value } }
    private func load() async {
        native.stop(); embedded.pause(); target = nil; error = nil; syncError = nil; loading = true
        let key = PlaybackKey(account: account, releaseID: release.id, typeID: translation.id, sourceID: source.id, position: currentEpisode.position)
        native = NativePlayback(key: key); embedded = EmbeddedPlayback(key: key)
        defer { loading = false }
        do {
            let resolved = try await repository.target(release.id, source: source.id, position: currentEpisode.position)
            try Task.checkCancellation()
            let next = try SourceResolver().resolve(resolved)
            target = next
            if case .native(let url) = next { native.start(url: url) }
            if episodes.isEmpty { episodes = try await repository.episodes(release.id, type: translation.id, source: source.id, token: session.token) }
            if let token = session.token {
                do { try await repository.recordHistory(release.id, source: source.id, position: currentEpisode.position, token: token) }
                catch { syncError = "История не синхронизирована: \(error.localizedDescription)" }
            }
        } catch is CancellationError { }
        catch { self.error = error.localizedDescription }
    }
}
