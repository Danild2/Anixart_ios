import Foundation

struct PlaybackKey: Codable, Hashable, Sendable {
    let account: String
    let releaseID: Int64
    let typeID: Int64
    let sourceID: Int64
    let position: Int
}
struct PlaybackProgress: Codable, Sendable {
    let key: PlaybackKey
    var seconds: Double
    var duration: Double?
    var updatedAt: Date
    var resumeSeconds: Double {
        guard seconds.isFinite, seconds >= 0 else { return 0 }
        if let duration, duration.isFinite, duration > 0, seconds >= duration - 10 { return 0 }
        return seconds
    }
}
@MainActor final class ProgressStore {
    private let url: URL
    private var entries: [PlaybackProgress]
    init(directory: URL? = nil) {
        let directory = directory ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Anixart", isDirectory: true)
        url = directory.appendingPathComponent("progress-v1.json")
        entries = (try? Data(contentsOf: url)).flatMap { try? JSONDecoder().decode([PlaybackProgress].self, from: $0) } ?? []
    }
    func progress(for key: PlaybackKey) -> PlaybackProgress? { entries.first { $0.key == key } }
    func save(key: PlaybackKey, seconds: Double, duration: Double?) throws {
        guard seconds.isFinite, seconds >= 0 else { return }
        entries.removeAll { $0.key == key }
        let safeDuration = duration.flatMap { $0.isFinite && $0 > 0 ? $0 : nil }
        entries.insert(PlaybackProgress(key: key, seconds: seconds, duration: safeDuration, updatedAt: Date()), at: 0)
        entries = Array(entries.prefix(2000))
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONEncoder().encode(entries).write(to: url, options: [.atomic, .completeFileProtectionUnlessOpen])
    }
}
