import SwiftUI

struct CatalogScreen: View {
    let title: String
    let feed: ReleaseFeed
    var searchable = false
    let persistenceKey: String?
    @Environment(\.repository) private var repository
    @Environment(SessionStore.self) private var session
    @Environment(AppSettings.self) private var settings
    @State private var model = CatalogModel()
    @State private var query = ""
    @State private var filter = CatalogFilter()
    @State private var showFilters = false
    init(title: String, feed: ReleaseFeed, searchable: Bool = false, initialFilter: CatalogFilter = CatalogFilter(), persistenceKey: String? = nil) {
        self.title = title; self.feed = feed; self.searchable = searchable
        self.persistenceKey = persistenceKey
        let saved = persistenceKey.flatMap { UserDefaults.standard.data(forKey: $0) }.flatMap { try? JSONDecoder().decode(CatalogFilter.self, from: $0) }
        _filter = State(initialValue: saved ?? initialFilter)
    }
    private var reloadID: String { "\(query)|\(filter)|\(feed)|\(session.identity)|\(settings.useRegionalAPI)" }

    var body: some View {
        Group {
            if searchable { content.searchable(text: $query, prompt: "Поиск аниме") }
            else { content }
        }
        .navigationTitle(title)
        .toolbar {
            if searchable {
                Button { showFilters = true } label: { Image(systemName: "slider.horizontal.3") }.accessibilityLabel("Фильтры")
            }
        }
        .sheet(isPresented: $showFilters) { FilterScreen(filter: $filter) }
        .task(id: reloadID) {
            do { if !query.isEmpty { try await Task.sleep(for: .milliseconds(350)) }; try Task.checkCancellation() }
            catch { return }
            await load(reset: true)
        }
        .refreshable { await load(reset: true) }
        .onChange(of: filter) { _, value in if let persistenceKey, let data = try? JSONEncoder().encode(value) { UserDefaults.standard.set(data, forKey: persistenceKey) } }
    }
    private var content: some View {
        List {
            if let date = model.cachedAt {
                Label("Сохранённый каталог: \(date.formatted(date: .abbreviated, time: .shortened))", systemImage: "clock").font(.caption)
            }
            if let error = model.error { FailureNotice(message: error) { Task { await load(reset: true) } } }
            ForEach(model.releases) { release in
                NavigationLink(value: release) { ReleaseRow(release: release) }.accessibilityIdentifier("release.\(release.id)")
            }
            if model.loading { HStack { Spacer(); ProgressView(); Spacer() } }
            else if model.releases.isEmpty && model.error == nil { ContentUnavailableView("Нет релизов", systemImage: "magnifyingglass", description: Text("Измените поиск или фильтры.")) }
            if model.hasMore && !model.releases.isEmpty && model.error == nil {
                Color.clear.frame(height: 1).onAppear { Task { await load(reset: false) } }
            }
        }.listStyle(.plain).accessibilityIdentifier("releaseList")
    }
    private func load(reset: Bool) async {
        await model.load(repository: repository, feed: feed, query: query, filter: filter, token: session.token, reset: reset)
    }
}

private struct FilterScreen: View {
    @Binding var filter: CatalogFilter
    @Environment(\.dismiss) private var dismiss
    @State private var draft = CatalogFilter()
    @State private var startYear = ""
    @State private var endYear = ""
    @State private var genres = ""
    private let sorts = OriginalCopy.array("sort")
    private var valid: Bool {
        let first = Int(startYear), last = Int(endYear)
        return (startYear.isEmpty || first != nil) && (endYear.isEmpty || last != nil)
            && (first == nil || last == nil || first! <= last!)
    }
    var body: some View {
        NavigationStack {
            Form {
                Picker("Сортировка", selection: $draft.sort) { ForEach(sorts.indices, id: \.self) { Text(sorts[$0]).tag($0) } }
                Section("Год выпуска") {
                    TextField("С", text: $startYear).keyboardType(.numberPad)
                    TextField("По", text: $endYear).keyboardType(.numberPad)
                    if !valid { Text("Укажите корректный диапазон лет.").foregroundStyle(.red) }
                }
                Section("Жанры") { TextField("Названия через запятую", text: $genres) }
                Button("Сбросить") { draft = CatalogFilter(); startYear = ""; endYear = ""; genres = "" }
            }.navigationTitle("Фильтры")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Отмена") { dismiss() } }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Применить") {
                            draft.startYear = Int(startYear); draft.endYear = Int(endYear)
                            draft.genres = genres.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
                            filter = draft; dismiss()
                        }.disabled(!valid)
                    }
                }
                .onAppear { draft = filter; startYear = filter.startYear.map(String.init) ?? ""; endYear = filter.endYear.map(String.init) ?? ""; genres = filter.genres.joined(separator: ", ") }
        }
    }
}
