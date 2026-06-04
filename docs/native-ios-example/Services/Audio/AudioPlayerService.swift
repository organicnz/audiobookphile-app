//
//  AudioPlayerService.swift
//  AudiobookphileClient
//
//  AVFoundation audio player with background playback and lock screen controls
//

import Foundation
import AVFoundation
import MediaPlayer
import Combine

/// Main audio player service using AVFoundation
@MainActor
class AudioPlayerService: NSObject, ObservableObject {
    static let shared = AudioPlayerService()

    // MARK: - Published State

    @Published var session: PlaybackSession?
    @Published var isPlaying = false
    @Published var isLoading = false
    @Published var currentTime: TimeInterval = 0
    @Published var duration: TimeInterval = 0
    @Published var bufferedTime: TimeInterval = 0
    @Published var playbackRate: Float = 1.0
    @Published var currentChapter: Chapter?
    @Published var syncStatus: SyncStatus = .idle

    // MARK: - Private Properties

    private var player: AVPlayer?
    private var playerItem: AVPlayerItem?
    private var timeObserver: Any?
    private var cancellables = Set<AnyCancellable>()
    private var syncTimer: Timer?
    private var lastSyncTime: Date = Date()
    private let syncInterval: TimeInterval = 30 // Sync every 30 seconds

    // MARK: - Initialization

    override init() {
        super.init()
        setupAudioSession()
        setupRemoteTransportControls()
        setupNotifications()
    }

    // MARK: - Audio Session Setup

