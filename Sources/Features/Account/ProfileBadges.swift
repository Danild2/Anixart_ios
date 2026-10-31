import SwiftUI

struct ProfileBadgeImage: View {
    let badge: ProfileBadge
    var size: CGFloat
    var body: some View { Poster(url:badge.thumbnail,width:size,height:size) }
}
struct ProfileBadgeGrid: View {
    let badges: [ProfileBadge]
    var own = false
    var body: some View {
        LazyVGrid(columns:[GridItem(.adaptive(minimum:72))],spacing:20) {
            ForEach(badges) { badge in
                NavigationLink { ProfileBadgeDetail(badge:badge,own:own) } label: {
                    VStack(spacing:8) {
                        ProfileBadgeImage(badge:badge,size:64)
                        Text(badge.name ?? "Значок").font(.caption).multilineTextAlignment(.center).lineLimit(2)
                        if badge.isSelected == true { Image(systemName:"checkmark.circle.fill").font(.caption).foregroundStyle(Color.accentColor) }
                    }.foregroundStyle(.primary)
                }.buttonStyle(.plain)
            }
        }
    }
}
struct ProfileBadgesScreen: View {
    let id: Int64
    @Environment(\.repository) private var repository
    @Environment(SessionStore.self) private var session
    @State private var result: ProfileBadgesResponse?
    @State private var error: String?
    private var own: Bool { session.session?.profile.id == id }
    var body: some View {
        ScrollView {
            VStack(alignment:.leading,spacing:24) {
                if let error { FailureNotice(message:error) { Task { await load() } } }
                if let result {
                    if let showcased = result.showcased, !showcased.isEmpty {
                        HStack { Text("Витрина значков").font(.headline); Spacer(); if own { NavigationLink("Порядок") { ProfileBadgeOrderScreen(badges:showcased) } } }
                        ProfileBadgeGrid(badges:showcased,own:own)
                    }
                    if let recent = result.recent, !recent.isEmpty { Text("Недавно получены").font(.headline); ProfileBadgeGrid(badges:recent,own:own) }
                    ForEach(result.sections ?? []) { section in
                        HStack {
                            Text(section.title ?? "Значки").font(.headline)
                            Spacer()
                            if let count = section.count { Text(count.formatted()).foregroundStyle(.secondary) }
                        }
                        ProfileBadgeGrid(badges:section.content ?? [],own:own)
                        NavigationLink(OriginalCopy.text("show_more")) {
                            RemoteProfileList(title:section.title ?? "Значки",path:"profile/\(id)/badge/list/\(section.id)") { (badge: ProfileBadge) in
                                NavigationLink { ProfileBadgeDetail(badge:badge,own:own) } label: {
                                    HStack(spacing:16) { ProfileBadgeImage(badge:badge,size:64); Text(badge.name ?? "Значок") }
                                }
                            }
                        }
                    }
                    if (result.sections ?? []).isEmpty && (result.showcased ?? []).isEmpty { Text(OriginalCopy.text("profile_badge_empty_title")).foregroundStyle(.secondary) }
                } else if error == nil { ProgressView() }
            }.padding(20)
        }.navigationTitle(OriginalCopy.text("profile_badges")).task(id:session.identity) { await load() }.refreshable { await load() }
    }
    private func load() async {
        error = nil
        do { let next = try await repository.profileBadges(id,token:session.token); try Task.checkCancellation(); result = next }
        catch is CancellationError { }
        catch { self.error = error.localizedDescription }
    }
}

struct ProfileBadgeOrderScreen: View {
    @State var badges: [ProfileBadge]
    @Environment(\.repository) private var repository
    @Environment(SessionStore.self) private var session
    @Environment(\.dismiss) private var dismiss
    @State private var busy = false
    @State private var error: String?
    var body: some View {
        List {
            ForEach(badges) { badge in HStack(spacing:16) { ProfileBadgeImage(badge:badge,size:48); Text(badge.name ?? "Значок") } }
                .onMove { source,destination in badges.move(fromOffsets:source,toOffset:destination) }
            if let error { Text(error).foregroundStyle(.red) }
        }.environment(\.editMode,.constant(.active)).navigationTitle("Витрина значков")
            .toolbar { Button("Сохранить") { Task { await save() } }.disabled(busy) }
    }
    private func save() async {
        guard let token = session.token else { return }; busy = true; error = nil; defer { busy = false }
        struct Body: Encodable { let ids: [Int64] }
        do {
            let _: Acknowledgement = try await repository.client.request(Endpoint(path:"profile/preference/badge/showcase/reorder",method:"POST",body:JSONEncoder().encode(Body(ids:badges.map(\.id))),isReadOnly:false),token:token)
            dismiss()
        } catch { self.error = error.localizedDescription }
    }
}
struct ProfileBadgeDetail: View {
    let badge: ProfileBadge
    let own: Bool
    @Environment(\.repository) private var repository
    @Environment(SessionStore.self) private var session
    @State private var error: String?
    @State private var busy = false
    @State private var selected = false
    @State private var showcased = false
    var body: some View {
        ScrollView {
            VStack(spacing:20) {
                ProfileBadgeImage(badge:badge,size:180)
                Text(badge.name ?? "Значок").font(.title2.bold())
                if let description = badge.description { Text(description).multilineTextAlignment(.center).textSelection(.enabled) }
                if let rarity = badge.rarity { Text(rarity).font(.subheadline).foregroundStyle(.secondary) }
                if let percent = badge.ownershipPercentage { Text("Есть у \(percent.formatted(.number.precision(.fractionLength(0...2))))% пользователей").font(.footnote).foregroundStyle(.secondary) }
                if let date = badge.timestamp, date > 0 { Text("Получен \(ProfileDate.day(date))").font(.footnote).foregroundStyle(.secondary) }
                if let error { Text(error).foregroundStyle(.red) }
                if own, badge.isOwned == true {
                    Button(selected ? "Убрать из профиля" : "Установить в профиль") { Task { await mutate(showcase:false) } }.buttonStyle(.borderedProminent).disabled(busy)
                    Button(showcased ? "Убрать с витрины" : "Добавить на витрину") { Task { await mutate(showcase:true) } }.buttonStyle(.bordered).disabled(busy)
                }
                if busy { ProgressView() }
            }.padding(24).frame(maxWidth:.infinity)
        }.navigationTitle("О значке").task { selected = badge.isSelected == true; showcased = badge.isShowcased == true }
    }
    private func mutate(showcase: Bool) async {
        guard let token = session.token else { return }; busy = true; error = nil; defer { busy = false }
        let path = showcase ? "profile/preference/badge/showcase/\(showcased ? "unpin" : "pin")/\(badge.id)" : "profile/preference/badge/\(selected ? "remove" : "edit/\(badge.id)")"
        do {
            let _: Acknowledgement = try await repository.client.request(Endpoint(path:path,method:showcase ? "POST" : "GET",isReadOnly:false),token:token)
            if showcase { showcased.toggle() } else { selected.toggle() }
        } catch { self.error = error.localizedDescription }
    }
}
