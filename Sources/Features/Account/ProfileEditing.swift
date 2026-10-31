import SwiftUI

struct ProfileEditScreen: View {
    let profile: Profile
    @Environment(\.repository) private var repository
    @Environment(SessionStore.self) private var session
    @Environment(\.dismiss) private var dismiss
    @State private var status = ""
    @State private var pinned = 0
    @State private var social = ProfileSocialEdit(vkPage:"",tgPage:"",instPage:"",ttPage:"",discordPage:"")
    @State private var loadedSocial: ProfileSocialEdit?
    @State private var error: String?
    @State private var busy = false
    var body: some View {
        Form {
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
            if let error { Text(error).foregroundStyle(.red) }
            if busy { ProgressView() }
        }.navigationTitle(OriginalCopy.text("profile_settings"))
            .toolbar { ToolbarItem(placement:.cancellationAction) { Button("Закрыть") { dismiss() } }; ToolbarItem(placement:.confirmationAction) { Button("Сохранить") { Task { await save() } }.disabled(busy || loadedSocial == nil) } }
            .task {
                status = profile.status ?? ""; pinned = profile.pinnedSectionId ?? 0
                do {
                    let response = try await repository.profileSocial(profile.id,token:session.token)
                    social = ProfileSocialEdit(vkPage:response.vkPage ?? "",tgPage:response.tgPage ?? "",instPage:response.instPage ?? "",ttPage:response.ttPage ?? "",discordPage:response.discordPage ?? "")
                    loadedSocial = social
                } catch { self.error = error.localizedDescription }
            }
    }
    private func save() async {
        guard let token = session.token else { return }; busy = true; error = nil; defer { busy = false }
        do {
            if status != (profile.status ?? "") { try await repository.editProfileStatus(status,token:token) }
            if pinned != (profile.pinnedSectionId ?? 0) { try await repository.pinProfileSection(pinned,token:token) }
            if social != loadedSocial { try await repository.editProfileSocial(social,token:token) }
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
            if let error { FailureNotice(message:error) { Task { await load() } } }
            if let result {
                social("ВКонтакте",value:result.vkPage,base:"https://vk.com/")
                social("Telegram",value:result.tgPage,base:"https://t.me/")
                social("Discord",value:result.discordPage,base:"https://discord.com/users/")
                social("TikTok",value:result.ttPage,base:"https://www.tiktok.com/@")
                social("Instagram",value:result.instPage,base:"https://www.instagram.com/")
                if [result.vkPage,result.tgPage,result.discordPage,result.ttPage,result.instPage].allSatisfy({ $0?.isEmpty != false }) { Text("Социальные сети не указаны или скрыты").foregroundStyle(.secondary) }
            } else if error == nil { ProgressView() }
        }.navigationTitle("Социальные сети").toolbar { Button("Закрыть") { dismiss() } }.task { await load() }
    }
    @ViewBuilder private func social(_ title: String,value: String?,base: String) -> some View {
        if let value, !value.isEmpty, let url = URL(string:value.hasPrefix("https://") || value.hasPrefix("http://") ? value : base + value.trimmingCharacters(in:CharacterSet(charactersIn:"@/ "))), ["http","https"].contains(url.scheme ?? "") {
            Link(destination:url) { LabeledContent(title,value:value) }
        }
    }
    private func load() async {
        error = nil
        do { let next = try await repository.profileSocial(id,token:session.token); try Task.checkCancellation(); result = next }
        catch is CancellationError { }
        catch { self.error = error.localizedDescription }
    }
}
