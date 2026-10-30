import SwiftUI

struct CommentsScreen: View {
    let releaseID: Int64
    @Environment(\.repository) private var repository
    @Environment(SessionStore.self) private var session
    @State private var comments: [ReleaseComment] = []
    @State private var page = 0
    @State private var hasMore = true
    @State private var busy = false
    @State private var sending = false
    @State private var message = ""
    @State private var spoiler = false
    @State private var error: String?
    @State private var revealed: Set<Int64> = []
    var body: some View {
        List {
            if let error { FailureNotice(message: error) { Task { await load(reset: true) } } }
            ForEach(comments) { comment in
                VStack(alignment: .leading, spacing: 8) {
                    Text(comment.profile?.login ?? "Пользователь").font(.headline)
                    if comment.isSpoiler == true && !revealed.contains(comment.id) {
                        Button("Показать спойлер") { revealed.insert(comment.id) }
                    } else { Text(comment.message ?? "").textSelection(.enabled) }
                }.padding(.vertical, 8)
            }
            if busy { ProgressView() }
            if hasMore && !comments.isEmpty && error == nil {
                Button("Ещё комментарии") { Task { await load(reset: false) } }.disabled(busy)
            }
            if !busy && comments.isEmpty && error == nil { Text("Комментариев пока нет.").foregroundStyle(.secondary) }
            if session.token != nil {
                Section("Новый комментарий") {
                    TextField("Сообщение", text: $message, axis: .vertical).lineLimit(3...8)
                    Toggle("Содержит спойлер", isOn: $spoiler)
                    Button(sending ? "Отправка…" : "Отправить") { Task { await send() } }
                        .disabled(sending || message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            } else { NavigationLink("Войдите, чтобы оставить комментарий") { SignInScreen() } }
        }.navigationTitle("Комментарии").task(id: session.identity) { await load(reset: true) }.refreshable { await load(reset: true) }
    }
    private func load(reset: Bool) async {
        guard !busy else { return }
        if reset { page = 0; comments = []; hasMore = true }
        guard hasMore else { return }
        busy = true; error = nil; defer { busy = false }
        do {
            let response = try await repository.comments(releaseID, page: page, token: session.token)
            try Task.checkCancellation()
            let existing = Set(comments.map(\.id)); comments += response.content.filter { !existing.contains($0.id) }
            page += 1; hasMore = !response.content.isEmpty && response.totalPageCount.map { page < $0 } != false
        } catch is CancellationError { }
        catch { self.error = error.localizedDescription }
    }
    private func send() async {
        guard let token = session.token, !sending else { return }
        sending = true; error = nil; defer { sending = false }
        do {
            try await repository.addComment(releaseID, message: message, spoiler: spoiler, token: token)
            message = ""; spoiler = false; await load(reset: true)
        } catch { self.error = error.localizedDescription }
    }
}
