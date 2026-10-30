import Foundation
import Observation
import UIKit

@MainActor protocol ExternalURLOpener {
    func canOpen(_ url: URL) -> Bool
    func open(_ url: URL) async -> Bool
}
struct ApplicationURLOpener: ExternalURLOpener {
    func canOpen(_ url: URL) -> Bool { UIApplication.shared.canOpenURL(url) }
    func open(_ url: URL) async -> Bool { await UIApplication.shared.open(url) }
}

@MainActor @Observable final class ExternalPlayback {
    struct Handoff: Sendable {
        let requestID: UUID
        let key: PlaybackKey
        let title: String
    }
    private(set) var active: Handoff?
    private(set) var message: String?
    private(set) var error: String?
    private let opener: any ExternalURLOpener
    init(opener: any ExternalURLOpener = ApplicationURLOpener()) { self.opener = opener }
    var isVLCInstalled: Bool { opener.canOpen(URL(string: "vlc-x-callback://x-callback-url/stream")!) }

    @discardableResult func open(media: URL, key: PlaybackKey, title: String, subtitles: URL? = nil) async -> Bool {
        error = nil; message = nil
        guard isVLCInstalled else { error = "Установите VLC для iOS, затем повторите открытие серии."; return false }
        do {
            let handoff = Handoff(requestID: UUID(), key: key, title: title)
            let link = try VLCLink.stream(media: media, title: title, subtitles: subtitles, requestID: handoff.requestID)
            active = handoff
            let opened = await opener.open(link)
            if opened { message = "Серия передана в VLC." }
            else { active = nil; error = "Не удалось открыть VLC." }
            return opened
        } catch { self.error = error.localizedDescription; return false }
    }
    @discardableResult func handleCallback(_ url: URL) -> Bool {
        guard url.scheme == "anixartport", url.host == "vlc-return", let active,
              let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems,
              items.first(where: { $0.name == "request" })?.value == active.requestID.uuidString else { return false }
        switch items.first(where: { $0.name == "outcome" })?.value {
        case "success": message = "Возврат из VLC: \(active.title)"; error = nil
        case "error": error = "VLC сообщил об ошибке открытия потока."
        default: return false
        }
        // VLC does not return time/duration through x-callback; do not fabricate progress.
        self.active = nil
        return true
    }
}
