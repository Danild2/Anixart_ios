import SwiftUI
import PhotosUI

struct ProfileEditScreen: View {
    let profile: Profile
    @Environment(\.repository) private var repository
    @Environment(SessionStore.self) private var session
    @Environment(\.dismiss) private var dismiss
    @State private var status = ""
    @State private var pinned = 0
    @State private var social = ProfileSocialEdit(vkPage:"",tgPage:"",instPage:"",ttPage:"",discordPage:"")
    @State private var loadedSocial: ProfileSocialEdit?
    @State private var preferences: ProfilePreferences?
    @State private var privacyStats = 0
    @State private var privacyCounts = 0
    @State private var privacySocial = 0
    @State private var privacyFriends = 0
    @State private var incognito = false
    @State private var theme: Int64 = 1
    @State private var photo: PhotosPickerItem?
    @State private var avatar: Data?
    @State private var removeAvatar = false
    @State private var error: String?
    @State private var busy = false
    var body: some View {
        Form {
            Section("Аватар") {
                HStack(spacing:20) {
                    if let avatar, let image = UIImage(data:avatar) { Image(uiImage:image).resizable().scaledToFill().frame(width:72,height:72).clipShape(Circle()) }
                    else { Poster(url:removeAvatar ? nil : profile.avatar.flatMap(URL.init(string:)),width:72,height:72).clipShape(Circle()) }
                    PhotosPicker("Изменить аватар",selection:$photo,matching:.images).disabled(preferences?.isChangeAvatarBanned == true)
                }
                Button("Удалить аватар",role:.destructive) { removeAvatar = true; avatar = nil }.disabled(preferences?.isChangeAvatarBanned == true)
            }
            Section("Статус") { TextField("Расскажите о себе",text:$status,axis:.vertical).lineLimit(2...4) }
            Section(OriginalCopy.text("profile_pinned_section_title")) {
                Picker("Секция профиля",selection:$pinned) { ForEach(ProfileSection.allCases) { Text($0.title).tag($0.rawValue) } }
            }
            Section("Социальные сети") {
                TextField("ВКонтакте",text:$social.vkPage)
                TextField("Telegram",text:$social.tgPage)
                TextField("Discord",text:$social.discordPage)
                TextField("TikTok",text:$social.ttPage)
                TextField("Instagram",text:$social.instPage)
            }.textInputAutocapitalization(.never).autocorrectionDisabled()
            if let preferences {
                Section {
                    Picker(OriginalCopy.text("profile_theme_title"),selection:$theme) { ForEach(preferences.availableThemes ?? []) { Text($0.name).tag($0.id) } }
                } footer: { Text(OriginalCopy.text("profile_theme_summary")) }
                Section(OriginalCopy.text("privacy")) {
                    privacyPicker("preference_privacy_stats",selection:$privacyStats)
                    privacyPicker("preference_privacy_counts",selection:$privacyCounts)
                    privacyPicker("preference_privacy_social",selection:$privacySocial)
                    Picker(OriginalCopy.text("preference_privacy_friend_requests"),selection:$privacyFriends) {
                        Text("Все пользователи").tag(0); Text("Никто").tag(1)
                    }
                    Toggle(OriginalCopy.text("pref_incognito_title"),isOn:$incognito)
                    Text(OriginalCopy.text("pref_incognito_summary")).font(.caption).foregroundStyle(.secondary)
                }
            }
            if let error { Text(error).foregroundStyle(.red) }
            if busy { ProgressView() }
        }.navigationTitle(OriginalCopy.text("profile_settings"))
            .toolbar { ToolbarItem(placement:.cancellationAction) { Button("Закрыть") { dismiss() } }; ToolbarItem(placement:.confirmationAction) { Button("Сохранить") { Task { await save() } }.disabled(busy || loadedSocial == nil || preferences == nil) } }
            .task {
                status = profile.status ?? ""; pinned = profile.pinnedSectionId ?? 0
                do {
                    let response = try await repository.profileSocial(profile.id,token:session.token)
                    social = ProfileSocialEdit(vkPage:response.vkPage ?? "",tgPage:response.tgPage ?? "",instPage:response.instPage ?? "",ttPage:response.ttPage ?? "",discordPage:response.discordPage ?? "")
                    loadedSocial = social
                    if let token = session.token {
                        let next = try await repository.profilePreferences(token:token); preferences = next
                        privacyStats = next.privacyStats ?? 0; privacyCounts = next.privacyCounts ?? 0
                        privacySocial = next.privacySocial ?? 0; privacyFriends = next.privacyFriendRequests ?? 0
                        incognito = next.isIncognito == true; theme = next.selectedThemeId ?? 1
                    }
                } catch { self.error = error.localizedDescription }
            }
            .onChange(of:photo) { _, next in
                Task {
                    do {
                        guard let data = try await next?.loadTransferable(type:Data.self), data.count <= 30_000_000,
                              let image = UIImage(data:data) else { throw APIError.malformed }
                        let scale = min(1,1024 / max(image.size.width,image.size.height))
                        let size = CGSize(width:image.size.width * scale,height:image.size.height * scale)
                        let renderer = UIGraphicsImageRenderer(size:size)
                        avatar = renderer.jpegData(withCompressionQuality:0.88) { _ in image.draw(in:CGRect(origin:.zero,size:size)) }
                        removeAvatar = false
                    } catch { self.error = error.localizedDescription }
                }
            }
    }
    private func privacyPicker(_ key: String,selection: Binding<Int>) -> some View {
        Picker(OriginalCopy.text(key),selection:selection) { Text("Все пользователи").tag(0); Text("Только друзья").tag(1); Text("Только я").tag(2) }
    }
    private func save() async {
        guard let token = session.token else { return }; busy = true; error = nil; defer { busy = false }
        do {
            if status != (profile.status ?? "") { try await repository.editProfileStatus(status,token:token) }
            if pinned != (profile.pinnedSectionId ?? 0) { try await repository.pinProfileSection(pinned,token:token) }
            if social != loadedSocial { try await repository.editProfileSocial(social,token:token) }
            if let p = preferences {
                if let old = p.privacyStats, privacyStats != old { try await repository.editProfilePrivacy("stats",permission:privacyStats,token:token) }
                if let old = p.privacyCounts, privacyCounts != old { try await repository.editProfilePrivacy("counts",permission:privacyCounts,token:token) }
                if let old = p.privacySocial, privacySocial != old { try await repository.editProfilePrivacy("social",permission:privacySocial,token:token) }
                if let old = p.privacyFriendRequests, privacyFriends != old { try await repository.editProfilePrivacy("friendRequests",permission:privacyFriends,token:token) }
                if incognito != (p.isIncognito == true) {
                    try await repository.toggleProfileIncognito(token:token)
                    // The endpoint toggles state. A later failed save operation
                    // must not cause a manual retry to toggle it back.
                    preferences?.isIncognito = incognito
                }
                if let old = p.selectedThemeId, theme != old { try await repository.selectProfileTheme(theme,token:token) }
            }
            if removeAvatar || avatar != nil { try await repository.editProfileAvatar(avatar,token:token) }
            await session.refresh(repository:repository); dismiss()
        } catch { self.error = error.localizedDescription }
    }
}
struct ProfileSocialScreen: View {
    let id: Int64
    @Environment(\.repository) private var repository
    @Environment(SessionStore.self) private var session
    @Environment(\.dismiss) private var dismiss
    @State private var result: ProfileSocialResponse?
    @State private var error: String?
    var body: some View {
        List {
            if session.token == nil { NavigationLink("Войдите, чтобы увидеть социальные сети") { SignInScreen() } }
            else {
            if let error { FailureNotice(message:error) { Task { await load() } } }
            if let result {
                social("ВКонтакте",value:result.vkPage,base:"https://vk.com/")
                social("Telegram",value:result.tgPage,base:"https://t.me/")
                social("Discord",value:result.discordPage,base:"https://discord.com/users/")
                social("TikTok",value:result.ttPage,base:"https://www.tiktok.com/@")
                social("Instagram",value:result.instPage,base:"https://www.instagram.com/")
                if [result.vkPage,result.tgPage,result.discordPage,result.ttPage,result.instPage].allSatisfy({ $0?.isEmpty != false }) { Text("Социальные сети не указаны или скрыты").foregroundStyle(.secondary) }
            } else if error == nil { ProgressView() }
            }
        }.navigationTitle("Социальные сети").toolbar { Button("Закрыть") { dismiss() } }.task { await load() }
    }
    @ViewBuilder private func social(_ title: String,value: String?,base: String) -> some View {
        if let value, !value.isEmpty, let url = URL(string:value.hasPrefix("https://") || value.hasPrefix("http://") ? value : base + value.trimmingCharacters(in:CharacterSet(charactersIn:"@/ "))), ["http","https"].contains(url.scheme ?? "") {
            Link(destination:url) { LabeledContent(title,value:value) }
        }
    }
    private func load() async {
        guard session.token != nil else { return }
        error = nil
        do { let next = try await repository.profileSocial(id,token:session.token); try Task.checkCancellation(); result = next }
        catch is CancellationError { }
        catch { self.error = error.localizedDescription }
    }
}

