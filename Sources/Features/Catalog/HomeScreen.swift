import SwiftUI

private enum HomeSection: Int, CaseIterable, Identifiable {
    case custom, anime, donghua, actual, ongoing, upcoming, finished, movies, ova
    var id: Int { rawValue }
    var title: String {
        OriginalCopy.text(["my_custom_filter_tab", "tab_title_anime", "tab_title_donghua", "tab_title_actual",
                           "tab_title_ongoing", "tab_title_upcoming", "tab_title_finished", "tab_title_movies", "tab_title_ova"][rawValue])
    }
    var filter: CatalogFilter {
        // HomeFragment.lll1l1IlII and HomeTabPresenter pass these exact values.
        switch self {
        case .anime: CatalogFilter(country: OriginalCopy.text("country_japan"))
        case .donghua: CatalogFilter(country: OriginalCopy.text("country_china"))
        case .ongoing: CatalogFilter(statusId: 2)
        case .upcoming: CatalogFilter(statusId: 3)
        case .finished: CatalogFilter(statusId: 1)
        case .movies: CatalogFilter(categoryId: 2)
        case .ova: CatalogFilter(categoryId: 3)
        case .actual, .custom: CatalogFilter()
        }
    }
}

struct HomeScreen: View {
    // Prefs.l1II1lIIlI defaults to position 1 in APK 10.5.
    @AppStorage("home-section") private var position = 1
    private var selected: HomeSection { HomeSection(rawValue: position) ?? .anime }
    var body: some View {
        VStack(spacing: 0) {
            ScrollView(.horizontal) {
                HStack(spacing: 20) {
                    ForEach(HomeSection.allCases) { section in
                        Button { position = section.rawValue } label: {
                            VStack(spacing: 10) {
                                Text(section.title).font(.subheadline.weight(selected == section ? .semibold : .regular))
                                Capsule().fill(selected == section ? Color.accentColor : .clear).frame(height: 3)
                            }
                        }.buttonStyle(.plain).accessibilityAddTraits(selected == section ? [.isSelected] : [])
                    }
                }.padding(.horizontal).padding(.top, 8)
            }.scrollIndicators(.hidden)
            CatalogScreen(title: "Anixart", feed: .catalog, searchable: true, initialFilter: selected.filter,
                          persistenceKey: selected == .custom ? "home.custom.filter.v1" : nil)
                .id(selected)
        }
    }
}
