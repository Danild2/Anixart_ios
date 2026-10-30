import SwiftUI
import Combine

@main struct AnixartApp: App {
    @State private var session = SessionStore()
    @State private var settings = AppSettings()
    @State private var externalPlayback = ExternalPlayback()
    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(session).environment(settings).environment(externalPlayback)
                .environment(\.repository, AnixartRepository(client: APIClient(baseURL: settings.useRegionalAPI ? APIClient.regionalURL : APIClient.primaryURL)))
                .preferredColorScheme(settings.darkMode ? .dark : .light)
                .tint(settings.darkMode ? Design.darkAccent : Design.accent)
                .onReceive(NotificationCenter.default.publisher(for: .sessionUnauthorized).receive(on: DispatchQueue.main)) { notification in
                    if let token = notification.object as? String { session.invalidate(ifMatching: token) }
                }
                .onOpenURL { url in externalPlayback.handleCallback(url) }
                .onChange(of: session.identity) { _, _ in externalPlayback.reset() }
        }
    }
}
