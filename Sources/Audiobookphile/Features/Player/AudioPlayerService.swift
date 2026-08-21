import Foundation
#if canImport(OSLog)
import OSLog
#endif
import Observation
import SwiftUI
#if !SKIP && !os(Android)
import AVFoundation
import MediaPlayer
#if os(iOS)
import UIKit
import BackgroundTasks
#endif
#endif

@Observable
@MainActor
public class AudioPlayerService {
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Audiobookphile", category: "AudioPlayer")
    public static let shared = AudioPlayerService()

    public var session: PlaybackSession?
    public var isPlaying = false
    public var isBuffering = false
    public var currentTime: TimeInterval = 0
    public var playbackRate: Float = 1.0
    public var duration: TimeInterval = 0
    public var playbackError: Error?
    // MARK: - Monotonic Seek Transaction Epochs
    /**
     * ── ARCHITECTURAL INVARIANT: PLAYBACK TIMELINE & SEEK INTEGRITY ──
     * 1. Monotonicity: Time updates from periodic observers MUST be rejected 
     *    while an active seek transaction is unresolved (activeSeekEpoch != acknowledgedSeekEpoch).
     * 2. Inclusive Boundaries: Track indexing MUST evaluate the final track
     *    inclusively (`targetTime <= trackEnd`) to prevent 100% end-of-book drops.
     * 3. Transient Guard: While AVPlayerItem buffers, `currentTime` MUST hold
     *    the target seek time and never fall back to `0.0`.
     */
    public private(set) var activeSeekEpoch: UInt64 = 0
    public private(set) var acknowledgedSeekEpoch: UInt64 = 0

    public var isSeeking: Bool {
        activeSeekEpoch != acknowledgedSeekEpoch
    }
    
    private var currentTrackIndex = 0
    private var retryCount = 0
    private var pendingSeekTimeWithinTrack: TimeInterval?

    // Sub-Managers
    public let bookmarkManager = AudioPlayerBookmarkManager()
    public let sleepTimer = AudioPlayerSleepTimer()
    public let syncManager = AudioPlayerSyncManager()
    public let nowPlayingManager = AudioPlayerNowPlayingManager()
    public let engine = AudioPlayerEngine()

    public var bookmarks: [Bookmark] = []
    
    public var sleepTimerRemaining: TimeInterval? {
        sleepTimer.remaining
    }

    private init() {
        #if os(iOS)
        engine.reconfigureAudioSession()
        
        NotificationCenter.default.addObserver(forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in
                self?.syncManager.syncProgressImmediately(getSessionData: { [weak self] in
                    return (self?.session, self?.currentTime ?? 0, self?.duration ?? 0)
                }, onSyncComplete: { [weak self] in
                    self?.syncWidgetState()
                })
                self?.syncManager.enqueueOfflineSyncOnBackground()
            }
        }

