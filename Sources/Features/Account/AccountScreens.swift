import SwiftUI

struct SignInScreen: View {
    @Environment(SessionStore.self) private var session
    @Environment(\.repository) private var repository
    @State private var login = ""
    @State private var password = ""
    @State private var request: Task<Void, Never>?
    @FocusState private var focus: Bool
    var body: some View {
        Form {
            Section {
                TextField("Логин или email", text: $login).textContentType(.username)
                    .textInputAutocapitalization(.never).autocorrectionDisabled()
                SecureField("Пароль", text: $password).textContentType(.password).focused($focus)
                    .onSubmit { signIn() }
            } header: { Text("Вход в Anixart") } footer: { Text("Данные отправляются напрямую официальному серверу Anixart по HTTPS. Пароль не сохраняется.") }
            if let error = session.error { Text(error).foregroundStyle(.red).accessibilityIdentifier("loginError") }
            Button(action: signIn) {
                HStack { Text("Войти"); Spacer(); if session.busy { ProgressView() } }
            }.disabled(login.trimmingCharacters(in: .whitespaces).isEmpty || password.isEmpty || session.busy)
            Section {
                NavigationLink(OriginalCopy.text("auth_register_action")) { AccountAccessScreen(mode: .registration) }
                NavigationLink(OriginalCopy.text("auth_forgot_password_question")) { AccountAccessScreen(mode: .restore) }
            }
        }.navigationTitle("Вход").onDisappear { request?.cancel(); password = "" }
    }
    private func signIn() {
        focus = false
        request = Task {
            await session.signIn(login: login.trimmingCharacters(in: .whitespaces), password: password, repository: repository)
            password = ""
        }
    }
}

struct ProfileScreen: View {
    @Environment(SessionStore.self) private var session
    @Environment(\.repository) private var repository
    var body: some View {
        Group {
            if let profile = session.session?.profile { FullProfileScreen(id:profile.id) }
            else if let id = ProfilePreviewLaunch.id { FullProfileScreen(id:id) }
            else { List {
                NavigationLink("Войти в аккаунт") { SignInScreen() }
                NavigationLink("Настройки", destination: SettingsScreen())
            } }
        }.navigationTitle("Профиль")
    }
}

struct SettingsScreen: View {
    @Environment(AppSettings.self) private var settings
    var body: some View {
        @Bindable var settings = settings
        Form {
            Section("Оформление") {
                Picker("Тема", selection: $settings.theme) { ForEach(AppTheme.allCases) { Text($0.title).tag($0) } }
                Toggle("Тёмное оформление", isOn: $settings.darkMode)
            }
            Section("Подключение") {
                Toggle("Официальный RU-сервер", isOn: $settings.useRegionalAPI)
                Text(settings.useRegionalAPI ? "api.anixsekai.com" : "api-s.anixsekai.com").font(.caption).foregroundStyle(.secondary)
            }
            Section("Воспроизведение") {
                Picker("Плеер", selection: $settings.playbackMode) { ForEach(PlaybackMode.allCases) { Text($0.title).tag($0) } }
                Text("В первой версии медиапоток открывается в VLC. Историю серий ведёт Anixart; точная позиция внешнего воспроизведения управляется VLC.").font(.caption).foregroundStyle(.secondary)
            }
            Section("О переносе") {
                LabeledContent("Версия", value: "\(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—") (\(Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "—"))")
                Text("Неофициальный нативный клиент на основе исследования Anixart 10.5.")
                Text("Каталог, списки, история и статистика просмотров. Для воспроизведения используется VLC.").foregroundStyle(.secondary)
            }
        }.navigationTitle("Настройки")
    }
}

