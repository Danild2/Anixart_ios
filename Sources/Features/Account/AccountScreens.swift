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
                Text("Функции и источники ещё требуют проверки с доступным сервером и на iPhone. Лента, каналы, друзья, уведомления и часть настроек оригинала пока не перенесены.").foregroundStyle(.secondary)
                Text("Bundle ID: local.anixartport.client").font(.caption)
            }
        }.navigationTitle("Настройки")
    }
}

struct FeedScreen: View {
    var body: some View {
        ContentUnavailableView("Лента пока не перенесена", systemImage: "text.bubble",
            description: Text("В APK обнаружены статьи, каналы и блочный редактор. Отображение всех типов блоков и социальные действия ещё не реализованы."))
            .navigationTitle("Лента")
    }
}
