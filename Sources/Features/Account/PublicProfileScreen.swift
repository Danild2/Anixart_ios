import SwiftUI

struct PublicProfileScreen: View {
    let id: Int64
    @Environment(\.repository) private var repository
    @Environment(SessionStore.self) private var session
    @State private var profile: Profile?
    @State private var error: String?
    @State private var loading = false
    var body: some View {
        List {
            if let error { FailureNotice(message:error) { Task { await load() } } }
            if loading { ProgressView() }
            if let profile {
                Section {
                    HStack(spacing:16) {
                        Poster(url:profile.avatar.flatMap(URL.init(string:)),width:64,height:64)
                        VStack(alignment:.leading,spacing:6) {
                            Text(profile.login ?? "Пользователь").font(.title2.bold())
                            if let status = profile.status, !status.isEmpty { Text(status).font(.subheadline).foregroundStyle(.secondary) }
                        }
                    }.padding(.vertical,8)
                }
                if profile.isStatsHidden != true, let days = profile.watchDynamics, !days.isEmpty {
                    Section { ProfileWatchDynamics(days:days) }
                }
                Section("Статистика") { ProfileStatistics(profile:profile) }
            }
        }.navigationTitle("Профиль").task(id:"\(id)|\(session.identity)") { await load() }
            .refreshable { await load() }
    }
    private func load() async {
        guard !loading else { return }
        loading = true; error = nil
        defer { loading = false }
        do { let next = try await repository.profile(id,token:session.token); try Task.checkCancellation(); profile = next }
        catch is CancellationError { }
        catch let error as URLError where error.code == .cancelled { }
        catch { self.error = error.localizedDescription }
    }
}
