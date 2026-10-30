import Foundation

enum StreamTestCapture {
    static func write(_ url: URL, key: PlaybackKey, duration: Double? = nil) {
        #if DEBUG
        guard ProcessInfo.processInfo.arguments.contains("-captureResolvedStream"),
              let directory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first else { return }
        let record: [String: Any] = ["url": url.absoluteString, "duration": duration ?? 0, "release_id": key.releaseID,
                                   "source_id": key.sourceID, "position": key.position]
        if let data = try? JSONSerialization.data(withJSONObject: record) {
            try? data.write(to: directory.appendingPathComponent("VLCStreamForTest.json"), options: .atomic)
        }
        #endif
    }
}
