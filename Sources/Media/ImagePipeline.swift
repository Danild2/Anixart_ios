import Foundation
import ImageIO
import CryptoKit

/// CGImage is immutable; this wrapper transfers a fully decoded bitmap between executors.
struct PosterBitmap: @unchecked Sendable { let image: CGImage }
private final class PosterBitmapBox: NSObject { let value: PosterBitmap; init(_ value: PosterBitmap) { self.value = value } }

actor ImagePipeline {
    static let shared = ImagePipeline()
    struct Metrics: Sendable, Equatable { var decoded = 0; var memoryHits = 0; var diskHits = 0; var requests = 0; var failures = 0 }
    private let session: URLSession
    private let directory: URL
    private let memory = NSCache<NSString, PosterBitmapBox>()
    private var images: [String: Task<PosterBitmap, Error>] = [:]
    private var downloads: [URL: Task<Data, Error>] = [:]
    private var metrics = Metrics()
    init(session: URLSession? = nil, directory: URL? = nil) {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.urlCache = nil
        configuration.httpShouldSetCookies = false
        configuration.httpMaximumConnectionsPerHost = 4
        configuration.timeoutIntervalForRequest = 20
        configuration.timeoutIntervalForResource = 35
        self.session = session ?? URLSession(configuration: configuration)
        self.directory = directory ?? FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0].appendingPathComponent("Anixart/Images-v1", isDirectory: true)
        memory.totalCostLimit = 32 * 1024 * 1024
        memory.countLimit = 256
    }
    func snapshot() -> Metrics { metrics }
    func image(_ url: URL, pixels: Int) async throws -> PosterBitmap {
        guard ["https", "http"].contains(url.scheme ?? ""), url.host != nil, url.user == nil, url.password == nil else { throw APIError.invalidURL }
        let pixels = min(1200, max(64, pixels))
        let key = "\(url.absoluteString)|\(pixels)"
        if let value = memory.object(forKey: key as NSString) { metrics.memoryHits += 1; return value.value }
        if let task = images[key] { return try await task.value }
        let task = Task.detached(priority: .userInitiated) { [self] in
            let data = try await self.data(url)
            return try Self.decode(data, pixels: pixels)
        }
        images[key] = task
        defer { images[key] = nil }
        do {
            let value = try await task.value
            memory.setObject(PosterBitmapBox(value), forKey: key as NSString, cost: value.image.bytesPerRow * value.image.height)
            metrics.decoded += 1
            return value
        } catch { metrics.failures += 1; throw error }
    }
    private func data(_ url: URL) async throws -> Data {
        let digest = SHA256.hash(data: Data(url.absoluteString.utf8)).map { String(format: "%02x", $0) }.joined()
        let file = directory.appendingPathComponent(digest)
        if let date = try? file.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate,
           Date().timeIntervalSince(date) < 7 * 24 * 3600,
           let value = try? Data(contentsOf: file), Self.validSource(value) != nil {
            metrics.diskHits += 1; return value
        }
        if let task = downloads[url] { return try await task.value }
        let session = self.session
        let task = Task.detached(priority: .userInitiated) {
            for attempt in 0..<2 {
                do {
                    var request = URLRequest(url: url); request.setValue("image/avif,image/webp,image/*;q=0.9,*/*;q=0.5", forHTTPHeaderField: "Accept")
                    let (data, response) = try await session.data(for: request)
                    guard let response = response as? HTTPURLResponse else { throw APIError.malformed }
                    if [502, 503, 504].contains(response.statusCode), attempt == 0 {
                        try await Task.sleep(for: .milliseconds(600)); continue
                    }
                    guard response.statusCode == 200 else { throw APIError.http(response.statusCode) }
                    guard data.count <= 8_000_000, !data.isEmpty, Self.validSource(data) != nil else { throw APIError.malformed }
                    return data
                } catch let error as URLError where attempt == 0 && [.timedOut, .networkConnectionLost].contains(error.code) {
                    try await Task.sleep(for: .milliseconds(400))
                }
            }
            throw APIError.malformed
        }
        downloads[url] = task; metrics.requests += 1
        defer { downloads[url] = nil }
        let value = try await task.value
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try value.write(to: file, options: .atomic)
            trimDisk()
        } catch { /* A disk-cache failure must not prevent displaying downloaded content. */ }
        return value
    }
    private func trimDisk() {
        guard let files = try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey]) else { return }
        let entries = files.compactMap { file -> (URL, Int, Date)? in
            guard let values = try? file.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey]) else { return nil }
            return (file, values.fileSize ?? 0, values.contentModificationDate ?? .distantPast)
        }.sorted { $0.2 > $1.2 }
        var total = 0
        for (file, bytes, _) in entries {
            total += bytes
            if total > 192 * 1024 * 1024 { try? FileManager.default.removeItem(at: file) }
        }
    }
    nonisolated static func decode(_ data: Data, pixels: Int) throws -> PosterBitmap {
        guard let source = validSource(data),
              let bitmap = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: pixels,
                kCGImageSourceShouldCacheImmediately: true
              ] as CFDictionary) else { throw APIError.malformed }
        return PosterBitmap(image: bitmap)
    }
    nonisolated private static func validSource(_ data: Data) -> CGImageSource? {
        guard let source = CGImageSourceCreateWithData(data as CFData,[kCGImageSourceShouldCache:false] as CFDictionary),
              CGImageSourceGetStatus(source) == .statusComplete,
              let values = CGImageSourceCopyPropertiesAtIndex(source,0,nil) as? [CFString:Any],
              let width = (values[kCGImagePropertyPixelWidth] as? NSNumber)?.intValue,
              let height = (values[kCGImagePropertyPixelHeight] as? NSNumber)?.intValue,
              width > 0, height > 0, width <= 16000, height <= 16000, width * height <= 40_000_000 else { return nil }
        return source
    }
}
