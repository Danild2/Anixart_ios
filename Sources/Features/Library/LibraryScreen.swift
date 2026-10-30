import SwiftUI

struct LibraryScreen: View {
    @Environment(SessionStore.self) private var session
    @State private var selection = "favorite/all"
    var body: some View {
        if session.token == nil { SignInScreen() }
        else {
            VStack(spacing: 0) {
                Picker("Список", selection: $selection) {
                    Text("Избранное").tag("favorite/all")
                    ForEach(WatchStatus.allCases) { Text($0.title).tag("profile/list/all/\($0.rawValue)") }
                    Text("История").tag("history")
                }.pickerStyle(.menu).padding(.horizontal).frame(maxWidth: .infinity, alignment: .leading)
                CatalogScreen(title: "Закладки", feed: .library(selection)).id(selection)
            }
        }
    }
}

struct DiscoverScreen: View {
    @State private var selection = 0
    var body: some View {
        VStack(spacing: 0) {
            NavigationLink { ScheduleScreen() } label: {
                Label(OriginalCopy.text("schedule"), systemImage: "calendar")
                    .frame(maxWidth: .infinity, alignment: .leading).padding()
            }.buttonStyle(.plain).accessibilityIdentifier("openSchedule")
            Picker("Раздел обзора", selection: $selection) {
                Text("Сейчас смотрят").tag(0); Text("Рекомендации").tag(1); Text("Коллекции").tag(2)
            }.pickerStyle(.menu).padding(.horizontal).frame(maxWidth: .infinity, alignment: .leading)
            if selection == 2 { CollectionsScreen() }
            else { CatalogScreen(title: "Обзор", feed: selection == 0 ? .watching : .recommendations).id(selection) }
        }
    }
}

private struct CollectionsScreen: View {
    @Environment(\.repository) private var repository
    @Environment(SessionStore.self) private var session
    @State private var items: [CollectionSummary] = []
    @State private var page = 0
    @State private var hasMore = true
    @State private var loading = false
    @State private var error: String?
    var body: some View {
        List {
            if let error { FailureNotice(message: error) { Task { await load(reset: true) } } }
            ForEach(items) { item in
                NavigationLink {
                    CatalogScreen(title: item.title ?? "Коллекция", feed: .collection(item.id))
                } label: {
                    HStack { Poster(url: item.image.flatMap(URL.init(string:)), width: 80, height: 100); Text(item.title ?? "Коллекция №\(item.id)").font(.headline) }
                }
            }
            if loading { ProgressView() }
            if !items.isEmpty && hasMore && error == nil { Color.clear.frame(height: 1).onAppear { Task { await load(reset: false) } } }
        }.listStyle(.plain).navigationTitle("Обзор")
            .task(id: session.identity) { await load(reset: true) }.refreshable { await load(reset: true) }
    }
    private func load(reset: Bool) async {
        guard !loading else { return }
        if reset { page = 0; items = []; hasMore = true }
        guard hasMore else { return }
        loading = true; error = nil; defer { loading = false }
        do {
            let response = try await repository.collections(page: page, token: session.token)
            try Task.checkCancellation()
            let existing = Set(items.map(\.id)); items += response.content.filter { !existing.contains($0.id) }
            page += 1; hasMore = !response.content.isEmpty && response.totalPageCount.map { page < $0 } != false
        } catch is CancellationError { }
        catch { self.error = error.localizedDescription }
    }
}
