import Foundation

/// Text extracted from the supplied APK; coverage of the file is not screen parity.
enum OriginalCopy {
    struct Resources: Decodable, Sendable {
        let strings: [String: String]
        let arrays: [String: [String]]
        let plurals: [String: [String: String]]
    }
    static let resources: Resources = {
        guard let url = Bundle.main.url(forResource: "OriginalResources", withExtension: "json"),
              let data = try? Data(contentsOf: url), let value = try? JSONDecoder().decode(Resources.self, from: data) else {
            return Resources(strings: [:], arrays: [:], plurals: [:])
        }
        return value
    }()
    static func text(_ key: String) -> String { unescape(resources.strings[key] ?? key) }
    static func array(_ key: String) -> [String] { (resources.arrays[key] ?? []).map(unescape) }
    static func plural(_ key: String, count: Int) -> String {
        let modulo10 = abs(count) % 10, modulo100 = abs(count) % 100
        let category = modulo10 == 1 && modulo100 != 11 ? "one" : ((2...4).contains(modulo10) && !(12...14).contains(modulo100) ? "few" : "many")
        let forms = resources.plurals[key] ?? [:]
        return unescape(forms[category] ?? forms["other"] ?? key)
    }
    static func format(_ key: String, _ arguments: CVarArg...) -> String {
        let pattern = text(key).replacingOccurrences(of: #"(?<!%)%([0-9]+\$)?s"#, with: "%$1@", options: .regularExpression)
        return String(format: pattern, locale: Locale(identifier: "ru_RU"), arguments: arguments)
    }
    private static func unescape(_ value: String) -> String {
        value.replacingOccurrences(of: #"\n"#, with: "\n").replacingOccurrences(of: #"\'"#, with: "'")
            .replacingOccurrences(of: #"\""#, with: "\"")
    }
}
