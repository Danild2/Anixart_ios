import Foundation

actor CatalogCache {
    struct Snapshot: Codable, Sendable { let savedAt: Date; let releases: [Release] }
    private let url: URL
    init(directory: URL? = nil) {
        let directory = directory ?? FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Anixart", isDirectory: true)
        url = directory.appendingPathComponent("public-catalog-v1.json")
    }
    func read() -> Snapshot? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(Snapshot.self, from: data)
    }
    func write(_ releases: [Release]) {
        do {
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            let data = try JSONEncoder().encode(Snapshot(savedAt: Date(), releases: releases))
            try data.write(to: url, options: [.atomic, .completeFileProtectionUnlessOpen])
        } catch { /* Optional public cache: live request remains authoritative. */ }
    }
}
