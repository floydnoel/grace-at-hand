import Foundation
import Observation
@preconcurrency import AVFoundation
@preconcurrency import MediaPlayer
import UIKit
import GraceCore

@MainActor @Observable final class PlaybackService {
    private(set) var current: Prayer?
    private(set) var isPlaying = false
    private(set) var isLoading = false
    private(set) var position: Double = 0
    private(set) var duration: Double = 1
    private(set) var errorMessage: String?
    private(set) var rate: Float = 1
    private(set) var sleepDeadline: Date?
    private(set) var sleepAtEnd = false
    var persist: ((Prayer, Double, Bool) -> Void)?
    private var player = AVPlayer()
    private var timeObserver: Any?
    private var controlObservation: NSKeyValueObservation?
    private var itemObservation: NSKeyValueObservation?
    private var notificationObservers: [NSObjectProtocol] = []
    private var remoteTargets: [Any] = []
    private(set) var currentURL: URL?
    @ObservationIgnored private lazy var artwork: MPMediaItemArtwork? = {
        guard let image = UIImage(named: "Cloister") else { return nil }
        return MPMediaItemArtwork(boundsSize: image.size) { @Sendable _ in image }
    }()
    private var lastPersisted: Double = -10
    private var autoplayAfterReady = false
    private var resumeAfterInterruption = false
    private var playGeneration = UUID()

