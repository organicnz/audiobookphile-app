//
//  AudioPlayerService.swift
//  Audiobookshelf
//
//  Playback state coordinator with background audio, lock screen controls, and progress sync.
//

import Foundation
import Observation
import SwiftUI
#if !SKIP && !os(Android)
import AVFoundation
import MediaPlayer
#endif

@Observable
@MainActor
public class AudioPlayerService {
    public static let shared = AudioPlayerService()

    public var session: PlaybackSession? = nil
    public var isPlaying = false
    public var currentTime: TimeInterval = 0
    public var duration: TimeInterval = 0
    public var playbackRate: Float = 1.0
    public var isBuffering = false
    public var sleepTimerRemaining: TimeInterval? = nil
    private var sleepTimer: Timer?

    private var currentTrackIndex = 0

    #if !SKIP && !os(Android)
    private var player: AVPlayer?
    private var timeObserverToken: Any?
    #endif
    
    private var progressSyncTimer: Timer?
    private var lastSyncedTime: TimeInterval = 0

    private init() {
        #if os(iOS)
        setupAudioSession()
        #endif
    }

    // MARK: - Playback Control

    public func startPlayback(session: PlaybackSession) {
        // Close existing session first
        if self.session != nil {
            Task {
                await closeSession()
            }
        }

        self.session = session
        self.duration = session.duration
        self.currentTime = session.currentTime
        self.playbackRate = session.playbackRate
        self.lastSyncedTime = session.currentTime

        // Check if there is a pending seek time from e.g. chapter selection in BookDetailView
        let pendingKey = "pendingSeekTime-\(session.id)"
        if let pendingSeek = UserDefaults.standard.value(forKey: pendingKey) as? TimeInterval {
            self.currentTime = pendingSeek
            UserDefaults.standard.removeObject(forKey: pendingKey)
        }

        // Find the correct starting track index based on currentTime
        var startingTrackIndex = 0
        var seekTimeWithinTrack = currentTime

        for (index, track) in session.audioTracks.enumerated() {
            let trackStart = track.startOffset
            let trackEnd = trackStart + track.duration
            if currentTime >= trackStart && currentTime < trackEnd {
                startingTrackIndex = index
                seekTimeWithinTrack = currentTime - trackStart
                break
            }
        }

        #if !SKIP && !os(Android)
        setupNowPlayingInfo(for: session)
        #endif

        loadTrack(index: startingTrackIndex, seekTimeWithinTrack: seekTimeWithinTrack)
        play()
        startSyncTimer()
    }

    public func play() {
        guard session != nil else { return }
        
        #if !SKIP && !os(Android)
        player?.play()
        player?.rate = playbackRate
        #endif
        
        isPlaying = true
        
        #if !SKIP && !os(Android)
        updateNowPlaying(rate: playbackRate)
        #endif
    }

    public func pause() {
        #if !SKIP && !os(Android)
        player?.pause()
        #endif
        
        isPlaying = false
        
        #if !SKIP && !os(Android)
        updateNowPlaying(rate: 0)
        #endif
        
        // Sync progress immediately on pause
        syncProgressImmediately()
    }

    public func togglePlayPause() {
        if isPlaying {
            pause()
        } else {
            play()
        }
    }

    public func seek(to time: TimeInterval) {
        guard let session = session else { return }
        let targetTime = min(max(0, time), duration)
        self.currentTime = targetTime
        
        // Find the correct track for targetTime
        var targetTrackIndex = 0
        var seekTimeWithinTrack = targetTime

        for (index, track) in session.audioTracks.enumerated() {
            let trackStart = track.startOffset
            let trackEnd = trackStart + track.duration
            if targetTime >= trackStart && targetTime <= trackEnd {
                targetTrackIndex = index
                seekTimeWithinTrack = targetTime - trackStart
                break
            }
        }

        #if !SKIP && !os(Android)
        if targetTrackIndex == currentTrackIndex {
            // We are already on the correct track, just seek AVPlayer
            let cmTime = CMTime(seconds: seekTimeWithinTrack, preferredTimescale: 600)
            player?.seek(to: cmTime, toleranceBefore: .zero, toleranceAfter: .zero) { [weak self] completed in
                if completed {
                    Task { @MainActor in
                        self?.updateNowPlaying(elapsedTime: targetTime)
                        self?.syncProgressImmediately()
                    }
                }
            }
        } else {
            // Switch tracks!
            loadTrack(index: targetTrackIndex, seekTimeWithinTrack: seekTimeWithinTrack)
            updateNowPlaying(elapsedTime: targetTime)
            syncProgressImmediately()
        }
        #else
        syncProgressImmediately()
        #endif
    }

