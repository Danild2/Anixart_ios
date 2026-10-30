import Foundation
import Observation

enum AppTheme: String, CaseIterable, Identifiable {
    case original, liquidGlass
    var id: String { rawValue }
    var title: String { self == .original ? "Original" : "iOS Liquid Glass" }
}

@MainActor @Observable final class AppSettings {
    var theme: AppTheme { didSet { defaults.set(theme.rawValue, forKey: "theme") } }
    var darkMode: Bool { didSet { defaults.set(darkMode, forKey: "darkMode") } }
    var useRegionalAPI: Bool { didSet { defaults.set(useRegionalAPI, forKey: "regionalAPI") } }
    private let defaults: UserDefaults
    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        theme = AppTheme(rawValue: defaults.string(forKey: "theme") ?? "liquidGlass") ?? .liquidGlass
        darkMode = defaults.object(forKey: "darkMode") as? Bool ?? true
        useRegionalAPI = defaults.bool(forKey: "regionalAPI")
    }
}