    init() { installPlayerObservers(); installNotifications(); installRemoteCommands() }
    private func installPlayerObservers() {
        controlObservation = player.observe(\.timeControlStatus, options: [.initial, .new]) { @Sendable [weak self] player, _ in
            let status = player.timeControlStatus
            Task { @MainActor [weak self] in
                self?.isPlaying = status == .playing
                self?.isLoading = status == .waitingToPlayAtSpecifiedRate
                self?.updateNowPlaying()
            }
        }
        timeObserver = player.addPeriodicTimeObserver(forInterval: CMTime(seconds: 0.5, preferredTimescale: 600), queue: .main) { [weak self] time in
            let seconds = time.seconds
            Task { @MainActor [weak self] in
                guard let self, seconds.isFinite else { return }
                position = max(0, seconds)
                if let actual = player.currentItem?.duration.seconds, actual.isFinite, actual > 0 { duration = actual }
                if abs(position - lastPersisted) >= 5 { savePosition() }
                checkSleepTimer(); updateNowPlaying()
            }
        }
    }
    private func configureSession() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playback, mode: .spokenAudio, policy: .longFormAudio)
        try session.setActive(true)
    }
    func prepare(_ prayer: Prayer, url: URL, position: Double = 0, autoplay: Bool = true) {
        savePosition()
        player.pause(); playGeneration = UUID()
        current = prayer; currentURL = url; self.position = position
        duration = max(1, prayer.durationSeconds); errorMessage = nil; isLoading = autoplay
        lastPersisted = -10; autoplayAfterReady = autoplay
        let item = AVPlayerItem(url: url)
        let expectedGeneration = playGeneration
        itemObservation = item.observe(\.status, options: [.initial, .new]) { @Sendable [weak self] item, _ in
            let status = item.status
            Task { @MainActor [weak self] in
                guard let self, playGeneration == expectedGeneration else { return }
                if status == .failed { isLoading = false; isPlaying = false; errorMessage = "This prayer couldn’t load. You can still read the text."; savePosition() }
                else if status == .readyToPlay {
                    isLoading = false
                    seek(to: position)
                    if autoplayAfterReady { play(); autoplayAfterReady = false }
                }
            }
        }
        player.replaceCurrentItem(with: item)
        MPRemoteCommandCenter.shared().playCommand.isEnabled = true
        MPRemoteCommandCenter.shared().pauseCommand.isEnabled = true
        updateNowPlaying()
    }
    func play() {
        guard current != nil else { return }
        do {
            try configureSession()
            if position >= duration - 0.5 { seek(to: 0) }
            if let deadline = sleepDeadline, deadline <= .now { sleepDeadline = nil }
            player.playImmediately(atRate: rate); errorMessage = nil
        } catch { errorMessage = "Audio is unavailable right now. Try again or read the prayer." }
    }
    func pause() { autoplayAfterReady = false; player.pause(); savePosition(); updateNowPlaying() }
    func toggle() { isPlaying || isLoading ? pause() : play() }
    func seek(to seconds: Double) {
        guard seconds.isFinite else { return }
        let value = min(max(0, seconds), duration)
        position = value
        player.seek(to: CMTime(seconds: value, preferredTimescale: 600), toleranceBefore: .zero, toleranceAfter: .zero)
        savePosition(); updateNowPlaying()
    }
    func skip(_ seconds: Double) { seek(to: position + seconds) }
    func setRate(_ value: Float) { rate = min(2, max(0.5, value)); if isPlaying { player.rate = rate }; updateNowPlaying() }
    func setSleep(minutes: Int?) {
        sleepAtEnd = minutes == 0
        sleepDeadline = minutes.flatMap { $0 > 0 ? Date.now.addingTimeInterval(Double($0) * 60) : nil }
    }
    private func checkSleepTimer() {
        if let sleepDeadline, Date.now >= sleepDeadline { self.sleepDeadline = nil; pause() }
    }
    func savePosition(completed: Bool = false) {
        if let current { persist?(current, position, completed); lastPersisted = position }
    }
    func dismissCurrent() {
        pause(); playGeneration = UUID(); player.replaceCurrentItem(with: nil)
        itemObservation = nil; current = nil; currentURL = nil; position = 0; sleepDeadline = nil; sleepAtEnd = false
        errorMessage = nil; isLoading = false; isPlaying = false
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
        MPRemoteCommandCenter.shared().playCommand.isEnabled = false
        MPRemoteCommandCenter.shared().pauseCommand.isEnabled = false
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
    private func installNotifications() {
        notificationObservers.append(NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: nil, queue: .main) { [weak self] notification in
            let item = notification.object as? AVPlayerItem
            Task { @MainActor [weak self] in
                guard let self, item === player.currentItem else { return }
                position = duration; isPlaying = false; savePosition(completed: true)
                if sleepAtEnd { sleepAtEnd = false }
                updateNowPlaying()
            }
        })
        notificationObservers.append(NotificationCenter.default.addObserver(forName: .AVPlayerItemPlaybackStalled, object: nil, queue: .main) { [weak self] notification in
            let item = notification.object as? AVPlayerItem
            Task { @MainActor [weak self] in
                guard let self, item === player.currentItem else { return }
                errorMessage = "The connection paused. Your place is saved. Try again or read the prayer."
                pause(); isLoading = false
            }
        })
        notificationObservers.append(NotificationCenter.default.addObserver(forName: AVAudioSession.interruptionNotification, object: nil, queue: .main) { [weak self] notification in
            let type = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt
            let options = notification.userInfo?[AVAudioSessionInterruptionOptionKey] as? UInt ?? 0
            Task { @MainActor [weak self] in
                guard let self else { return }
                if type == AVAudioSession.InterruptionType.began.rawValue { resumeAfterInterruption = isPlaying; pause() }
                else if resumeAfterInterruption && AVAudioSession.InterruptionOptions(rawValue: options).contains(.shouldResume) { resumeAfterInterruption = false; play() }
            }
        })
        notificationObservers.append(NotificationCenter.default.addObserver(forName: AVAudioSession.routeChangeNotification, object: nil, queue: .main) { [weak self] notification in
            let reason = notification.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt
            if reason == AVAudioSession.RouteChangeReason.oldDeviceUnavailable.rawValue { Task { @MainActor [weak self] in self?.pause() } }
        })
        notificationObservers.append(NotificationCenter.default.addObserver(forName: AVAudioSession.mediaServicesWereResetNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                let prayer = current, url = currentURL, saved = position
                if let timeObserver { player.removeTimeObserver(timeObserver) }
                player = AVPlayer(); installPlayerObservers()
                if let prayer, let url { prepare(prayer, url: url, position: saved, autoplay: false) }
            }
        })
    }
    private func installRemoteCommands() {
        let center = MPRemoteCommandCenter.shared()
        center.playCommand.isEnabled = false; center.pauseCommand.isEnabled = false
        center.skipForwardCommand.preferredIntervals = [15]; center.skipBackwardCommand.preferredIntervals = [15]
        remoteTargets.append(center.playCommand.addTarget { @Sendable [weak self] _ in Task { @MainActor [weak self] in self?.play() }; return .success })
        remoteTargets.append(center.pauseCommand.addTarget { @Sendable [weak self] _ in Task { @MainActor [weak self] in self?.pause() }; return .success })
        remoteTargets.append(center.togglePlayPauseCommand.addTarget { @Sendable [weak self] _ in Task { @MainActor [weak self] in self?.toggle() }; return .success })
        remoteTargets.append(center.skipForwardCommand.addTarget { @Sendable [weak self] _ in Task { @MainActor [weak self] in self?.skip(15) }; return .success })
        remoteTargets.append(center.skipBackwardCommand.addTarget { @Sendable [weak self] _ in Task { @MainActor [weak self] in self?.skip(-15) }; return .success })
        remoteTargets.append(center.changePlaybackPositionCommand.addTarget { @Sendable [weak self] event in
            guard let event = event as? MPChangePlaybackPositionCommandEvent else { return .commandFailed }
            let position = event.positionTime
            Task { @MainActor [weak self] in self?.seek(to: position) }; return .success
        })
    }
    private func updateNowPlaying() {
        guard let current else { return }
        var info: [String: Any] = [MPMediaItemPropertyTitle: current.title, MPMediaItemPropertyArtist: "Grace at Hand", MPMediaItemPropertyPlaybackDuration: duration, MPNowPlayingInfoPropertyElapsedPlaybackTime: position, MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? rate : 0, MPNowPlayingInfoPropertyDefaultPlaybackRate: rate]
        if let artwork { info[MPMediaItemPropertyArtwork] = artwork }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }
}
