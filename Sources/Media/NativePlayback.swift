import AVKit
import SwiftUI
import Observation

@MainActor @Observable final class NativePlayback {
    private(set) var player: AVPlayer?
    private(set) var error: String?
    private(set) var ready = false
    private(set) var speed: Float = 1
    private let progress: ProgressStore
    private let key: PlaybackKey
    private var timer: Any?
    private var statusObserver: NSKeyValueObservation?
    private var startupTask: Task<Void, Never>?

    init(key: PlaybackKey, progress: ProgressStore = ProgressStore()) { self.key = key; self.progress = progress }
    func start(url: URL, autoplay: Bool = true, resumeOverride: Double? = nil) {
        stop(); error = nil; ready = false
        do { try AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback); try AVAudioSession.sharedInstance().setActive(true) }
        catch { self.error = "Не удалось настроить звук: \(error.localizedDescription)" }
        let item = AVPlayerItem(url: url)
        let player = AVPlayer(playerItem: item)
        self.player = player
        let resume = resumeOverride ?? progress.progress(for: key)?.resumeSeconds ?? 0
        if resume > 0 { player.seek(to: CMTime(seconds: resume, preferredTimescale: 600)) }
        statusObserver = item.observe(\.status, options: [.initial, .new]) { [weak self] _, _ in
            Task { @MainActor [weak self] in self?.updateStatus() }
        }
        timer = player.addPeriodicTimeObserver(forInterval: CMTime(seconds: 5, preferredTimescale: 600), queue: .main) { [weak self] _ in
            Task { @MainActor [weak self] in self?.save() }
        }
        startupTask = Task { [weak self] in
            do { try await Task.sleep(for: .seconds(30)) } catch { return }
            guard let self, !self.ready else { return }
            self.error = "Источник не начал воспроизведение. Выберите другой источник или повторите попытку."
        }
        player.defaultRate = speed
        if autoplay { player.play() }
    }
    func quality(_ url: URL) {
        let position = player?.currentTime().seconds
        let playing = (player?.rate ?? 0) > 0
        start(url: url, autoplay: playing, resumeOverride: position.flatMap { $0.isFinite ? $0 : nil })
    }
    func setSpeed(_ value: Float) {
        guard [0.5, 0.75, 1, 1.25, 1.5, 2].contains(value) else { return }
        speed = value; player?.defaultRate = value
        if (player?.rate ?? 0) > 0 { player?.rate = value }
    }
    private func updateStatus() {
        guard let item = player?.currentItem else { return }
        if item.status == .readyToPlay { ready = true; startupTask?.cancel() }
        if item.status == .failed { error = "Не удалось воспроизвести источник. \(item.error?.localizedDescription ?? "")"; startupTask?.cancel() }
    }
    func save() {
        guard let player, ready else { return }
        do { try progress.save(key: key, seconds: player.currentTime().seconds, duration: player.currentItem?.duration.seconds) }
        catch { self.error = "Не удалось сохранить позицию просмотра: \(error.localizedDescription)" }
    }
    func stop() {
        startupTask?.cancel(); startupTask = nil
        save(); player?.pause()
        if let timer { player?.removeTimeObserver(timer); self.timer = nil }
        statusObserver?.invalidate(); statusObserver = nil
        player = nil
    }
}

struct NativePlayerView: UIViewControllerRepresentable {
    let player: AVPlayer
    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let controller = AVPlayerViewController()
        controller.player = player
        controller.showsPlaybackControls = true
        controller.allowsPictureInPicturePlayback = false // Enable only after device and signing validation.
        return controller
    }
    func updateUIViewController(_ controller: AVPlayerViewController, context: Context) { controller.player = player }
    static func dismantleUIViewController(_ controller: AVPlayerViewController, coordinator: ()) { controller.player = nil }
}