        NotificationCenter.default.addObserver(forName: UIApplication.willTerminateNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in
                self?.syncManager.syncProgressImmediately(getSessionData: { [weak self] in
                    return (self?.session, self?.currentTime ?? 0, self?.duration ?? 0)
                }, onSyncComplete: { [weak self] in
                    self?.syncWidgetState()
                })
            }
        }
        #endif

        setupEngineCallbacks()
    }
    
    private func setupEngineCallbacks() {
        engine.onTimeControlStatusChanged = { [weak self] playing, buffering in
            guard let self = self else { return }
            if playing {
                self.isPlaying = true
                self.isBuffering = buffering
                if !buffering { self.retryCount = 0 }
            } else {
                if self.activeSeekEpoch == self.acknowledgedSeekEpoch {
                    self.isPlaying = false
                }
                self.isBuffering = false
            }
            self.syncWidgetState()
        }
        
        engine.onCurrentItemChanged = { [weak self] item in
            self?.handleCurrentItemChanged(item)
        }
        
        engine.onPeriodicTimeUpdate = { [weak self] time in
            self?.handlePeriodicTimeUpdate(time: time)
        }
        
        engine.onItemReady = { [weak self] item in
            self?.handleItemReady(item)
        }
        
        engine.onItemFailed = { [weak self] error in
            self?.handlePlaybackFailure(error: error)
        }
        
        engine.onItemDidPlayToEndTime = { [weak self] _ in
            self?.handleItemDidPlayToEndTime()
        }
        
        engine.onItemStalled = { [weak self] in
            self?.handlePlaybackStalled()
        }
        
        engine.onAudioRouteLost = { [weak self] in
            self?.pause()
        }
        
        engine.onAudioInterruptionBegan = { [weak self] in
            self?.pause()
        }
        
        engine.onAudioInterruptionEnded = { [weak self] shouldResume in
            if shouldResume { self?.play() }
        }
    }
    
    // MARK: - Playback Control
    
    public func closeSession() async {
        if let activeSession = self.session {
            syncManager.recordClosedSession(session: activeSession, syncTime: self.currentTime, syncDuration: self.duration)
            pause()
            syncManager.stopSyncTimer()
            stopSleepTimer()

            #if !SKIP && !os(Android)
            engine.cleanup()
            #endif
            self.session = nil
        }
    }

    public func startPlayback(session: PlaybackSession) {
        if self.session != nil {
            Task {
                await closeSession()
            }
        }

        logger.info("startPlayback called - session id: \(session.id)")

        self.session = session
        self.duration = session.duration
        self.currentTime = session.currentTime
        self.isPlaying = true
        self.bookmarks = []

        Task {
            let fetched = await bookmarkManager.fetchBookmarks(libraryItemId: session.libraryItemId)
            self.bookmarks = fetched
        }

        self.playbackRate = session.playbackRate
        syncManager.setLastSyncedTime(session.currentTime)

        let pendingKey = "pendingSeekTime-\(session.id)"
        if let pendingSeek = UserDefaults.standard.value(forKey: pendingKey) as? TimeInterval {
            self.currentTime = pendingSeek
            UserDefaults.standard.removeObject(forKey: pendingKey)
        }

        let trackInfo = findTrackIndexAndOffset(for: currentTime)
        self.currentTrackIndex = trackInfo.index

        #if !SKIP && !os(Android)
        nowPlayingManager.setupNowPlayingInfo(
            title: session.displayTitle,
            author: session.displayAuthor,
            duration: session.duration,
            currentTime: currentTime,
            playbackRate: playbackRate
        )
        nowPlayingManager.setupRemoteCommandCenter(
            onPlay: { [weak self] in self?.play() },
            onPause: { [weak self] in self?.pause() },
            onSkipForward: { [weak self] interval in self?.skipForward(Int(interval)) },
            onSkipBackward: { [weak self] interval in self?.skipBackward(Int(interval)) },
            onSeek: { [weak self] time in self?.seek(to: time) }
        )
        loadQueue(from: trackInfo.index, seekTimeWithinTrack: trackInfo.offset, autoPlay: true)
        #endif
        self.isPlaying = true
        #if !SKIP && !os(Android)
        nowPlayingManager.updateNowPlaying(rate: playbackRate)
        #endif
        syncWidgetState()
        
        syncManager.startSyncTimer(getSessionData: { [weak self] in
            return (self?.session, self?.currentTime ?? 0, self?.duration ?? 0)
        }, onSyncComplete: { [weak self] in
            self?.syncWidgetState()
        })
    }

    public func play() {
        guard session != nil else { return }
        engine.play(rate: playbackRate)
        isPlaying = true
        #if !SKIP && !os(Android)
        nowPlayingManager.updateNowPlaying(rate: playbackRate, elapsedTime: currentTime)
        #endif
        syncWidgetState()
    }

    public func pause() {
        engine.pause()
        isPlaying = false
        #if !SKIP && !os(Android)
        nowPlayingManager.updateNowPlaying(rate: 0.0, elapsedTime: currentTime)
        #endif
        syncManager.debounceProgressSync(getSessionData: { [weak self] in
            return (self?.session, self?.currentTime ?? 0, self?.duration ?? 0)
        }, onSyncComplete: { [weak self] in
            self?.syncWidgetState()
        })
        syncWidgetState()
    }

    public func togglePlayPause() {
        if isPlaying {
            pause()
        } else {
            play()
        }
    }

    public func skipForward(_ seconds: Int = 15) {
        seek(to: currentTime + TimeInterval(seconds))
    }

    public func skipBackward(_ seconds: Int = 15) {
        seek(to: max(0, currentTime - TimeInterval(seconds)))
    }

    public func setPlaybackRate(_ rate: Float) {
        self.playbackRate = rate
        #if !SKIP && !os(Android)
        if isPlaying {
            engine.play(rate: rate)
            nowPlayingManager.updateNowPlaying(rate: rate, elapsedTime: currentTime)
        }
        #endif
    }

    public func seek(to time: TimeInterval) {
        guard let session = session else { return }

        let targetTime = max(0, min(time, duration))
        self.currentTime = targetTime
        
        activeSeekEpoch &+= 1
        let thisEpoch = activeSeekEpoch
        
        #if !SKIP && !os(Android)
        nowPlayingManager.updateNowPlaying(elapsedTime: targetTime)
        #endif
        
        syncWidgetState()

        let trackInfo = findTrackIndexAndOffset(for: targetTime)

        #if !SKIP && !os(Android)
        if trackInfo.index == currentTrackIndex && engine.currentItem != nil {
            if let item = engine.currentItem as? AVPlayerItem, item.status == .readyToPlay {
                let wasPlaying = self.isPlaying
                let seekId = UUID()
                
                if wasPlaying {
                    engine.pause()
                }
                
                executeSeek(to: trackInfo.offset, seekId: seekId, wasPlaying: wasPlaying, epoch: thisEpoch)
            } else {
                // Item is still loading, defer the seek until it is ready
                self.pendingSeekTimeWithinTrack = trackInfo.offset
            }
        } else {
            loadQueue(from: trackInfo.index, seekTimeWithinTrack: trackInfo.offset, autoPlay: isPlaying, epoch: thisEpoch)
        }
        #endif
        
        syncManager.debounceProgressSync(getSessionData: { [weak self] in
            return (self?.session, self?.currentTime ?? 0, self?.duration ?? 0)
        }, onSyncComplete: { [weak self] in
            self?.syncWidgetState()
        })
    }

    private func findTrackIndexAndOffset(for targetTime: TimeInterval) -> (index: Int, offset: TimeInterval) {
        guard let session = session, !session.audioTracks.isEmpty else { return (0, 0) }
        for (index, track) in session.audioTracks.enumerated() {
            let isLast = index == session.audioTracks.count - 1
            let trackEnd = track.startOffset + track.duration
            if targetTime >= track.startOffset && (isLast ? targetTime <= trackEnd : targetTime < trackEnd) {
                return (index, max(0, targetTime - track.startOffset))
            }
        }
        let lastIdx = session.audioTracks.count - 1
        let track = session.audioTracks[lastIdx]
        let offset = max(0, targetTime - track.startOffset)
        return (lastIdx, offset)
    }

    // MARK: - Queue & Engine Handling
    
    private func loadQueue(from index: Int, seekTimeWithinTrack: TimeInterval, autoPlay: Bool = true, epoch: UInt64? = nil) {
        guard let session = session else { return }
        guard index >= 0 && index < session.audioTracks.count else { return }

        self.currentTrackIndex = index
        self.pendingSeekTimeWithinTrack = seekTimeWithinTrack

        #if !SKIP && !os(Android)
        engine.initializePlayer()
        if autoPlay {
            self.isPlaying = true
        }
        topUpQueue(from: index)
        #endif
    }

    private func topUpQueue(from startIndex: Int? = nil) {
        guard let session = session else { return }
        #if !SKIP && !os(Android)
        var lastIdx = currentTrackIndex - 1
        if let start = startIndex {
            lastIdx = start - 1
        }

        let maxQueuedItems = 3
        while engine.queuedItemsCount < maxQueuedItems {
            let nextIndex = lastIdx + 1
            guard nextIndex < session.audioTracks.count else { break }
            lastIdx = nextIndex

            if let item = makePlayerItem(for: nextIndex) {
                engine.insertItem(item)
            } else {
                logger.error("Failed to create AVPlayerItem for track index \(nextIndex)")
                TelemetryService.shared.captureMessage("Failed to create AVPlayerItem for track index \(nextIndex)", level: .warning, tags: ["area": "player"])
            }
        }
        #endif
    }
    
    private func makePlayerItem(for index: Int) -> AVPlayerItem? {
        guard let session = session, index >= 0 && index < session.audioTracks.count else { return nil }
        let track = session.audioTracks[index]
        guard let url = getFullTrackURL(from: track.contentUrl, libraryItemId: session.libraryItemId) else {
            return nil
        }
        
        let options: [String: Any] = [AVURLAssetPreferPreciseDurationAndTimingKey: false]
        let asset = AVURLAsset(url: url, options: options)
        let item = AVPlayerItem(asset: asset)
        item.preferredForwardBufferDuration = 60.0
        #if os(iOS)
        item.audioTimePitchAlgorithm = .spectral
        if #available(iOS 15.0, *) {
            item.allowedAudioSpatializationFormats = [.monoAndStereo, .multichannel]
        }
        #endif
        return item
    }

    private func getFullTrackURL(from trackPath: String, libraryItemId: String? = nil) -> URL? {
        let trimmedPath = trackPath.trimmingCharacters(in: .whitespacesAndNewlines)
        if let bookId = libraryItemId,
           let localURL = DownloadService.shared.getLocalTrackURL(bookId: bookId, trackPath: trimmedPath) {
            return localURL
        }

        var finalURLString = ""
        if trimmedPath.hasPrefix("http") {
            finalURLString = trimmedPath
        } else if trimmedPath.hasPrefix("/") {
            let base = UserDefaults.standard.string(forKey: "abp_serverURL") ?? ""
            finalURLString = base + trimmedPath
        } else {
            return nil
        }
        
        guard var components = URLComponents(string: finalURLString) ?? URLComponents(string: finalURLString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "") else {
            return nil
        }
        
        let token = AppState.shared.token
        if !token.isEmpty && !trimmedPath.hasPrefix("http") {
            var queryItems = components.queryItems ?? []
            if !queryItems.contains(where: { $0.name == "token" }) {
                queryItems.append(URLQueryItem(name: "token", value: token))
            }
            components.queryItems = queryItems
        }
        
        return components.url
    }

    // MARK: - Callbacks

    private func handleCurrentItemChanged(_ item: AVPlayerItem?) {
        guard let session = session else { return }
        guard let item = item else {
            if isPlaying && currentTrackIndex >= session.audioTracks.count - 1 && activeSeekEpoch == acknowledgedSeekEpoch {
                handleItemDidPlayToEndTime()
            }
            return
        }

        if let asset = item.asset as? AVURLAsset,
           let matchedIndex = session.audioTracks.firstIndex(where: {
               getFullTrackURL(from: $0.contentUrl, libraryItemId: session.libraryItemId) == asset.url
           }) {
            if matchedIndex != currentTrackIndex {
                currentTrackIndex = matchedIndex
            }
        }

        topUpQueue()
        #if !SKIP && !os(Android)
        nowPlayingManager.updateNowPlaying(rate: isPlaying ? playbackRate : 0.0, elapsedTime: currentTime)
        #endif
    }
    
    private func handlePeriodicTimeUpdate(time: CMTime) {
        guard isPlaying, activeSeekEpoch == acknowledgedSeekEpoch, let session = session, currentTrackIndex < session.audioTracks.count else { return }
        let track = session.audioTracks[currentTrackIndex]
        let absoluteTime = track.startOffset + time.seconds
        self.currentTime = absoluteTime

        #if !SKIP && !os(Android)
        nowPlayingManager.updateNowPlaying(elapsedTime: absoluteTime)
        #endif

        if let item = engine.currentItem as? AVPlayerItem, item.status == .readyToPlay {
            let itemDur = item.duration.seconds
            if itemDur > 0 && !itemDur.isNaN && (track.duration <= 0 || abs(itemDur - track.duration) > 2) {
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
    }

    private func handleItemReady(_ item: AVPlayerItem) {
        if let pendingSeek = self.pendingSeekTimeWithinTrack {
            self.pendingSeekTimeWithinTrack = nil
            let seekId = UUID()
            let thisEpoch = self.activeSeekEpoch
            
            if pendingSeek > 0.01 {
                executeSeek(to: pendingSeek, seekId: seekId, wasPlaying: self.isPlaying, epoch: thisEpoch)
            } else {
                if self.activeSeekEpoch == thisEpoch {
                    self.acknowledgedSeekEpoch = thisEpoch
                }
                if self.isPlaying {
                    self.play()
                }
            }
        } else {
            if self.activeSeekEpoch == self.acknowledgedSeekEpoch {
                // Already in sync
            } else {
                self.acknowledgedSeekEpoch = self.activeSeekEpoch
            }
            if self.isPlaying {
                self.play()
            }
        }
    }
    
    private func executeSeek(to targetTimeWithinTrack: TimeInterval, seekId: UUID, wasPlaying: Bool, epoch: UInt64? = nil, retryCount: Int = 0) {
        let cmTime = CMTime(seconds: targetTimeWithinTrack, preferredTimescale: 600)
        let targetEpoch = epoch ?? self.activeSeekEpoch
        
        #if !SKIP && !os(Android)
        if let item = engine.currentItem as? AVPlayerItem {
            if item.status == .failed {
                if self.activeSeekEpoch == targetEpoch {
                    self.acknowledgedSeekEpoch = targetEpoch
                }
                return
            }
            if item.seekableTimeRanges.isEmpty {
                if retryCount < 50 {
                    Task { @MainActor in
                        try? await Task.sleep(nanoseconds: 100_000_000)
                        if self.activeSeekEpoch == targetEpoch {
                            self.executeSeek(to: targetTimeWithinTrack, seekId: seekId, wasPlaying: wasPlaying, epoch: targetEpoch, retryCount: retryCount + 1)
                        }
                    }
                    return
                }
            }
        }
        #endif

        engine.seek(to: cmTime) { [weak self] finished in
            Task { @MainActor in
                guard let self = self else { return }
                guard self.activeSeekEpoch == targetEpoch else { return } // A newer seek transaction was started
                
                if finished {
                    self.acknowledgedSeekEpoch = targetEpoch
                    if wasPlaying { self.play() }
                } else {
                    if retryCount < 50 {
                        Task {
                            try? await Task.sleep(nanoseconds: 100_000_000)
                            if self.activeSeekEpoch == targetEpoch {
                                self.executeSeek(to: targetTimeWithinTrack, seekId: seekId, wasPlaying: wasPlaying, epoch: targetEpoch, retryCount: retryCount + 1)
                            }
                        }
                    } else {
                        self.acknowledgedSeekEpoch = targetEpoch
                        if wasPlaying { self.play() }
                    }
                }
            }
        }
    }

    private func handlePlaybackFailure(error: Error?) {
        guard let session = session else { return }
        if retryCount < 3 {
            retryCount += 1
            let delay = Double(retryCount) * 1.5
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                guard self.session?.id == session.id else { return }
                let track = session.audioTracks[self.currentTrackIndex]
                let seekTime = max(0, self.currentTime - track.startOffset)
                self.loadQueue(from: self.currentTrackIndex, seekTimeWithinTrack: seekTime, autoPlay: self.isPlaying)
            }
        } else {
            retryCount = 0
            pause()
            self.acknowledgedSeekEpoch = self.activeSeekEpoch
            Task { @MainActor in
                self.playbackError = error ?? NSError(domain: "AudioPlayerServiceErrorDomain", code: -1, userInfo: [NSLocalizedDescriptionKey: "Audio stream failed repeatedly."])
            }
        }
    }

    private func handlePlaybackStalled() {
        guard isPlaying else { return }
        isBuffering = true
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            if self.isBuffering && self.isPlaying {
                if self.engine.currentItem == nil {
                    self.playbackError = NSError(domain: "AudioPlayerServiceErrorDomain", code: -2, userInfo: [NSLocalizedDescriptionKey: "Audio stream stalled completely."])
                    self.pause()
                } else {
                    self.engine.play(rate: self.playbackRate)
                }
            }
        }
    }

    private func handleItemDidPlayToEndTime() {
        guard let session = self.session else { return }
        if self.currentTrackIndex >= session.audioTracks.count - 1 {
            self.pause()
            self.currentTime = self.duration
            self.syncManager.syncProgressImmediately(getSessionData: { [weak self] in
                return (self?.session, self?.currentTime ?? 0, self?.duration ?? 0)
            }, onSyncComplete: { [weak self] in
                self?.syncWidgetState()
            })
            self.syncWidgetState()
        }
    }

    // MARK: - Bookmarks

    public func addBookmark(title: String) {
        guard let session = session else { return }
        let timePos = currentTime
        let bookmarkTitle = title.isEmpty ? "Bookmark at \(currentTime)" : title

        let temp = Bookmark(id: UUID().uuidString, userId: AppState.shared.currentUser?.id ?? "", libraryItemId: session.libraryItemId, timePos: timePos, title: bookmarkTitle, createdAt: Date())
        self.bookmarks.append(temp)
        self.bookmarks.sort(by: { $0.timePos < $1.timePos })

        Task {
            if let saved = await bookmarkManager.addBookmark(title: title, currentTime: timePos, libraryItemId: session.libraryItemId) {
                if let idx = self.bookmarks.firstIndex(where: { $0.id == temp.id }) {
                    self.bookmarks[idx] = saved
                } else {
                    self.bookmarks.append(saved)
                    self.bookmarks.sort(by: { $0.timePos < $1.timePos })
                }
            } else {
                self.bookmarks.removeAll(where: { $0.id == temp.id })
            }
        }
    }

    public func deleteBookmark(_ bookmark: Bookmark) {
        guard let session = session else { return }
        self.bookmarks.removeAll { $0.id == bookmark.id }
        Task {
            let success = await bookmarkManager.deleteBookmark(bookmark, libraryItemId: session.libraryItemId)
            if !success {
                self.bookmarks.append(bookmark)
                self.bookmarks.sort(by: { $0.timePos < $1.timePos })
            }
        }
    }

    // MARK: - Sleep Timer

    public func startSleepTimer(duration: TimeInterval) {
        sleepTimer.setSleepTimer(minutes: Int(duration / 60)) { [weak self] in
            self?.pause()
        }
    }

    public func stopSleepTimer() {
        sleepTimer.stopSleepTimer()
    }

    // MARK: - Sync Passthroughs
    
    public func flushOfflineProgressQueue() async {
        await syncManager.flushOfflineProgressQueue()
    }
    
    // MARK: - Engine Passthroughs
    
    public func applyAudioDSP() {
        engine.applyAudioDSP()
    }
    
    public func reconfigureAudioSession() {
        engine.reconfigureAudioSession()
    }

    // MARK: - Widget State Sync

    private func syncWidgetState() {
        guard let session = session, let defaults = UserDefaults(suiteName: EnvironmentConfig.appGroupIdentifier) else { return }

        var currentChapterName = "Reading"
        for chapter in session.chapters {
            if currentTime >= chapter.start && currentTime < chapter.end {
                currentChapterName = chapter.title
                break
            }
        }

        let stateDict: [String: Any] = [
            "bookTitle": session.displayTitle,
            "author": session.displayAuthor,
            "chapterName": currentChapterName,
            "progress": currentTime,
            "duration": duration,
            "isPlaying": isPlaying,
            "updatedAt": Date().timeIntervalSince1970
        ]
        defaults.set(stateDict, forKey: "audiobookWidgetState")
    }
}

@Observable
public final class ProMotionManager: @unchecked Sendable {
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
