import SwiftUI
import Observation

@MainActor @Observable final class NavigationChrome {
    var playbackVisible = false
}

private enum MainTab: Int, CaseIterable, Identifiable {
    case home, discover, bookmarks, feed, profile
    var id: Int { rawValue }
    var title: String {
        OriginalCopy.text(["home", "discover", "bookmarks", "feed", "profile"][rawValue])
    }
    var icon: String {
        switch self { case .home: "house"; case .discover: "safari"; case .bookmarks: "bookmark"; case .feed: "text.bubble"; case .profile: "person.crop.circle" }
    }
}

struct RootView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(SessionStore.self) private var session
    @State private var tab = MainTab.home
    @State private var chrome = NavigationChrome()
    var body: some View {
        TabView(selection: $tab) {
            ForEach(MainTab.allCases) { item in
                Tab(item.title, systemImage: item.icon, value: item) {
                  NavigationStack {
                    Group {
                        switch item {
                        case .home: HomeScreen()
                        case .discover: DiscoverScreen()
                        case .bookmarks: LibraryScreen()
                        case .feed: FeedScreen()
                        case .profile: ProfileScreen()
                        }
                    }
                    .navigationDestination(for: Release.self) { ReleaseScreen(initial: $0) }
                    .navigationBarTitleDisplayMode(.inline)
                  }
                  .toolbar(settings.theme == .original || chrome.playbackVisible ? .hidden : .visible, for: .tabBar)
                }
            }
        }
        .id(session.identity)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if settings.theme == .original && !chrome.playbackVisible {
                HStack(alignment: .top, spacing: 0) {
                    ForEach(MainTab.allCases) { item in
                        Button { tab = item } label: {
                            VStack(spacing: 4) {
                                Image(systemName: item.icon).font(.title3).frame(height: 28)
                                Text(item.title).font(.caption2)
                            }.frame(maxWidth: .infinity).padding(.vertical, 8)
                        }
                        .buttonStyle(.plain).foregroundStyle(tab == item ? (settings.darkMode ? Design.darkAccent : Design.accent) : .secondary)
                        .accessibilityIdentifier("tab.\(item.rawValue)")
                        .accessibilityAddTraits(tab == item ? [.isSelected] : [])
                    }
                }.background(settings.darkMode ? Design.darkSurface : .white)
            }
        }
        .environment(chrome)
        .overlay(alignment:.topTrailing) { ImageDebugMetrics() }
        .task(id: session.identity) { await session.refresh(repository: AnixartRepository(client: APIClient(baseURL: settings.useRegionalAPI ? APIClient.regionalURL : APIClient.primaryURL))) }
    }
}
