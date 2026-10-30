import SwiftUI

struct SignInScreen: View {
    @Environment(SessionStore.self) private var session
    @Environment(\.repository) private var repository
    @State private var login = ""
    @State private var password = ""
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
            Section { Text("Регистрация, восстановление пароля и вход через социальные сети пока не перенесены.").foregroundStyle(.secondary) }
        }.navigationTitle("Вход").onDisappear { password = "" }
    }
    private func signIn() {
        focus = false
        Task {
            await session.signIn(login: login.trimmingCharacters(in: .whitespaces), password: password, repository: repository)
            password = ""
        }
    }
}

struct ProfileScreen: View {
    @Environment(SessionStore.self) private var session
    @Environment(\.repository) private var repository
    var body: some View {
        List {
            if let profile = session.session?.profile {
                Section {
                    HStack {
                        Poster(url: profile.avatar.flatMap(URL.init(string:)), width: 64, height: 64)
                        VStack(alignment: .leading) { Text(profile.login ?? "Профиль").font(.title2); if let status = profile.status { Text(status).foregroundStyle(.secondary) } }
                    }
                }
                NavigationLink("История просмотра") { CatalogScreen(title: "История", feed: .library("history")) }
                if let error = session.error { Text(error).foregroundStyle(.red) }
                Button("Обновить профиль") { Task { await session.refresh(repository: repository) } }
                Button("Выйти", role: .destructive) { session.signOut() }
            } else {
                NavigationLink("Войти в аккаунт") { SignInScreen() }
            }
            NavigationLink("Настройки", destination: SettingsScreen())
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
            Section("О переносе") {
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