    public func skipForward(_ seconds: TimeInterval = 30) {
        let interval: TimeInterval
        if seconds != 30 {
            interval = seconds
        } else {
            let saved = UserDefaults.standard.integer(forKey: "jumpForwardTime")
            interval = TimeInterval(saved == 0 ? 30 : saved)
        }
        seek(to: currentTime + interval)
    }

    public func skipBackward(_ seconds: TimeInterval = 10) {
        let interval: TimeInterval
        if seconds != 10 {
            interval = seconds
        } else {
            let saved = UserDefaults.standard.integer(forKey: "jumpBackwardTime")
            interval = TimeInterval(saved == 0 ? 10 : saved)
        }
        seek(to: currentTime - interval)
    }

    public func setPlaybackRate(_ rate: Float) {
        self.playbackRate = rate
        #if !SKIP && !os(Android)
        if isPlaying {
            player?.rate = rate
        }
        updateNowPlaying(rate: isPlaying ? rate : 0.0)
        #endif
    }

    public func closeSession() async {
        guard let activeSession = session else { return }

        pause()
        stopSyncTimer()
        stopSleepTimer()

        #if !SKIP && !os(Android)
        if let token = timeObserverToken {
            player?.removeTimeObserver(token)
            timeObserverToken = nil
        }
        player = nil
        #endif

        // Sync final progress
        do {
            try await AudiobookshelfAPI.shared.closePlaybackSession(
                sessionId: activeSession.id,
                currentTime: currentTime,
                duration: duration
            )
            print("[Player] Playback session closed successfully on server.")
        } catch {
            print("[Player] Failed to close session on server: \(error)")
        }

        self.session = nil
    }

    // MARK: - iOS Specific Player Setup

