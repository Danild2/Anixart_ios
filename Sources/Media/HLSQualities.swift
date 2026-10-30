import Foundation

struct HLSQuality: Identifiable, Hashable, Sendable {
    let url: URL
    let height: Int?
    let bandwidth: Int?
    var id: URL { url }
    var title: String {
        if let height { return "\(height)p" }
        if let bandwidth { return (Double(bandwidth) / 1_000_000).formatted(.number.precision(.fractionLength(1))) + " Мбит/с" }
        return "Поток"
    }
}

struct HLSQualities {
    static func parse(_ data: Data, baseURL: URL) throws -> [HLSQuality] {
        guard data.count <= 2_000_000, let text = String(data: data, encoding: .utf8), text.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("#EXTM3U") else { throw APIError.malformed }
        let expression = try NSRegularExpression(pattern: #"([A-Z0-9-]+)=("[^"]*"|[^,]*)"#)
        func attributes(_ line: String) -> [String: String] {
            var result: [String: String] = [:]
            for match in expression.matches(in: line, range: NSRange(line.startIndex..<line.endIndex, in: line)) {
                if let key = Range(match.range(at: 1), in: line), let value = Range(match.range(at: 2), in: line) {
                    result[String(line[key])] = String(line[value]).trimmingCharacters(in: CharacterSet(charactersIn: "\""))
                }
            }
            return result
        }
        let externalAudio = Set(text.components(separatedBy: .newlines).compactMap { raw -> String? in
            let line = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard line.hasPrefix("#EXT-X-MEDIA:") else { return nil }
            let values = attributes(line)
            return values["TYPE"] == "AUDIO" && values["URI"] != nil ? values["GROUP-ID"] : nil
        })
        var pending: [String: String]?
        var result: [HLSQuality] = []
        for raw in text.components(separatedBy: .newlines) {
            let line = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            if line.hasPrefix("#EXT-X-STREAM-INF:") {
                pending = attributes(line)
            } else if !line.isEmpty, !line.hasPrefix("#"), let attributes = pending {
                pending = nil
                // Opening a video-only child playlist would discard its separate audio.
                // Keep the complete master URL in Auto for those manifests.
                if let group = attributes["AUDIO"], externalAudio.contains(group) { continue }
                guard let url = URL(string: line, relativeTo: baseURL)?.absoluteURL, ["http", "https"].contains(url.scheme ?? ""), url.user == nil, url.password == nil else { continue }
                let height = attributes["RESOLUTION"].flatMap { Int($0.split(separator: "x").last ?? "") }
                result.append(HLSQuality(url: url, height: height, bandwidth: attributes["BANDWIDTH"].flatMap(Int.init)))
            }
        }
        var seen: Set<URL> = []
        return result.filter { seen.insert($0.url).inserted }.sorted { ($0.height ?? 0, $0.bandwidth ?? 0) > ($1.height ?? 0, $1.bandwidth ?? 0) }
    }
    static func load(_ url: URL) async throws -> [HLSQuality] {
        var request = URLRequest(url: url); request.timeoutInterval = 15
        let configuration = URLSessionConfiguration.ephemeral
        configuration.urlCache = nil
        let session = URLSession(configuration: configuration)
        defer { session.invalidateAndCancel() }
        let (bytes, response) = try await session.bytes(for: request)
        guard let response = response as? HTTPURLResponse else { throw APIError.malformed }
        guard response.statusCode == 200 else { throw APIError.http(response.statusCode) }
        guard response.expectedContentLength <= 2_000_000 else { throw APIError.malformed }
        var data = Data()
        for try await byte in bytes {
            guard data.count < 2_000_000 else { throw APIError.malformed }
            data.append(byte)
        }
        return try parse(data, baseURL: response.url ?? url)
    }
}
