import SwiftUI

enum ProfileSection: Int, CaseIterable, Identifiable {
    case statistics, votes, collections, comments, videos, badges
    var id: Int { rawValue }
    var title: String { OriginalCopy.text(["profile_stats","profile_votes","collections","title_comments","title_videos","profile_badges"][rawValue]) }
    func count(_ p: Profile) -> Int? {
        switch self {
        case .statistics,.votes: nil
        case .collections: p.collectionCount
        case .comments: p.commentCount
        case .videos: p.videoCount
        case .badges: p.badgeCount
        }
    }
    static func visible(in p: Profile) -> [Self] {
        let visible = allCases.filter {
            switch $0 {
            case .statistics,.votes: p.isStatsHidden != true
            case .collections,.comments,.videos: p.isCountsHidden != true
            case .badges: true
            }
        }
        guard let pinned = visible.first(where: { $0.rawValue == p.pinnedSectionId }) else { return visible }
        return [pinned] + visible.filter { $0 != pinned }
    }
}

struct FullProfileScreen: View {
    let id: Int64
    @Environment(\.repository) private var repository
    @Environment(SessionStore.self) private var session
    @State private var profile: Profile?
    @State private var blog: ProfileChannel?
    @State private var error: String?
    @State private var blogError: String?
    @State private var loading = false
    @State private var generation = UUID()
    @State private var loadedContext: String?
    @State private var section = ProfileSection.statistics
    @State private var editing = false
    @State private var showSocial = false
    @State private var newPost = false
    @State private var message: String?
    private var own: Bool { session.session?.profile.id == id }
    private var background: Color { Color(uiColor:.systemBackground) }
    private var context: String { "\(id)|\(session.identity)" }
    var body: some View {
        ScrollView {
            LazyVStack(spacing:0) {
                if let error { FailureNotice(message:error) { Task { await load() } } }
                if let p = profile {
                    header(p)
                    if p.isDeleted != true {
                        showcase(p)
                        if p.isStatsHidden != true {
                            if let days = p.watchDynamics, !days.isEmpty {
                                Divider().padding(.top,20)
                                ProfileWatchDynamics(days:days).padding(20)
                            }
                            if let history = p.history, !history.isEmpty { historySection(history) }
                        } else { Text(OriginalCopy.text("profile_is_hidden")).font(.footnote).foregroundStyle(.secondary).padding(20) }
                        if let blog { ProfileBlogSection(channel:blog,own:own) }
                        else if let blogError { FailureNotice(message:blogError) { Task { await loadBlog() } } }
                        else if own {
                            Button { newPost = true } label: { Label("Новая запись",systemImage:"square.and.pencil").frame(maxWidth:.infinity,minHeight:60) }.buttonStyle(.bordered).padding(20)
                        }
                    }
                } else if loading { ProgressView().padding(60) }
            }
        }.navigationTitle("Профиль").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if own {
                    ToolbarItem(placement:.topBarTrailing) {
                        NavigationLink { SettingsScreen() } label: { Image(systemName:"gearshape") }.accessibilityLabel("Настройки")
                    }
                }
            }
            .task(id:context) {
                if loadedContext != context { profile = nil; blog = nil; blogError = nil; loadedContext = context }
                await load()
            }
            .refreshable { await load() }
            .sheet(isPresented:$editing,onDismiss: { Task { await load() } }) {
                if let profile { NavigationStack { ProfileEditScreen(profile:profile) } }
            }
            .sheet(isPresented:$showSocial) { NavigationStack { ProfileSocialScreen(id:id) } }
            .sheet(isPresented:$newPost,onDismiss: { Task { await loadBlog() } }) { NavigationStack { ProfileArticleComposer() } }
            .alert(OriginalCopy.text("information"),isPresented:Binding(get:{ message != nil },set:{ if !$0 { message = nil } })) {
                Button(OriginalCopy.text("understand"),role:.cancel) { message = nil }
            } message: { Text(message ?? "") }
    }
    private func header(_ p: Profile) -> some View {
        VStack(spacing:0) {
            GeometryReader { geometry in
                if let cover = blog?.cover.flatMap(URL.init(string:)) { Poster(url:cover,width:geometry.size.width,height:174) }
                else { Rectangle().fill(Color.accentColor.opacity(0.2)) }
            }.frame(height:174)
            VStack(spacing:12) {
                ZStack(alignment:.bottomTrailing) {
                    Poster(url:p.avatar.flatMap(URL.init(string:)),width:96,height:96)
                        .clipShape(Circle()).padding(6).background(background,in:Circle())
                    if p.isOnline == true { Circle().fill(.green).frame(width:18,height:18).overlay(Circle().stroke(background,lineWidth:3)).padding(8) }
                }.padding(.top,-62)
                HStack(spacing:6) {
                    Text(p.login ?? "Пользователь").font(.system(size:20,weight:.semibold))
                    if p.isVerified == true { Image(systemName:"checkmark.seal.fill").foregroundStyle(.blue).accessibilityLabel(OriginalCopy.text("tooltip_profile_verified")) }
                    if let badge = p.badge { ProfileBadgeImage(badge:badge,size:24) }
                }.accessibilityIdentifier("profileHeaderName")
                if let status = p.status, !status.isEmpty { Text(status).font(.system(size:15)).multilineTextAlignment(.center).lineLimit(4).textSelection(.enabled) }
                if let score = p.ratingScore {
                    Button { message = OriginalCopy.text("tooltip_profile_rating_score") } label: {
                        Label(score.formatted(),systemImage:"star.fill").font(.subheadline).foregroundStyle(.secondary)
                    }.buttonStyle(.plain).accessibilityLabel("Репутация: \(score)")
                }
                VStack(spacing:5) {
                    if p.isOnline == true { Text("В сети").foregroundStyle(.green) }
                    else if let time = p.lastActivityTime, time > 0 { Text("был(а) в сети \(ProfileDate.text(time))") }
                    if let date = p.registerDate, date > 0 { Text("на проекте с \(ProfileDate.day(date))") }
                }.font(.footnote).foregroundStyle(.secondary)
                if let roles = p.roles, !roles.isEmpty {
                    ViewThatFits {
                        HStack { ForEach(roles) { role in roleLabel(role) } }
                        VStack { ForEach(roles) { role in roleLabel(role) } }
                    }
                }
                banners(p)
                HStack(spacing:12) {
                    if own { Button(OriginalCopy.text("edit")) { editing = true }.buttonStyle(.bordered).frame(maxWidth:.infinity) }
                    else if session.token != nil, p.isDeleted != true {
                        Button(friendTitle(p)) { Task { await friendship(p) } }.buttonStyle(.bordered).disabled(loading || p.isFriendRequestsDisallowed == true && p.friendStatus == nil)
                        Button { showSocial = true } label: { Image(systemName:"message") }.buttonStyle(.bordered).accessibilityLabel("Связаться")
                    }
                    Menu {
                        ShareLink(item:URL(string:"https://anixart.tv/profile/\(id)")!) { Label("Поделиться профилем",systemImage:"square.and.arrow.up") }
                        Button("Скопировать ID") { UIPasteboard.general.string = String(id) }
                        NavigationLink("История логина") { ProfileLoginHistoryScreen(id:id) }
                        if own { Button("Выйти",role:.destructive) { session.signOut() } }
                    } label: { Image(systemName:"ellipsis").frame(width:40,height:40) }.accessibilityLabel("Ещё")
                }
                if p.isSocialHidden != true {
                    ProfileSocialLinks(profile:p,own:own) { editing = true }
                }
                if p.isCountsHidden != true, let friendCount = p.friendCount {
                NavigationLink { ProfilePeopleScreen(id:id,own:own) } label: {
                    HStack(spacing:12) {
                        HStack(spacing:-12) {
                            ForEach(Array((p.friendsPreview ?? []).prefix(3))) { friend in
                                Poster(url:friend.avatar.flatMap(URL.init(string:)),width:32,height:32).clipShape(Circle()).overlay(Circle().stroke(background,lineWidth:2))
                            }
                        }
                        Text(friendCount > 0 ? "Друзья · \(friendCount)" : OriginalCopy.text("friends_zero"))
                        Spacer(); Image(systemName:"chevron.right").font(.caption)
                    }.font(.subheadline).foregroundStyle(.secondary).padding(.vertical,10).contentShape(Rectangle())
                }.buttonStyle(.plain).accessibilityIdentifier("profileFriends")
                }
            }.padding(.horizontal,20).padding(.bottom,12)
                .background(background,in:UnevenRoundedRectangle(topLeadingRadius:32,topTrailingRadius:32)).padding(.top,-16)
        }
    }
    private func roleLabel(_ role: ProfileRole) -> some View {
        Text(role.name ?? "").font(.caption.bold()).foregroundStyle(Color(profileHex:role.color) ?? .accentColor)
            .padding(.horizontal,10).padding(.vertical,5).background((Color(profileHex:role.color) ?? .accentColor).opacity(0.15),in:Capsule())
    }
    @ViewBuilder private func banners(_ p: Profile) -> some View {
        if p.isDeleted == true { Label(OriginalCopy.text("profile_deleted"),systemImage:"person.crop.circle.badge.xmark").foregroundStyle(.secondary) }
        if p.isBanned == true {
            VStack(spacing:5) { Text(p.isPermBanned == true ? OriginalCopy.text("profile_perm_banned") : "Заблокирован(а) до \(ProfileDate.day(p.banExpires ?? 0))"); if let reason = p.banReason { Text(reason) } }.font(.footnote).foregroundStyle(.red)
        }
        if p.isIncognito == true { Label(OriginalCopy.text("profile_incognito_hint"),systemImage:"eye.slash").font(.footnote) }
        if p.isBlocked == true || p.isMeBlocked == true { Text(OriginalCopy.text("profile_block_hint")).font(.footnote).foregroundStyle(.secondary) }
        if p.isDeletionRequested == true { Text(OriginalCopy.text("account_deletion_requested_success")).font(.footnote).foregroundStyle(.orange) }
    }
    private func showcase(_ p: Profile) -> some View {
        VStack(alignment:.leading,spacing:20) {
            ScrollView(.horizontal) {
                HStack(spacing:8) {
                    ForEach(ProfileSection.visible(in:p)) { item in
                        Button { section = item } label: {
                            HStack(spacing:5) { Text(item.title); if let n = item.count(p), n > 0 { Text(n.formatted()).opacity(0.7) } }
                                .font(.subheadline.weight(.medium)).padding(.horizontal,16).padding(.vertical,10)
                                .background(section == item ? Color.accentColor.opacity(0.22) : Color.primary.opacity(0.06),in:Capsule())
                                .overlay(Capsule().stroke(section == item ? Color.accentColor : .clear))
                        }.buttonStyle(.plain).accessibilityIdentifier("profile.section.\(item.rawValue)")
                    }
                }.padding(.horizontal,20)
            }.scrollIndicators(.hidden).accessibilityIdentifier("profileSections")
            VStack(alignment:.leading,spacing:12) {
                switch section {
                case .statistics: ProfileStatistics(profile:p)
                case .votes:
                    if (p.votes ?? []).isEmpty { empty() }
                    ForEach(p.votes ?? []) { release in
                        NavigationLink { ReleaseScreen(initial:release) } label: { ProfileVoteRow(release:release) }.buttonStyle(.plain)
                    }
                case .collections:
                    if (p.collectionsPreview ?? []).isEmpty { empty() }
                    ForEach(p.collectionsPreview ?? []) { ProfileCollectionRow(collection:$0) }
                case .comments:
                    if (p.commentsPreview ?? []).isEmpty { empty() }
                    ForEach(p.commentsPreview ?? []) { ProfileCommentCard(comment:$0) }
                case .videos:
                    if (p.releaseVideosPreview ?? []).isEmpty { empty() }
                    ForEach(p.releaseVideosPreview ?? []) { ProfileVideoRow(video:$0) }
                case .badges:
                    if (p.badgesPreview ?? []).isEmpty { empty() }
                    else { ProfileBadgeGrid(badges:p.badgesPreview ?? [],own:own) }
                }
                if section != .statistics {
                    NavigationLink { ProfileSectionScreen(profile:p,section:section) } label: {
                        Text(OriginalCopy.text("show_more")).font(.footnote).frame(maxWidth:.infinity,minHeight:44).contentShape(Rectangle())
                    }.accessibilityIdentifier("profile.section.more")
                }
            }.padding(.horizontal,20)
        }.padding(.vertical,16).background { ProfileShowcaseBackground(profile:p) }
    }
    private func empty() -> some View { Text("Здесь пока ничего нет").font(.subheadline).foregroundStyle(.secondary).frame(maxWidth:.infinity,minHeight:100) }
    private func historySection(_ releases: [Release]) -> some View {
        VStack(alignment:.leading,spacing:16) {
            Divider()
            Text(OriginalCopy.text("profile_history")).font(.headline).padding(.horizontal,20)
            ScrollView(.horizontal) {
                HStack(alignment:.top,spacing:16) {
                    ForEach(releases) { release in
                        NavigationLink { ReleaseScreen(initial:release) } label: {
                            VStack(alignment:.leading,spacing:6) {
                                Poster(url:release.poster)
                                Text(release.title).font(.caption.weight(.medium)).lineLimit(2)
                                if let episode = release.lastViewEpisode?.name { Text(episode).font(.caption2).foregroundStyle(.secondary) }
                                if let date = release.lastViewTimestamp { Text(ProfileDate.text(date)).font(.caption2).foregroundStyle(.secondary) }
                            }.frame(width:104,alignment:.leading)
                        }.buttonStyle(.plain)
                    }
                }.padding(.horizontal,20)
            }.scrollIndicators(.hidden)
        }.padding(.bottom,24).accessibilityIdentifier("profileRecentHistory")
    }
    private func friendTitle(_ p: Profile) -> String {
        OriginalCopy.text(p.friendStatus == 2 ? "profile_del_friend" : p.friendStatus == 0 ? "profile_friend_request_sent" : p.friendStatus == 1 ? "profile_friend_request_accept" : "profile_add_friend")
    }
    private func friendship(_ p: Profile) async {
        guard let token = session.token else { return }
        do { try await repository.friend(id,action:p.friendStatus == 2 || p.friendStatus == 0 ? "remove" : "send",token:token); await load() }
        catch { message = error.localizedDescription }
    }
    private func load() async {
        let requestGeneration = UUID(); generation = requestGeneration
        loading = true; error = nil
        defer { if generation == requestGeneration { loading = false } }
        do {
            let next = try await repository.profile(id,token:session.token); try Task.checkCancellation()
            guard generation == requestGeneration else { return }
            let chooseInitial = profile == nil || profile?.pinnedSectionId != next.pinnedSectionId || !ProfileSection.visible(in:next).contains(section)
            profile = next
            if chooseInitial, let initial = ProfileSection.visible(in:next).first { section = initial }
            await loadBlog()
        } catch is CancellationError { }
        catch let e as URLError where e.code == .cancelled { }
        catch { if generation == requestGeneration { self.error = error.localizedDescription } }
    }
    private func loadBlog() async {
        let identity = session.identity, profileID = id, requestGeneration = generation
        blogError = nil
        do { let next = try await repository.profileBlog(profileID,token:session.token); try Task.checkCancellation(); guard identity == session.identity, profile?.id == profileID, generation == requestGeneration else { return }; blog = next }
        catch is CancellationError { }
        catch let e as URLError where e.code == .cancelled { }
        catch { if identity == session.identity, profile?.id == profileID, generation == requestGeneration { blogError = error.localizedDescription } }
    }
}

