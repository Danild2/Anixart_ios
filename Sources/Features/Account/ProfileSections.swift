import SwiftUI
import SafariServices

struct RemoteProfileList<Item: Decodable & Identifiable & Sendable, Row: View>: View {
    let title: String
    let path: String
    var query: [String:String] = [:]
    @ViewBuilder let row: (Item) -> Row
    @Environment(\.repository) private var repository
    @Environment(SessionStore.self) private var session
    @State private var items: [Item] = []
    @State private var page = 0
    @State private var more = true
    @State private var loading = false
    @State private var error: String?
    var body: some View {
        List {
            ForEach(items) { row($0) }
            if let error { FailureNotice(message:error) { Task { await load(reset:false) } } }
            if loading { ProgressView().frame(maxWidth:.infinity) }
            if !loading, error == nil, items.isEmpty { Text("Здесь пока ничего нет").foregroundStyle(.secondary) }
            if !items.isEmpty, more, error == nil { Color.clear.frame(height:1).onAppear { Task { await load(reset:false) } } }
        }.listStyle(.plain).navigationTitle(title)
            .task(id:"\(path)|\(query.sorted { $0.key < $1.key })|\(session.identity)") { await load(reset:true) }
            .refreshable { await load(reset:true) }
    }
    private func load(reset: Bool) async {
        guard !loading else { return }
        if reset { page = 0; items = []; more = true }
        guard more else { return }; loading = true; error = nil; defer { loading = false }
        do {
            let result: Page<Item> = try await repository.profilePage(path,page:page,query:query,token:session.token)
            try Task.checkCancellation()
            let existing = Set(items.map(\.id)); items += result.content.filter { !existing.contains($0.id) }
            page += 1; more = !result.content.isEmpty && result.totalPageCount.map { page < $0 } != false
        } catch is CancellationError { }
        catch let e as URLError where e.code == .cancelled { }
        catch { self.error = error.localizedDescription }
    }
}

struct ProfileSectionScreen: View {
    let profile: Profile
    let section: ProfileSection
    @State private var commentKind = 0
    @State private var sort = 0
    var body: some View {
        Group {
            switch section {
            case .statistics:
                ScrollView { ProfileStatistics(profile:profile).padding(20) }
            case .votes:
                RemoteProfileList(title:section.title,path:"profile/vote/release/voted/\(profile.id)",query:["sort":String(sort)]) { (release: Release) in
                    NavigationLink { ReleaseScreen(id:release.id) } label: { ProfileVoteRow(release:release) }
                }.toolbar { Menu("Сортировка") { Button("Сначала новые") { sort = 0 }; Button("Сначала старые") { sort = 1 } } }
            case .collections:
                RemoteProfileList(title:section.title,path:"collection/all/profile/\(profile.id)") { (collection: CollectionSummary) in ProfileCollectionRow(collection:collection) }
            case .comments:
                VStack {
                    Picker("Комментарии",selection:$commentKind) { Text("Релизы").tag(0); Text("Коллекции").tag(1); Text("Записи").tag(2) }.pickerStyle(.segmented).padding(.horizontal)
                    RemoteProfileList(title:section.title,path:"\(["release","collection","article"][commentKind])/comment/all/profile/\(profile.id)",query:["sort":"0"]) { (comment: ProfileComment) in ProfileCommentCard(comment:comment) }.id(commentKind)
                }
            case .videos:
                RemoteProfileList(title:section.title,path:"video/profile/\(profile.id)") { (video: ProfileVideo) in ProfileVideoRow(video:video) }
            case .badges: ProfileBadgesScreen(id:profile.id)
            }
        }.navigationTitle(section.title)
    }
}

