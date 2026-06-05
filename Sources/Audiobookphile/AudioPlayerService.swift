//
//  AudioPlayerService.swift
//  Audiobookphile
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
    private var playerItemObserverToken: Any?
    #endif
    
    private var progressSyncTimer: Timer?
    private var lastSyncedTime: TimeInterval = 0

    private init() {
        #if os(iOS)
        setupAudioSession()
        
        NotificationCenter.default.addObserver(forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in
                self?.syncProgressImmediately()
            }
        }
        
        NotificationCenter.default.addObserver(forName: UIApplication.willTerminateNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in
                self?.syncProgressImmediately()
            }
        }
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

        print("[Player] startPlayback called - session id: \(session.id)")
        print("[Player] duration: \(session.duration), currentTime: \(session.currentTime), tracks: \(session.audioTracks.count)")
        // Write debug info to file for diagnostics
        var debugInfo = "[Player] startPlayback called\n"
        debugInfo += "Session ID: \(session.id)\n"
        debugInfo += "Duration: \(session.duration)\n"
        debugInfo += "CurrentTime: \(session.currentTime)\n"
        debugInfo += "PlaybackRate: \(session.playbackRate)\n"
        debugInfo += "LibraryItemId: \(session.libraryItemId)\n"
        debugInfo += "Track count: \(session.audioTracks.count)\n"
        for (i, track) in session.audioTracks.enumerated() {
            debugInfo += "Track[\(i)]: contentUrl=\(track.contentUrl), duration=\(track.duration), startOffset=\(track.startOffset)\n"
        }
        let debugPath = NSTemporaryDirectory() + "audiobookphile_playback_debug.txt"
        try? debugInfo.write(toFile: debugPath, atomically: true, encoding: .utf8)
        print("[Player] Debug info written to: \(debugPath)")

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
        
        let targetTime = max(0, min(time, duration))
        print("[Player] SEEK CALLED: requestedTime=\(time), duration=\(duration), targetTime=\(targetTime)")
        self.currentTime = targetTime
        
        // Find the correct track for targetTime
        var targetTrackIndex = session.audioTracks.count > 0 ? session.audioTracks.count - 1 : 0
        var seekTimeWithinTrack = targetTime

        for (index, track) in session.audioTracks.enumerated() {
            let trackStart = track.startOffset
            let trackEnd = trackStart + track.duration
            if targetTime >= trackStart && targetTime < trackEnd {
                targetTrackIndex = index
                seekTimeWithinTrack = targetTime - trackStart
                print("[Player] SEEK MATCHED TRACK \(index): start=\(trackStart), end=\(trackEnd), seekTimeWithinTrack=\(seekTimeWithinTrack)")
                break
            }
        }
        
        if targetTrackIndex == session.audioTracks.count - 1 && session.audioTracks.count > 0 {
            let trackStart = session.audioTracks[targetTrackIndex].startOffset
            seekTimeWithinTrack = max(0, targetTime - trackStart)
            print("[Player] SEEK FALLBACK TO LAST TRACK \(targetTrackIndex): start=\(trackStart), seekTimeWithinTrack=\(seekTimeWithinTrack)")
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

    public func jumpChapterStart() {
        guard let session = session, !session.chapters.isEmpty else {
            seek(to: 0)
            return
        }
        
        let current = currentTime
        // Find current chapter
        var currentChapterIdx = 0
        for (i, chapter) in session.chapters.enumerated() {
            if current >= chapter.start && current < chapter.end {
                currentChapterIdx = i
                break
            }
        }
        
        // If we are past the last chapter, pretend we are in the last chapter
        if current >= session.chapters.last!.end {
            currentChapterIdx = session.chapters.count - 1
        }
        
        let chapter = session.chapters[currentChapterIdx]
        
        // If we are less than 4 seconds into the chapter, go to previous chapter
        if current - chapter.start <= 4.0 {
            if currentChapterIdx > 0 {
                seek(to: session.chapters[currentChapterIdx - 1].start)
            } else {
                seek(to: 0)
            }
        } else {
            // Otherwise restart current chapter
            seek(to: chapter.start)
        }
    }

    public func jumpNextChapter() {
        guard let session = session, !session.chapters.isEmpty else { return }
        let current = currentTime
        
        for chapter in session.chapters {
            if chapter.start > current + 0.1 { // adding a small delta to avoid rounding issues
                seek(to: chapter.start)
                return
            }
        }
        // If no next chapter found, go to the end
        seek(to: duration)
    }

    public func selectChapter(_ chapter: Chapter) {
        seek(to: chapter.start)
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
        if let token = playerItemObserverToken {
            NotificationCenter.default.removeObserver(token)
            playerItemObserverToken = nil
        }
        player = nil
        #endif

        // Sync final progress
        do {
            try await AudiobookphileAPI.shared.closePlaybackSession(
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
            print("[Player] Error: No playable track URL found for track index \(index). contentUrl was: \(track.contentUrl)")
            return
        }

        print("[Player] Loading track \(index) at resolved URL: \(url)")

        #if !SKIP && !os(Android)
        if let token = timeObserverToken {
            player?.removeTimeObserver(token)
            timeObserverToken = nil
        }
        if let token = playerItemObserverToken {
            NotificationCenter.default.removeObserver(token)
            playerItemObserverToken = nil
        }

        let playerItem = AVPlayerItem(url: url)
        if player == nil {
            player = AVPlayer(playerItem: playerItem)
            setupRemoteCommandCenter()
        } else {
            player?.replaceCurrentItem(with: playerItem)
        }

        // Diagnostic task to check AVPlayerItem status
        Task {
            var statusLog = "Checking AVPlayerItem status for \(url.absoluteString)...\n"
            for i in 0..<10 {
                try? await Task.sleep(nanoseconds: 500_000_000) // 0.5s
                let status = playerItem.status
                let err = playerItem.error
                let logLine = "[\(i*500)ms] Status: \(status.rawValue), Error: \(String(describing: err))\n"
                statusLog += logLine
                print(logLine)
                if status == .failed || status == .readyToPlay {
                    break
                }
            }
            try? statusLog.write(toFile: NSTemporaryDirectory() + "audiobookphile_avplayer_load_error.txt", atomically: true, encoding: .utf8)
        }

        playerItemObserverToken = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: playerItem,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.handleTrackFinished()
            }
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

                var trackDuration = track.duration
                // Fallback to AVPlayerItem duration if API didn't provide one
                if let item = self.player?.currentItem {
                    // Log status to a temp file
                    let statusStr: String
                    switch item.status {
                    case .unknown: statusStr = "unknown"
                    case .readyToPlay: statusStr = "readyToPlay"
                    case .failed: statusStr = "failed (error: \(String(describing: item.error)))"
                    @unknown default: statusStr = "default"
                    }
                    let logMsg = "Player status: \(statusStr), duration: \(item.duration.seconds), isPlaying: \(self.player?.timeControlStatus == .playing)\n"
                    try? logMsg.write(toFile: NSTemporaryDirectory() + "audiobookphile_avplayer_status.txt", atomically: true, encoding: .utf8)
                }

                self.lastSyncedTime = self.currentTime

                // Update track duration if needed (handle estimates)
                trackDuration = self.session?.audioTracks[self.currentTrackIndex].duration ?? track.duration
                if let item = self.player?.currentItem, item.status == .readyToPlay {
                    let itemDur = item.duration.seconds
                    // Update if the track duration is 0, or if the actual duration is significantly different from the estimate
                    if itemDur > 0 && !itemDur.isNaN && (trackDuration <= 0 || abs(itemDur - trackDuration) > 2) {
                        trackDuration = itemDur
                        
                        // Update session track durations and offsets to enable accurate seeking
                        self.session?.audioTracks[self.currentTrackIndex].duration = itemDur
                        
                        var currentOffset: TimeInterval = 0
                        if let tracks = self.session?.audioTracks {
                            for i in 0..<tracks.count {
                                self.session?.audioTracks[i].startOffset = currentOffset
                                currentOffset += self.session?.audioTracks[i].duration ?? 0
                            }
                            self.duration = currentOffset
                        }
                    }
                }

                if trackDuration > 0 && time.seconds >= trackDuration - 0.5 {
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

    private let offlineProgressQueueKey = "abs_offlineProgressQueue"
    
    private func queueOfflineProgress(item: ProgressSyncQueueItem) {
        var queue = getOfflineProgressQueue()
        // If we already have a pending sync for this session, replace it with the latest one
        if let idx = queue.firstIndex(where: { $0.sessionId == item.sessionId }) {
            queue[idx] = item
        } else {
            queue.append(item)
        }
        if let data = try? JSONEncoder().encode(queue) {
            UserDefaults.standard.set(data, forKey: offlineProgressQueueKey)
        }
        print("[Player] Queued offline progress for session \(item.sessionId)")
    }
    
    private func getOfflineProgressQueue() -> [ProgressSyncQueueItem] {
        if let data = UserDefaults.standard.data(forKey: offlineProgressQueueKey),
           let queue = try? JSONDecoder().decode([ProgressSyncQueueItem].self, from: data) {
            return queue
        }
        return []
    }
    
    private func flushOfflineProgressQueue() {
        let queue = getOfflineProgressQueue()
        guard !queue.isEmpty else { return }
        guard NetworkMonitor.shared.isConnected else { return }
        
        print("[Player] Flushing \(queue.count) offline progress items")
        Task {
            var failedItems: [ProgressSyncQueueItem] = []
            for item in queue {
                do {
                    try await AudiobookphileAPI.shared.syncProgress(
                        sessionId: item.sessionId,
                        currentTime: item.currentTime,
                        duration: item.duration,
                        timeListened: item.timeListened
                    )
                    print("[Player] Offline sync succeeded for session \(item.sessionId)")
                } catch {
                    print("[Player] Offline sync failed for session \(item.sessionId): \(error)")
                    failedItems.append(item)
                }
            }
            // Save remaining failed items back to queue
            if let data = try? JSONEncoder().encode(failedItems) {
                UserDefaults.standard.set(data, forKey: offlineProgressQueueKey)
            }
        }
    }

    private func startSyncTimer() {
        stopSyncTimer()
        
        // Sync every 15 seconds
        progressSyncTimer = Timer.scheduledTimer(withTimeInterval: 15.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.syncProgress()
                self?.flushOfflineProgressQueue()
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

        let timeListenedToSync = elapsedListened > 0 ? elapsedListened : 0
        lastSyncedTime = currentTime
        
        guard NetworkMonitor.shared.isConnected else {
            print("[Player] Device offline, queueing sync...")
            let item = ProgressSyncQueueItem(sessionId: session.id, currentTime: currentTime, duration: duration, timeListened: timeListenedToSync)
            queueOfflineProgress(item: item)
            return
        }
        
        Task {
            do {
                try await AudiobookphileAPI.shared.syncProgress(
                    sessionId: session.id,
                    currentTime: currentTime,
                    duration: duration,
                    timeListened: timeListenedToSync
                )
                print("[Player] Synced progress to server: \(currentTime)s / \(duration)s")
            } catch {
                print("[Player] Progress sync failed: \(error). Queueing for later.")
                let item = ProgressSyncQueueItem(sessionId: session.id, currentTime: currentTime, duration: duration, timeListened: timeListenedToSync)
                queueOfflineProgress(item: item)
            }
        }
    }

    private func syncProgressImmediately() {
        syncProgress()
        flushOfflineProgressQueue()
    }

    // MARK: - URL Resolver

    private func getFullTrackURL(from trackPath: String, libraryItemId: String? = nil) -> URL? {
        if let bookId = libraryItemId,
           let localURL = DownloadService.shared.getLocalTrackURL(bookId: bookId, trackPath: trackPath) {
            print("[Player] Redirected streaming to local downloaded file: \(localURL)")
            return localURL
        }

        // External pre-signed URLs (e.g. S3) — use as-is, do NOT append token
        // Adding query params to a pre-signed URL invalidates its signature
        if trackPath.hasPrefix("http") {
            return URL(string: trackPath)
        }

        // Relative path to our own server — build full URL with auth token
        let baseURL = AppState.shared.serverURL
        let token = AppState.shared.token

        let fullPath = baseURL + (trackPath.hasPrefix("/") ? "" : "/") + trackPath

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

    
    // MARK: - Bookmarks
    
    private let bookmarksKeyPrefix = "abs_bookmarks_"
    
    public func getBookmarks(for libraryItemId: String) -> [Bookmark] {
        guard let data = UserDefaults.standard.data(forKey: bookmarksKeyPrefix + libraryItemId),
              let bookmarks = try? JSONDecoder().decode([Bookmark].self, from: data) else {
            return []
        }
        return bookmarks.sorted(by: { $0.time < $1.time })
    }
    
    public func addBookmark(title: String) {
        guard let session = session else { return }
        let newBookmark = Bookmark(
            libraryItemId: session.libraryItemId,
            title: title.isEmpty ? "Bookmark at \(formatTime(currentTime))" : title,
            time: currentTime
        )
        
        var currentBookmarks = getBookmarks(for: session.libraryItemId)
        currentBookmarks.append(newBookmark)
        
        if let data = try? JSONEncoder().encode(currentBookmarks) {
            UserDefaults.standard.set(data, forKey: bookmarksKeyPrefix + session.libraryItemId)
        }
    }
    
    public func deleteBookmark(_ bookmark: Bookmark) {
        var currentBookmarks = getBookmarks(for: bookmark.libraryItemId)
        currentBookmarks.removeAll { $0.id == bookmark.id }
        
        if let data = try? JSONEncoder().encode(currentBookmarks) {
            UserDefaults.standard.set(data, forKey: bookmarksKeyPrefix + bookmark.libraryItemId)
        }
    }
    
    private func formatTime(_ time: TimeInterval) -> String {
        let hours = Int(time) / 3600
        let minutes = Int(time) / 60 % 60
        let seconds = Int(time) % 60
        if hours > 0 {
            return String(format: "%i:%02i:%02i", hours, minutes, seconds)
        } else {
            return String(format: "%02i:%02i", minutes, seconds)
        }
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