    #if os(iOS)
    private func setupAudioSession() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playback, mode: .default, options: [])
            try audioSession.setActive(true)
            print("[Player] Audio session category configured successfully.")
        } catch {
            print("[Player] Failed to configure AVAudioSession category: \(error)")
        }
    }
    #endif

    private func loadTrack(index: Int, seekTimeWithinTrack: TimeInterval) {
        guard let session = session else { return }
        guard index >= 0 && index < session.audioTracks.count else { return }

        self.currentTrackIndex = index
        let track = session.audioTracks[index]

        guard let url = getFullTrackURL(from: track.contentUrl, libraryItemId: session.libraryItemId) else {
            print("[Player] Error: No playable track URL found for track index \(index).")
            return
        }

        print("[Player] Loading track \(index) at URL: \(url)")

        #if !SKIP && !os(Android)
        if let token = timeObserverToken {
            player?.removeTimeObserver(token)
            timeObserverToken = nil
        }

        let playerItem = AVPlayerItem(url: url)
        if player == nil {
            player = AVPlayer(playerItem: playerItem)
            setupRemoteCommandCenter()
        } else {
            player?.replaceCurrentItem(with: playerItem)
        }

        let cmTime = CMTime(seconds: seekTimeWithinTrack, preferredTimescale: 600)
        player?.seek(to: cmTime, toleranceBefore: .zero, toleranceAfter: .zero)

        if isPlaying {
            player?.play()
            player?.rate = playbackRate
        }

        let interval = CMTime(seconds: 0.5, preferredTimescale: 600)
        timeObserverToken = player?.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            Task { @MainActor in
                guard let self = self, self.isPlaying else { return }

                let trackStart = track.startOffset
                let absoluteTime = trackStart + time.seconds
                self.currentTime = absoluteTime

                self.updateNowPlaying(elapsedTime: absoluteTime)

                let trackDuration = track.duration
                if time.seconds >= trackDuration - 0.5 {
                    self.handleTrackFinished()
                }
            }
        }
        #endif
    }

    private func handleTrackFinished() {
        guard let session = session else { return }

        if currentTrackIndex + 1 < session.audioTracks.count {
            print("[Player] Transitioning to next track: \(currentTrackIndex + 1)")
            loadTrack(index: currentTrackIndex + 1, seekTimeWithinTrack: 0)
        } else {
            print("[Player] Reached the end of the last track.")
            pause()
            seek(to: duration)
        }
    }

    #if !SKIP && !os(Android)
    private func setupNowPlayingInfo(for session: PlaybackSession) {
        var nowPlayingInfo = [String: Any]()
        nowPlayingInfo[MPMediaItemPropertyTitle] = session.displayTitle
        nowPlayingInfo[MPMediaItemPropertyArtist] = session.displayAuthor
        nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = session.duration
        nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = currentTime
        nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = playbackRate
        
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
    }

    private func updateNowPlaying(rate: Float? = nil, elapsedTime: TimeInterval? = nil) {
        var info = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? [String: Any]()
        if let rate = rate {
            info[MPNowPlayingInfoPropertyPlaybackRate] = rate
        }
        if let elapsed = elapsedTime {
            info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = elapsed
        }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }

    private func setupRemoteCommandCenter() {
        let commandCenter = MPRemoteCommandCenter.shared()

        commandCenter.playCommand.isEnabled = true
        commandCenter.playCommand.addTarget { [weak self] event in
            self?.play()
            return .success
        }

        commandCenter.pauseCommand.isEnabled = true
        commandCenter.pauseCommand.addTarget { [weak self] event in
            self?.pause()
            return .success
        }

        commandCenter.skipForwardCommand.isEnabled = true
        commandCenter.skipForwardCommand.preferredIntervals = [30]
        commandCenter.skipForwardCommand.addTarget { [weak self] event in
            self?.skipForward(30)
            return .success
        }

        commandCenter.skipBackwardCommand.isEnabled = true
        commandCenter.skipBackwardCommand.preferredIntervals = [10]
        commandCenter.skipBackwardCommand.addTarget { [weak self] event in
            self?.skipBackward(10)
            return .success
        }
    }
    #endif

    // MARK: - Progress Syncing

    private func startSyncTimer() {
        stopSyncTimer()
        
        // Sync every 15 seconds
        progressSyncTimer = Timer.scheduledTimer(withTimeInterval: 15.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.syncProgress()
            }
        }
    }

    private func stopSyncTimer() {
        progressSyncTimer?.invalidate()
        progressSyncTimer = nil
    }

    private func syncProgress() {
        guard let session = session else { return }
        
        let elapsedListened = currentTime - lastSyncedTime
        guard elapsedListened >= 1.0 || abs(elapsedListened) > 5.0 else { return }

        lastSyncedTime = currentTime
        
        Task {
            do {
                try await AudiobookshelfAPI.shared.syncProgress(
                    sessionId: session.id,
                    currentTime: currentTime,
                    duration: duration,
                    timeListened: elapsedListened > 0 ? elapsedListened : 0
                )
                print("[Player] Synced progress to server: \(currentTime)s / \(duration)s")
            } catch {
                print("[Player] Progress sync failed: \(error)")
            }
        }
    }

    private func syncProgressImmediately() {
        syncProgress()
    }

    // MARK: - URL Resolver

    private func getFullTrackURL(from trackPath: String, libraryItemId: String? = nil) -> URL? {
        if let bookId = libraryItemId,
           let localURL = DownloadService.shared.getLocalTrackURL(bookId: bookId, trackPath: trackPath) {
            print("[Player] Redirected streaming to local downloaded file: \(localURL)")
            return localURL
        }

        let baseURL = AudiobookshelfAPI.shared.baseURL
        let token = AudiobookshelfAPI.shared.accessToken

        let fullPath: String
        if trackPath.hasPrefix("http") {
            fullPath = trackPath
        } else {
            fullPath = baseURL + (trackPath.hasPrefix("/") ? "" : "/") + trackPath
        }

        guard var components = URLComponents(string: fullPath) else {
            return URL(string: fullPath)
        }

        var queryItems = components.queryItems ?? []
        if !queryItems.contains(where: { $0.name == "token" }) {
            queryItems.append(URLQueryItem(name: "token", value: token))
        }
        components.queryItems = queryItems
        return components.url
    }

    // MARK: - Sleep Timer

    public func startSleepTimer(duration: TimeInterval) {
        stopSleepTimer()
        sleepTimerRemaining = duration
        sleepTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self = self else { return }
                if let remaining = self.sleepTimerRemaining {
                    if remaining <= 1.0 {
                        self.pause()
                        self.stopSleepTimer()
                    } else {
                        self.sleepTimerRemaining = remaining - 1.0
                    }
                }
            }
        }
    }

    public func stopSleepTimer() {
        sleepTimer?.invalidate()
        sleepTimer = nil
        sleepTimerRemaining = nil
    }
}

public final class ProMotionManager: ObservableObject, Sendable {
    public static let shared = ProMotionManager()
    public init() {}
    public func enableHighPerformanceMode() {
        #if os(iOS)
        print("[ProMotion] High performance mode enabled")
        #endif
    }
    
    public func optimizedSpring(response: Double = 0.3, dampingFraction: Double = 0.8) -> Animation {
        return .spring(response: response, dampingFraction: dampingFraction)
    }
}