struct ProfileSocialLinks: View {
    let profile: Profile
    let own: Bool
    let edit: () -> Void
    @Environment(\.repository) private var repository
    @Environment(SessionStore.self) private var session
    @State private var social: ProfileSocialResponse?
    var body: some View {
        HStack(spacing:12) {
            link("ВКонтакте",icon:"vk",raw:social?.vkPage ?? profile.vkPage,base:"https://vk.com/",color:Color(red:0,green:119/255,blue:1))
            link("Telegram",icon:"telegram",raw:social?.tgPage ?? profile.tgPage,base:"https://t.me/",color:Color(red:0,green:136/255,blue:204/255))
            link("Discord",icon:"discord",raw:social?.discordPage ?? profile.discordPage,base:"https://discord.com/users/",color:Color(red:88/255,green:101/255,blue:242/255))
            link("TikTok",icon:"tiktok",raw:social?.ttPage ?? profile.ttPage,base:"https://www.tiktok.com/@",color:.primary)
            if own { Button(action:edit) { Image(systemName:"plus").frame(width:44,height:36).overlay(RoundedRectangle(cornerRadius:12).stroke(.secondary,lineWidth:1.5)) }.accessibilityLabel("Добавить социальную сеть") }
        }.frame(maxWidth:.infinity).task(id:session.identity) {
            guard session.token != nil else { return }
            social = try? await repository.profileSocial(profile.id,token:session.token)
        }
    }
    @ViewBuilder private func link(_ name: String,icon: String,raw: String?,base: String,color: Color) -> some View {
        if let raw, !raw.isEmpty, let url = URL(string:raw.hasPrefix("https://") || raw.hasPrefix("http://") ? raw : base + raw.trimmingCharacters(in:CharacterSet(charactersIn:"@/ "))), ["https","http"].contains(url.scheme ?? "") {
            Link(destination:url) {
                Image("original_\(icon)").renderingMode(icon == "tiktok" ? .template : .original).resizable().scaledToFit().frame(width:24,height:24)
                    .foregroundStyle(color).frame(width:56,height:36).overlay(RoundedRectangle(cornerRadius:12).stroke(color,lineWidth:1.5))
            }.accessibilityLabel(name)
        }
    }
}