enum ProfileDate {
    static func day(_ timestamp: Int64) -> String { Date(timeIntervalSince1970:Double(timestamp)).formatted(.dateTime.locale(Locale(identifier:"ru_RU")).day().month(.wide).year()) }
    static func text(_ timestamp: Int64) -> String { Date(timeIntervalSince1970:Double(timestamp)).formatted(.relative(presentation:.named,unitsStyle:.wide).locale(Locale(identifier:"ru_RU"))) }
}
extension Color {
    init?(profileHex value: String?) {
        guard var text = value?.trimmingCharacters(in:.whitespacesAndNewlines), !text.isEmpty else { return nil }
        text = text.replacingOccurrences(of:"#",with:"")
        guard let hex = UInt64(text,radix:16), text.count == 6 || text.count == 8 else { return nil }
        self.init(.sRGB,red:Double((hex >> 16) & 255)/255,green:Double((hex >> 8) & 255)/255,blue:Double(hex & 255)/255,opacity:text.count == 8 ? Double((hex >> 24) & 255)/255 : 1)
    }
}
struct ProfileShowcaseBackground: View {
    let profile: Profile
    private var colors: [Color] { [Color(profileHex:profile.themeGradientStartColor) ?? .clear,Color(profileHex:profile.themeGradientEndColor) ?? .clear] }
    private var points: (UnitPoint,UnitPoint) {
        switch profile.themeGradientAngle?.lowercased() {
        case "left_to_right": (.leading,.trailing)
        case "bottom_to_top": (.bottom,.top)
        case "diagonal_tl_br": (.topLeading,.bottomTrailing)
        case "diagonal_tr_bl": (.topTrailing,.bottomLeading)
        default: (.top,.bottom)
        }
    }
    var body: some View {
        if profile.themeEnabled == true {
            Group {
                if profile.themeGradientAngle?.lowercased() == "radial_from_center" {
                    GeometryReader { g in RadialGradient(colors:colors,center:.center,startRadius:0,endRadius:hypot(g.size.width / 2,g.size.height / 2) * 0.8) }
                } else { LinearGradient(colors:colors,startPoint:points.0,endPoint:points.1) }
            }
                .overlay {
                    if let url = profile.themeBackgroundUrl.flatMap(URL.init(string:)) {
                        GeometryReader { g in Poster(url:url,width:g.size.width,height:g.size.height).opacity(profile.themeBackgroundAlpha ?? 0.2) }.clipped()
                    }
                }
        }
    }
}