    private func setupAudioSession() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playback, mode: .spokenAudio, options: [])
            try audioSession.setActive(true)
        } catch {
            print("[AudioPlayerService] Failed to setup audio session: \(error)")
        }
    }

    // MARK: - Remote Transport Controls (Lock Screen)

    private func setupRemoteTransportControls() {
        let commandCenter = MPRemoteCommandCenter.shared()

        // Play
        commandCenter.playCommand.addTarget { [weak self] _ in
            self?.play()
            return .success
        }

        // Pause
        commandCenter.pauseCommand.addTarget { [weak self] _ in
            self?.pause()
            return .success
        }

        // Toggle Play/Pause
        commandCenter.togglePlayPauseCommand.addTarget { [weak self] _ in
            if self?.isPlaying == true {
                self?.pause()
            } else {
                self?.play()
            }
            return .success
        }

        // Skip Forward
        commandCenter.skipForwardCommand.preferredIntervals = [30]
        commandCenter.skipForwardCommand.addTarget { [weak self] _ in
            self?.seek(by: 30)
            return .success
        }

        // Skip Backward
        commandCenter.skipBackwardCommand.preferredIntervals = [10]
        commandCenter.skipBackwardCommand.addTarget { [weak self] _ in
            self?.seek(by: -10)
            return .success
        }

        // Seek (scrubbing)
        commandCenter.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let positionEvent = event as? MPChangePlaybackPositionCommandEvent else {
                return .commandFailed
            }
            self?.seek(to: positionEvent.positionTime)
            return .success
        }
    }

    // MARK: - Notifications

    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleInterruption),
            name: AVAudioSession.interruptionNotification,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleRouteChange),
            name: AVAudioSession.routeChangeNotification,
            object: nil
        )
    }

    @objc private func handleInterruption(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
            return
        }

        switch type {
        case .began:
            pause()
        case .ended:
            guard let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt else { return }
            let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
            if options.contains(.shouldResume) {
                play()
            }
        @unknown default:
            break
        }
    }

    @objc private func handleRouteChange(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let reasonValue = userInfo[AVAudioSessionRouteChangeReasonKey] as? UInt,
              let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue) else {
            return
        }

        if reason == .oldDeviceUnavailable {
            // Headphones were unplugged - pause
            pause()
        }
    }

    // MARK: - Playback Control

    /// Start playback from a session
    func startPlayback(session: PlaybackSession) async {
        self.session = session
        self.isLoading = true

        let audioTracks = session.audioTracks
        guard !audioTracks.isEmpty else {
            print("[AudioPlayerService] No audio tracks in session")
            isLoading = false
            return
        }

        // Get the first track URL
        let serverURL = UserDefaults.standard.string(forKey: "serverURL") ?? ""
        let firstTrack = audioTracks[0]
        let trackURL = "\(serverURL)\(firstTrack.contentUrl)"

        guard let url = URL(string: trackURL) else {
            print("[AudioPlayerService] Invalid track URL")
            isLoading = false
            return
        }

        // Create player item
        let asset = AVURLAsset(url: url)
        playerItem = AVPlayerItem(asset: asset)

        // Create player
        player = AVPlayer(playerItem: playerItem)
        player?.rate = playbackRate

        // Observe status
        playerItem?.publisher(for: \.status)
            .sink { [weak self] status in
                switch status {
                case .readyToPlay:
                    self?.isLoading = false
                    self?.duration = session.duration

                    // Seek to saved position
                    let startTime = session.currentTime
                    if startTime > 0 {
                        self?.seek(to: startTime)
                    }

                    // Auto-play
                    self?.play()

                case .failed:
                    self?.isLoading = false
                    print("[AudioPlayerService] Player item failed: \(String(describing: self?.playerItem?.error))")

                default:
                    break
                }
            }
            .store(in: &cancellables)

        // Time observer
        let interval = CMTime(seconds: 1, preferredTimescale: 1000)
        timeObserver = player?.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            self?.updateTime(time.seconds)
        }

        // Update Now Playing info
        updateNowPlayingInfo()

        // Start sync timer
        startSyncTimer()
    }

    func play() {
        player?.play()
        player?.rate = playbackRate
        isPlaying = true
        updateNowPlayingInfo()
    }

    func pause() {
        player?.pause()
        isPlaying = false
        updateNowPlayingInfo()

        // Sync immediately on pause
        Task {
            await syncProgress()
        }
    }

    func seek(to time: TimeInterval) {
        let cmTime = CMTime(seconds: time, preferredTimescale: 1000)
        player?.seek(to: cmTime, toleranceBefore: .zero, toleranceAfter: .zero)
        currentTime = time
        updateNowPlayingInfo()
    }

    func seek(by seconds: TimeInterval) {
        let newTime = max(0, min(duration, currentTime + seconds))
        seek(to: newTime)
    }

    func setPlaybackRate(_ rate: Float) {
        playbackRate = rate
        if isPlaying {
            player?.rate = rate
        }
        updateNowPlayingInfo()
    }

    func stop() {
        player?.pause()

        if let observer = timeObserver {
            player?.removeTimeObserver(observer)
            timeObserver = nil
        }

        player = nil
        playerItem = nil
        session = nil
        isPlaying = false
        currentTime = 0
        duration = 0

        stopSyncTimer()
        clearNowPlayingInfo()
    }

    // MARK: - Time Updates

    private func updateTime(_ time: TimeInterval) {
        currentTime = time

        // Update current chapter
        if let chapters = session?.chapters {
            currentChapter = chapters.first { chapter in
                time >= chapter.start && time < chapter.end
            }
        }

        updateNowPlayingInfo()
    }

    // MARK: - Now Playing Info

    private func updateNowPlayingInfo() {
        var nowPlayingInfo = [String: Any]()

        if let session = session {
            nowPlayingInfo[MPMediaItemPropertyTitle] = session.displayTitle
            nowPlayingInfo[MPMediaItemPropertyArtist] = session.displayAuthor
            nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = currentTime
            nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = duration
            nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? playbackRate : 0

            if let chapter = currentChapter {
                nowPlayingInfo[MPNowPlayingInfoPropertyChapterNumber] = session.chapters.firstIndex(where: { $0.id == chapter.id })
                nowPlayingInfo[MPNowPlayingInfoPropertyChapterCount] = session.chapters.count
            }
        }

        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
    }

    private func clearNowPlayingInfo() {
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
    }

    // MARK: - Progress Sync

    private func startSyncTimer() {
        syncTimer = Timer.scheduledTimer(withTimeInterval: syncInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.syncProgress()
            }
        }
    }

    private func stopSyncTimer() {
        syncTimer?.invalidate()
        syncTimer = nil
    }

    func syncProgress() async {
        guard let session = session else { return }

        syncStatus = .syncing

        do {
            try await AudiobookphileAPI.shared.syncProgress(
                sessionId: session.id,
                currentTime: currentTime,
                duration: duration,
                timeListened: Date().timeIntervalSince(lastSyncTime)
            )
            syncStatus = .success
            lastSyncTime = Date()

            // Reset to idle after a moment
            Task {
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                self.syncStatus = .idle
            }
        } catch {
            print("[AudioPlayerService] Sync failed: \(error)")
            syncStatus = .failed
        }
    }

    func closeSession() async {
        guard let session = session else { return }

        // Final sync
        await syncProgress()

        // Close session on server
        do {
            try await AudiobookphileAPI.shared.closePlaybackSession(
                sessionId: session.id,
                currentTime: currentTime,
                duration: duration
            )
        } catch {
            print("[AudioPlayerService] Failed to close session: \(error)")
        }

        stop()
    }
}
