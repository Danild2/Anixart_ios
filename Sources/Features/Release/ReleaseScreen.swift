import SwiftUI

struct ReleaseScreen: View {
    let initial: Release
    @Environment(\.repository) private var repository
    @Environment(SessionStore.self) private var session
    @State private var release: Release?
    @State private var error: String?
    @State private var loading = false
    @State private var acting = false
    private var item: Release { release ?? initial }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack(alignment: .top, spacing: 20) {
                    Poster(url: item.poster, width: 130, height: 195)
                    VStack(alignment: .leading, spacing: 12) {
                        Text(item.title).font(.title2.bold())
                        if let title = item.titleOriginal { Text(title).font(.subheadline).foregroundStyle(.secondary) }
                        if let year = item.year { Text(year) }
                        if let grade = item.grade { Label(grade.formatted(.number.precision(.fractionLength(2))), systemImage: "star.fill") }
                    }
                }
                if loading { ProgressView("Обновление релиза…") }
                if let error { FailureNotice(message: error) { Task { await reload() } } }
                if item.isPlayDisabled == true || item.isViewBlocked == true {
                    Text("Просмотр этого релиза ограничен сервером.").foregroundStyle(.secondary)
                } else {
                    NavigationLink { EpisodeScreen(release: item) } label: {
                        Label("Смотреть", systemImage: "play.fill").frame(maxWidth: .infinity).modifier(GlassAction())
                    }.buttonStyle(.plain)
                }
                if session.token != nil {
                    HStack {
                        Menu {
                            ForEach(WatchStatus.allCases) { status in
                                Button(status.title) { act { token in try await repository.setStatus(item.id, status: status, token: token) } }
                            }
                            if let raw = item.profileListStatus, let status = WatchStatus(rawValue: raw) {
                                Button("Убрать из списка", role: .destructive) { act { token in try await repository.setStatus(item.id, status: status, remove: true, token: token) } }
                            }
                        } label: { Label(item.profileListStatus.flatMap(WatchStatus.init(rawValue:))?.title ?? "В список", systemImage: "text.badge.plus") }
                        Spacer()
                        Menu {
                            ForEach(1...5, id: \.self) { value in
                                Button("\(value) ★") { act { token in try await repository.vote(item.id, value: value, token: token) } }
                            }
                        } label: { Label("Оценить", systemImage: "star") }
                    }.disabled(acting)
                } else { NavigationLink("Войдите, чтобы сохранять и оценивать") { SignInScreen() } }
                if let description = item.description { Text(description).textSelection(.enabled) }
                Group {
                    if let genres = item.genres { LabeledContent("Жанры", value: genres) }
                    if let studio = item.studio { LabeledContent("Студия", value: studio) }
                    if let country = item.country { LabeledContent("Страна", value: country) }
                }.font(.subheadline)
                NavigationLink { CommentsScreen(releaseID: item.id) } label: { Label("Комментарии", systemImage: "text.bubble") }
                if let related = item.relatedReleases, !related.isEmpty {
                    Text("Связанное").font(.headline)
                    ForEach(related) { release in NavigationLink(value: release) { ReleaseRow(release: release) } }
                }
                if let recommended = item.recommendedReleases, !recommended.isEmpty {
                    Text("Рекомендации").font(.headline)
                    ForEach(recommended) { release in NavigationLink(value: release) { ReleaseRow(release: release) } }
                }
            }.padding()
        }.navigationTitle("О релизе")
            .toolbar {
                if session.token != nil {
                    Button { act { token in try await repository.setFavorite(item.id, enabled: item.isFavorite != true, token: token) } } label: { Image(systemName: item.isFavorite == true ? "bookmark.fill" : "bookmark") }
                        .disabled(acting).accessibilityLabel(item.isFavorite == true ? "Удалить из избранного" : "В избранное")
                }
            }
            .task(id: session.identity) { await reload() }.refreshable { await reload() }
    }
    private func reload() async {
        loading = true; error = nil; defer { loading = false }
        do { let next = try await repository.release(initial.id, token: session.token); try Task.checkCancellation(); release = next }
        catch is CancellationError { }
        catch { self.error = error.localizedDescription }
    }
    private func act(_ action: @escaping (String) async throws -> Void) {
        guard !acting, let token = session.token else { return }
        acting = true; error = nil
        Task {
            defer { acting = false }
            do { try await action(token); await reload() }
            catch { self.error = error.localizedDescription }
        }
    }
}