struct ProfileVoteRow: View {
    let release: Release
    var body: some View {
        HStack(alignment:.top,spacing:16) {
            Poster(url:release.poster,width:64,height:96)
            VStack(alignment:.leading,spacing:8) {
                Text(release.title).font(.subheadline.weight(.semibold)).foregroundStyle(.primary)
                if let vote = release.myVote {
                    HStack(spacing:3) { ForEach(1...5,id:\.self) { i in Image(systemName:i <= vote ? "star.fill" : "star").foregroundStyle(i <= vote ? Color.yellow : .secondary) } }.font(.caption)
                }
                if let date = release.votedAt, date > 0 { Text(ProfileDate.text(date)).font(.caption).foregroundStyle(.secondary) }
            }.frame(maxWidth:.infinity,alignment:.leading)
        }.padding(.vertical,4)
    }
}
struct ProfileCollectionRow: View {
    let collection: CollectionSummary
    var body: some View {
        NavigationLink { CatalogScreen(title:collection.title ?? "Коллекция",feed:.collection(collection.id)) } label: {
            HStack(spacing:16) {
                Poster(url:collection.image.flatMap(URL.init(string:)),width:90,height:68)
                VStack(alignment:.leading,spacing:6) {
                    Text(collection.title ?? "Коллекция").font(.subheadline.weight(.semibold))
                    HStack {
                        if collection.isPrivate == true { Image(systemName:"lock") }
                        if let count = collection.favoriteCount { Label(count.formatted(),systemImage:"heart") }
                        if let count = collection.commentCount { Label(count.formatted(),systemImage:"bubble.right") }
                    }.font(.caption).foregroundStyle(.secondary)
                }.frame(maxWidth:.infinity,alignment:.leading)
            }
        }.buttonStyle(.plain)
    }
}
struct ProfileCommentCard: View {
    let comment: ProfileComment
    @State private var reveal = false
    var body: some View {
        VStack(alignment:.leading,spacing:10) {
            if let release = comment.release { NavigationLink { ReleaseScreen(id:release.id) } label: { Text(release.title).font(.subheadline.bold()) } }
            if let collection = comment.collection { ProfileCollectionRow(collection:collection) }
            if let article = comment.article { NavigationLink("Запись в блоге") { ProfileArticleScreen(id:article.id) } }
            if comment.isDeleted == true { Text("Комментарий удалён").foregroundStyle(.secondary) }
            else if comment.isSpoiler == true && !reveal { Button("Спойлер · показать") { reveal = true } }
            else { Text(comment.message ?? "").font(.subheadline).textSelection(.enabled) }
            HStack {
                if let time = comment.timestamp { Text(ProfileDate.text(time)) }
                if comment.isEdited == true { Text("изменён") }
                Spacer()
                if let count = comment.voteCount { Label(count.formatted(),systemImage:"hand.thumbsup") }
                if let count = comment.replyCount, count > 0 { Label(count.formatted(),systemImage:"bubble.right") }
            }.font(.caption).foregroundStyle(.secondary)
            Divider()
        }.padding(.vertical,8)
    }
}
struct ProfileVideoRow: View {
    let video: ProfileVideo
    @State private var open = false
    private var url: URL? { (video.playerUrl?.isEmpty == false ? video.playerUrl : video.url).flatMap(URL.init(string:)).flatMap { ["http","https"].contains($0.scheme?.lowercased() ?? "") ? $0 : nil } }
    var body: some View {
        Button { open = true } label: {
            VStack(alignment:.leading,spacing:8) {
                GeometryReader { g in Poster(url:video.image.flatMap(URL.init(string:)),width:g.size.width,height:g.size.height).overlay { Image(systemName:"play.circle.fill").font(.largeTitle).foregroundStyle(.white) } }.aspectRatio(16/9,contentMode:.fit)
                Text(video.title ?? "Видео").font(.headline)
                if let release = video.release { Text(release.title).font(.subheadline).foregroundStyle(.secondary) }
                HStack { if let name = video.hosting?.name { Text(name) }; if let timestamp = video.timestamp { Text(ProfileDate.text(timestamp)) } }.font(.caption).foregroundStyle(.secondary)
            }
        }.buttonStyle(.plain).disabled(url == nil).sheet(isPresented:$open) { if let url { ProfileWebPage(url:url).ignoresSafeArea() } }
    }
}
struct ProfileWebPage: UIViewControllerRepresentable {
    let url: URL
    func makeUIViewController(context: Context) -> SFSafariViewController { SFSafariViewController(url:url) }
    func updateUIViewController(_ controller: SFSafariViewController,context: Context) { }
}

struct ProfilePeopleScreen: View {
    let id: Int64
    let own: Bool
    @State private var tab = 0
    private var path: String { tab == 0 ? "profile/friend/all/\(id)" : tab == 1 ? "profile/friend/requests/in" : "profile/friend/requests/out" }
    var body: some View {
        VStack {
            if own { Picker("Друзья",selection:$tab) { Text("Друзья").tag(0); Text("Входящие").tag(1); Text("Исходящие").tag(2) }.pickerStyle(.segmented).padding(.horizontal) }
            RemoteProfileList(title:OriginalCopy.text("profile_all_friends"),path:path) { (p: Profile) in
                NavigationLink { PublicProfileScreen(id:p.id) } label: {
                    HStack(spacing:14) {
                        Poster(url:p.avatar.flatMap(URL.init(string:)),width:48,height:48).clipShape(Circle())
                        VStack(alignment:.leading,spacing:6) { Text(p.login ?? "Пользователь"); if p.isOnline == true { Text("В сети").font(.caption).foregroundStyle(.green) } }
                    }
                }
            }.id(tab)
        }
    }
}
struct ProfileLoginChange: Decodable, Identifiable, Sendable { var id: Int64; var oldLogin: String?; var newLogin: String?; var timestamp: Int64? }
struct ProfileLoginHistoryScreen: View {
    let id: Int64
    var body: some View {
        RemoteProfileList(title:"История логина",path:"profile/login/history/all/\(id)") { (item: ProfileLoginChange) in
            VStack(alignment:.leading,spacing:6) { Text("\(item.oldLogin ?? "") → \(item.newLogin ?? "")"); if let time = item.timestamp { Text(ProfileDate.day(time)).font(.caption).foregroundStyle(.secondary) } }
        }
    }
}
