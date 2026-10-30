import Foundation
import CryptoKit

actor CatalogCache {
    struct Snapshot: Codable, Sendable { let savedAt: Date; let releases: [Release]; var filter: CatalogFilter? }
    private let directory: URL
    init(directory: URL? = nil) {
        self.directory = directory ?? FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Anixart", isDirectory: true)
    }
    private func url(for filter: CatalogFilter) throws -> URL {
        let encoder = JSONEncoder(); encoder.outputFormatting = .sortedKeys
        let digest = SHA256.hash(data: try encoder.encode(filter)).map { String(format: "%02x", $0) }.joined()
        return directory.appendingPathComponent("public-catalog-v2-\(digest).json")
    }
    func read(filter: CatalogFilter = CatalogFilter()) -> Snapshot? {
        guard let url = try? url(for: filter) else { return nil }
        var data = try? Data(contentsOf: url)
        if data == nil, filter == CatalogFilter() { data = try? Data(contentsOf: directory.appendingPathComponent("public-catalog-v1.json")) }
        guard let data, let snapshot = try? JSONDecoder().decode(Snapshot.self, from: data),
              snapshot.filter == filter || (snapshot.filter == nil && filter == CatalogFilter()) else { return nil }
        return snapshot
    }
    func write(_ releases: [Release], filter: CatalogFilter = CatalogFilter()) {
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let data = try JSONEncoder().encode(Snapshot(savedAt: Date(), releases: releases, filter: filter))
            try data.write(to: url(for: filter), options: [.atomic, .completeFileProtectionUnlessOpen])
            let files = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.contentModificationDateKey])
                .compactMap { file -> (url: URL, date: Date)? in
                    guard file.lastPathComponent.hasPrefix("public-catalog-v2-"), file.pathExtension == "json" else { return nil }
                    let date = try? file.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
                    return (file, date ?? .distantPast)
                }.sorted { $0.date > $1.date }
            for file in files.dropFirst(32) { try? FileManager.default.removeItem(at: file.url) }
        } catch { /* Optional public cache: live request remains authoritative. */ }
    }
}
