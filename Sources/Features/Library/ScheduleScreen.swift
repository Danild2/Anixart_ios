import SwiftUI

struct ScheduleScreen: View {
    @Environment(\.repository) private var repository
    @Environment(AppSettings.self) private var settings
    @State private var schedule: ScheduleResponse?
    @State private var loading = false
    @State private var error: String?
    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 24) {
                Text(OriginalCopy.text("schedule_hint")).font(.footnote).foregroundStyle(.secondary).padding(.horizontal)
                if loading { ProgressView().frame(maxWidth: .infinity) }
                if let error { FailureNotice(message: error) { Task { await load() } } }
                if let schedule {
                    ForEach(schedule.days, id: \.key) { day in
                        VStack(alignment: .leading, spacing: 16) {
                            Text(OriginalCopy.text(day.key)).font(.title3.bold()).padding(.horizontal)
                            if day.releases.isEmpty {
                                Text("Нет запланированных релизов").font(.caption).foregroundStyle(.secondary).padding(.horizontal)
                            } else {
                                ScrollView(.horizontal) {
                                    LazyHStack(alignment: .top, spacing: 12) {
                                        ForEach(day.releases) { release in
                                            NavigationLink(value: release) {
                                                VStack(alignment: .leading, spacing: 8) {
                                                    Poster(url: release.poster, width: 104, height: 156)
                                                    Text(release.title).font(.caption).lineLimit(2).foregroundStyle(.primary)
                                                    if let count = release.episodesReleased {
                                                        Text("\(count) / \(release.episodesTotal.map(String.init) ?? "?")")
                                                            .font(.caption2).foregroundStyle(.secondary)
                                                    }
                                                }.frame(width: 114, alignment: .leading)
                                            }.buttonStyle(.plain).accessibilityIdentifier("schedule.release.\(release.id)")
                                        }
                                    }.padding(.horizontal)
                                }.scrollIndicators(.hidden)
                            }
                        }
                    }
                }
            }.padding(.vertical)
        }.navigationTitle(OriginalCopy.text("schedule"))
            .task(id: settings.useRegionalAPI) { await load() }
            .refreshable { await load() }
    }
    private func load() async {
        guard !loading else { return }
        loading = true; error = nil
        defer { loading = false }
        do { let next = try await repository.schedule(); try Task.checkCancellation(); schedule = next }
        catch is CancellationError { }
        catch { self.error = error.localizedDescription }
    }
}
