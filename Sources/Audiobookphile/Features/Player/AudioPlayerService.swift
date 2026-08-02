//
//  AudioPlayerService.swift
//  Audiobookphile
//
//  Playback state coordinator with background audio, lock screen controls, and progress sync.
//

import Foundation
import OSLog
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
    public var currentTime: TimeInterval = 0
    public var duration: TimeInterval = 0
    public var playbackRate: Float = 1.0
    public var isBuffering = false
    public var sleepTimerRemaining: TimeInterval?
    public var bookmarks: [Bookmark] = []
    private var sleepTimer: Timer?

    private var currentTrackIndex = 0

    private var retryCount = 0
    private var lastQueuedIndex: Int = -1
    private var pendingSeekTimeWithinTrack: TimeInterval?

    #if !SKIP && !os(Android)
    private var player: AVQueuePlayer?
    private var timeObserverToken: Any?
    private var playerItemObserverToken: Any?
    private var playerFailedObserverToken: Any?
    private var playerStalledObserverToken: Any?
    private var timeControlStatusObserver: NSKeyValueObservation?
    private var currentItemObserver: NSKeyValueObservation?
    private var currentItemStatusObserver: NSKeyValueObservation?
    private var eqUnit: AVAudioUnitEQ?
    #endif

    private var progressSyncTimer: Timer?
    private var lastSyncedTime: TimeInterval = 0

    private init() {
        #if os(iOS)
        setupAudioSession()

        NotificationCenter.default.addObserver(forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in
                self?.syncProgressImmediately()

                let queue = self?.getOfflineProgressQueue() ?? []
                if !queue.isEmpty {
                    let request = BGProcessingTaskRequest(identifier: "club.foodshare.audiobookphile.progress-sync")
                    request.requiresNetworkConnectivity = true
                    request.requiresExternalPower = false
                    do {
                        try BGTaskScheduler.shared.submit(request)
                        self?.logger.info("Submitted BGTaskScheduler request for \(queue.count) offline items.")
                    } catch {
                        self?.logger.error("Could not schedule BGTask: \(error)")
                    }
                }
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
        if let activeSession = self.session {
            let syncId = activeSession.id
            let episodeId = activeSession.episodeId
            let syncTime = self.currentTime
            let syncDuration = self.duration
            let timeListened = max(0, self.currentTime - self.lastSyncedTime)

            pause()
            stopSyncTimer()
            stopSleepTimer()

            #if !SKIP && !os(Android)
            cleanupPlayer()
            #endif
            self.session = nil

            #if os(iOS)
            var bgTask: UIBackgroundTaskIdentifier = .invalid
            bgTask = UIApplication.shared.beginBackgroundTask(withName: "closePlaybackSession") {
                UIApplication.shared.endBackgroundTask(bgTask)
                bgTask = .invalid
            }
            #endif

            Task {
                do {
                    try await AudiobookphileAPI.shared.closePlaybackSession(
                        sessionId: syncId,
                        episodeId: episodeId,
                        currentTime: syncTime,
                        duration: syncDuration,
                        timeListened: timeListened
                    )
                } catch {
                    logger.error("Failed to close session on startPlayback: \(error). Queueing for offline sync.")
                    let item = ProgressSyncQueueItem(sessionId: syncId, episodeId: episodeId, currentTime: syncTime, duration: syncDuration, timeListened: timeListened)
                    queueOfflineProgress(item: item)
                }

                #if os(iOS)
                if bgTask != .invalid {
                    UIApplication.shared.endBackgroundTask(bgTask)
                }
                #endif
            }
        }

        logger.info("startPlayback called - session id: \(session.id)")
        logger.info("duration: \(session.duration), currentTime: \(session.currentTime), tracks: \(session.audioTracks.count)")

        // Write debug info to file for diagnostics asynchronously to avoid blocking MainActor
        Task.detached {
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
            self.logger.info("Debug info written to: \(debugPath)")
        }

        self.session = session
        self.duration = session.duration
        self.currentTime = session.currentTime
        self.isPlaying = true
        self.bookmarks = []

        Task {
            do {
                self.bookmarks = try await AudiobookphileAPI.shared.fetchBookmarks(libraryItemId: session.libraryItemId)
            } catch {
                self.logger.error("Failed to fetch bookmarks: \(error)")
            }
        }

        self.playbackRate = session.playbackRate
        self.lastSyncedTime = session.currentTime

        // Check if there is a pending seek time from e.g. chapter selection in BookDetailView
        let pendingKey = "pendingSeekTime-\(session.id)"
        if let pendingSeek = UserDefaults.standard.value(forKey: pendingKey) as? TimeInterval {
            self.currentTime = pendingSeek
            UserDefaults.standard.removeObject(forKey: pendingKey)
        }

        // Find the correct starting track index and offset based on currentTime
        let trackInfo = findTrackIndexAndOffset(for: currentTime)
        self.currentTrackIndex = trackInfo.index

        #if !SKIP && !os(Android)
        setupNowPlayingInfo(for: session)
        loadQueue(from: trackInfo.index, seekTimeWithinTrack: trackInfo.offset, autoPlay: true)
        #endif
        self.isPlaying = true
        updateNowPlaying(rate: playbackRate)
        syncWidgetState()
        startSyncTimer()
    }

    public func play() {
        guard session != nil else { return }

        #if !SKIP && !os(Android)
        reconfigureAudioSession()
        if let currentItem = player?.currentItem {
            if currentItem.status == .readyToPlay {
                player?.play()
                player?.rate = playbackRate
            }
        } else if session != nil {
            let trackInfo = findTrackIndexAndOffset(for: currentTime)
            loadQueue(from: trackInfo.index, seekTimeWithinTrack: trackInfo.offset, autoPlay: true)
        }
        #endif

        isPlaying = true

        #if os(iOS)
        if UIAccessibility.isVoiceOverRunning {
            UIAccessibility.post(notification: .announcement, argument: "Playing")
        }
        #endif

        #if !SKIP && !os(Android)
        updateNowPlaying(rate: playbackRate)
        #endif

        syncWidgetState()
    }

    public func pause() {
        #if !SKIP && !os(Android)
        player?.pause()
        #endif

        isPlaying = false
        isBuffering = false
        retryCount = 0

        #if os(iOS)
        if UIAccessibility.isVoiceOverRunning {
            UIAccessibility.post(notification: .announcement, argument: "Paused")
        }
        #endif

        #if !SKIP && !os(Android)
        updateNowPlaying(rate: 0)
        #endif

        // Sync progress immediately on pause
        syncProgressImmediately()
        syncWidgetState()
    }

    public func togglePlayPause() {
        if isPlaying {
            pause()
        } else {
            play()
        }
    }

    private func findTrackIndexAndOffset(for time: TimeInterval) -> (index: Int, offset: TimeInterval) {
        guard let session = session, !session.audioTracks.isEmpty else { return (0, time) }
        let targetTime = max(0, min(time, duration))
        for (index, track) in session.audioTracks.enumerated() {
            let trackStart = track.startOffset
            let trackEnd = trackStart + track.duration
            if targetTime >= trackStart && targetTime < trackEnd {
                return (index, targetTime - trackStart)
            }
        }
        let lastIndex = session.audioTracks.count - 1
        let lastTrackStart = session.audioTracks[lastIndex].startOffset
        return (lastIndex, max(0, targetTime - lastTrackStart))
    }

    public func seek(to time: TimeInterval) {
        guard let session = session else { return }

        let targetTime = max(0, min(time, duration))
        self.logger.info("SEEK CALLED: requestedTime=\(time), duration=\(self.duration), targetTime=\(targetTime)")
        self.currentTime = targetTime

        // Find the correct track for targetTime
        var targetTrackIndex = session.audioTracks.count > 0 ? session.audioTracks.count - 1 : 0
        var seekTimeWithinTrack = targetTime
        var matched = false

        for (index, track) in session.audioTracks.enumerated() {
            let trackStart = track.startOffset
            let trackEnd = trackStart + track.duration
            if targetTime >= trackStart && targetTime < trackEnd {
                targetTrackIndex = index
                seekTimeWithinTrack = targetTime - trackStart
                matched = true
                logger.info("SEEK MATCHED TRACK \(index): start=\(trackStart), end=\(trackEnd), seekTimeWithinTrack=\(seekTimeWithinTrack)")
                break
            }
        }

        if !matched && session.audioTracks.count > 0 {
            targetTrackIndex = session.audioTracks.count - 1
            let trackStart = session.audioTracks[targetTrackIndex].startOffset
            seekTimeWithinTrack = max(0, targetTime - trackStart)
            logger.info("SEEK FALLBACK TO LAST TRACK \(targetTrackIndex): start=\(trackStart), seekTimeWithinTrack=\(seekTimeWithinTrack)")
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
            loadQueue(from: targetTrackIndex, seekTimeWithinTrack: seekTimeWithinTrack, autoPlay: isPlaying)
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
            interval = TimeInterval(AppState.shared.settings.jumpForwardTime)
        }
        seek(to: currentTime + interval)
    }

    public func skipBackward(_ seconds: TimeInterval = 10) {
        let interval: TimeInterval
        if seconds != 10 {
            interval = seconds
        } else {
            interval = TimeInterval(AppState.shared.settings.jumpBackwardsTime)
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

        let syncId = activeSession.id
        let episodeId = activeSession.episodeId
        let syncTime = currentTime
        let syncDuration = duration
        let timeListened = max(0, currentTime - lastSyncedTime)

        pause()
        stopSyncTimer()
        stopSleepTimer()

        #if !SKIP && !os(Android)
        cleanupPlayer()
        #endif
        self.session = nil

        // Sync final progress
        #if os(iOS)
        var bgTask: UIBackgroundTaskIdentifier = .invalid
        bgTask = UIApplication.shared.beginBackgroundTask(withName: "closeSession") {
            UIApplication.shared.endBackgroundTask(bgTask)
            bgTask = .invalid
        }
        #endif

        do {
            try await AudiobookphileAPI.shared.closePlaybackSession(
                sessionId: syncId,
                episodeId: episodeId,
                currentTime: syncTime,
                duration: syncDuration,
                timeListened: timeListened
            )
            logger.info("Playback session closed successfully on server.")
        } catch {
            logger.error("Failed to close session on server: \(error). Queueing for offline sync.")
            let item = ProgressSyncQueueItem(sessionId: syncId, episodeId: episodeId, currentTime: syncTime, duration: syncDuration, timeListened: timeListened)
            queueOfflineProgress(item: item)
        }

        #if os(iOS)
        if bgTask != .invalid {
            UIApplication.shared.endBackgroundTask(bgTask)
        }
        #endif
    }

    // MARK: - iOS Specific Player Setup

    // MARK: - Native Audio Setup & DSP

    public func reconfigureAudioSession() {
        #if os(iOS)
        do {
            let audioSession = AVAudioSession.sharedInstance()
            let mode: AVAudioSession.Mode = AppState.shared.settings.spokenAudioModeEnabled ? .spokenAudio : .default
            try audioSession.setCategory(
                .playback,
                mode: mode,
                options: [.allowBluetooth, .allowBluetoothA2DP, .allowAirPlay, .defaultToSpeaker]
            )

            if AppState.shared.settings.highResAudioEnabled {
                try? audioSession.setPreferredSampleRate(48000.0)
                try? audioSession.setPreferredIOBufferDuration(0.005)
            }

            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
            logger.info("AVAudioSession configured: mode=\(mode == .spokenAudio ? "spokenAudio" : "default"), highRes=\(AppState.shared.settings.highResAudioEnabled).")
        } catch {
            logger.error("Failed to configure AVAudioSession: \(error)")
        }
        #endif
    }

    private func setupAudioSession() {
        reconfigureAudioSession()
        setupAudioObservers()
    }

    private func setupAudioObservers() {
        #if os(iOS)
        // Auto-pause when headphones / AirPods disconnect (route change)
        NotificationCenter.default.addObserver(
            forName: AVAudioSession.routeChangeNotification,
            object: AVAudioSession.sharedInstance(),
            queue: .main
        ) { [weak self] notification in
            let reasonValue = notification.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt
            Task { @MainActor in
                guard let self = self,
                      let reasonValue = reasonValue,
                      let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue) else {
                    return
                }

                if reason == .oldDeviceUnavailable {
                    self.logger.info("Hardware audio route lost (e.g. AirPods disconnected). Pausing playback.")
                    self.pause()
                }
            }
        }

        // Handle phone call and Siri audio interruptions
        NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance(),
            queue: .main
        ) { [weak self] notification in
            let typeValue = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt
            let optionsValue = notification.userInfo?[AVAudioSessionInterruptionOptionKey] as? UInt
            Task { @MainActor in
                guard let self = self,
                      let typeValue = typeValue,
                      let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
                    return
                }

                switch type {
                case .began:
                    self.logger.info("Audio interruption began (e.g. incoming call). Pausing playback.")
                    self.pause()
                case .ended:
                    if let optionsValue = optionsValue {
                        let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
                        if options.contains(.shouldResume) {
                            self.logger.info("Audio interruption ended with shouldResume. Resuming playback.")
                            self.play()
                        }
                    }
                @unknown default:
                    break
                }
            }
        }

        // System Mono Audio Accessibility Observer
        NotificationCenter.default.addObserver(
            forName: UIAccessibility.monoAudioStatusDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                let isMono = UIAccessibility.isMonoAudioEnabled
                self?.logger.info("System Mono Audio status changed: \(isMono)")
            }
        }
        #endif
    }

    #if !SKIP && !os(Android)
    private var reverbUnit: AVAudioUnitReverb?
    #endif

    public func applyAudioDSP() {
        #if !SKIP && !os(Android)
        if eqUnit == nil {
            setupAudioEngineDSP()
        }

        guard let eq = eqUnit else { return }
        let settings = AppState.shared.settings
        eq.bands[0].bypass = !settings.lowCutFilterEnabled
        eq.bands[1].bypass = !settings.vocalBoostEnabled
        eq.bands[2].bypass = !settings.deEsserEnabled
        eq.bands[3].bypass = !settings.volumeLevelerEnabled

        if reverbUnit == nil {
            let reverb = AVAudioUnitReverb()
            reverb.loadFactoryPreset(.smallRoom)
            reverb.wetDryMix = 0.0
            self.reverbUnit = reverb
        }
        if let reverb = reverbUnit {
            let presets: [AVAudioUnitReverbPreset] = [.smallRoom, .mediumRoom, .mediumHall]
            let preset = presets[min(max(0, settings.binauralReverbPresetRaw), presets.count - 1)]
            reverb.loadFactoryPreset(preset)
            reverb.wetDryMix = settings.binauralReverbEnabled ? 18.0 : 0.0
        }

        logger.info("Live Audio DSP Filter state updated: lowCut=\(!eq.bands[0].bypass), vocalBoost=\(!eq.bands[1].bypass), deEsser=\(!eq.bands[2].bypass), leveler=\(!eq.bands[3].bypass), reverb=\(settings.binauralReverbEnabled)")
        #endif
    }

    #if !SKIP && !os(Android)
    private func setupAudioEngineDSP() {
        let eq = AVAudioUnitEQ(numberOfBands: 4)

        // Band 0: Low-Cut Highpass Filter at 80Hz (removes HVAC & mic thumps)
        let b0 = eq.bands[0]
        b0.filterType = .highPass
        b0.frequency = 80.0
        b0.bypass = !AppState.shared.settings.lowCutFilterEnabled

        // Band 1: Vocal Formant Boost at 2.5kHz (+3.5 dB boost)
        let b1 = eq.bands[1]
        b1.filterType = .parametric
        b1.frequency = 2500.0
        b1.bandwidth = 1.0
        b1.gain = 3.5
        b1.bypass = !AppState.shared.settings.vocalBoostEnabled

        // Band 2: De-Esser Notch Filter at 6.5kHz (-3.0 dB)
        let b2 = eq.bands[2]
        b2.filterType = .parametric
        b2.frequency = 6500.0
        b2.bandwidth = 0.8
        b2.gain = -3.0
        b2.bypass = !AppState.shared.settings.deEsserEnabled

        // Band 3: Dynamic Volume Leveler High-Shelf Contour at 10kHz (+2.0 dB air clarity)
        let b3 = eq.bands[3]
        b3.filterType = .highShelf
        b3.frequency = 10000.0
        b3.gain = 2.0
        b3.bypass = !AppState.shared.settings.volumeLevelerEnabled

        self.eqUnit = eq
        logger.info("Initialized 4-Band Audiophile Parametric EQ DSP Graph.")
    }
    #endif

    private func cleanupPlayer() {
        #if !SKIP && !os(Android)
        if let token = timeObserverToken {
            player?.removeTimeObserver(token)
            timeObserverToken = nil
        }
        if let token = playerItemObserverToken {
            NotificationCenter.default.removeObserver(token)
            playerItemObserverToken = nil
        }
        if let token = playerFailedObserverToken {
            NotificationCenter.default.removeObserver(token)
            playerFailedObserverToken = nil
        }
        if let token = playerStalledObserverToken {
            NotificationCenter.default.removeObserver(token)
            playerStalledObserverToken = nil
        }
        timeControlStatusObserver = nil
        currentItemObserver = nil
        currentItemStatusObserver = nil
        player?.removeAllItems()
        player = nil
        #endif
    }

    private func loadQueue(from index: Int, seekTimeWithinTrack: TimeInterval, autoPlay: Bool = true) {
        guard let session = session else { return }
        guard index >= 0 && index < session.audioTracks.count else { return }

        self.currentTrackIndex = index
        self.pendingSeekTimeWithinTrack = seekTimeWithinTrack > 0.1 ? seekTimeWithinTrack : nil

        #if !SKIP && !os(Android)
        if player == nil {
            player = AVQueuePlayer()
            setupRemoteCommandCenter()
            setupPlayerObservers()
        }

        player?.removeAllItems()
        topUpQueue(from: index)
        #endif
    }

    private func topUpQueue(from startIndex: Int? = nil) {
        guard let session = session else { return }
        #if !SKIP && !os(Android)
        guard let player = player else { return }
        
        if let start = startIndex {
            lastQueuedIndex = start - 1
        }

        let maxQueuedItems = 3
        while player.items().count < maxQueuedItems {
            let nextIndex = lastQueuedIndex + 1
            guard nextIndex < session.audioTracks.count else { break }
            lastQueuedIndex = nextIndex

            if let item = makePlayerItem(for: nextIndex) {
                player.insert(item, after: nil)
            } else {
                logger.error("Failed to create AVPlayerItem for track index \(nextIndex)")
            }
        }
        #endif
    }

    private func makePlayerItem(for index: Int) -> AVPlayerItem? {
        guard let session = session, index >= 0 && index < session.audioTracks.count else { return nil }
        let track = session.audioTracks[index]
        guard let url = getFullTrackURL(from: track.contentUrl, libraryItemId: session.libraryItemId) else {
            logger.error("No valid URL for track index \(index): \(track.contentUrl)")
            return nil
        }
        let asset = AVURLAsset(url: url, options: [AVURLAssetPreferPreciseDurationAndTimingKey: true])
        let item = AVPlayerItem(asset: asset)
        item.preferredForwardBufferDuration = 30.0
        #if os(iOS)
        item.audioTimePitchAlgorithm = .spectral
        if #available(iOS 15.0, *) {
            item.allowedAudioSpatializationFormats = [.monoAndStereo, .multichannel]
        }
        #endif
        return item
    }

    #if !SKIP && !os(Android)
    private func setupPlayerObservers() {
        guard let player = player else { return }

        timeControlStatusObserver = player.observe(\.timeControlStatus, options: [.initial, .new]) { [weak self] player, _ in
            Task { @MainActor in
                guard let self = self else { return }
                switch player.timeControlStatus {
                case .playing:
                    self.isPlaying = true
                    self.isBuffering = false
                    self.retryCount = 0
                case .waitingToPlayAtSpecifiedRate:
                    self.isBuffering = true
                case .paused:
                    self.isPlaying = false
                    self.isBuffering = false
                @unknown default:
                    break
                }
                self.syncWidgetState()
            }
        }

        currentItemObserver = player.observe(\.currentItem, options: [.initial, .new]) { [weak self] player, _ in
            Task { @MainActor in
                guard let self = self else { return }
                self.handleCurrentItemChanged(player.currentItem)
            }
        }

        if let token = timeObserverToken {
            player.removeTimeObserver(token)
            timeObserverToken = nil
        }
        let interval = CMTime(seconds: 0.5, preferredTimescale: 600)
        timeObserverToken = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            Task { @MainActor in
                self?.handlePeriodicTimeUpdate(time: time)
            }
        }
    }

    private func handleCurrentItemChanged(_ item: AVPlayerItem?) {
        guard let session = session else { return }
        guard let item = item else {
            if isPlaying && currentTrackIndex >= session.audioTracks.count - 1 {
                logger.info("Reached the end of the audiobook.")
                pause()
                currentTime = duration
                syncProgressImmediately()
                syncWidgetState()
            }
            return
        }

        if let asset = item.asset as? AVURLAsset,
           let matchedIndex = session.audioTracks.firstIndex(where: {
               getFullTrackURL(from: $0.contentUrl, libraryItemId: session.libraryItemId) == asset.url
           }) {
            if matchedIndex != currentTrackIndex {
                logger.info("Advanced to track index \(matchedIndex)")
                currentTrackIndex = matchedIndex
            }
        }

        observeCurrentItemStatus(item)
        topUpQueue()
        updateNowPlaying(rate: isPlaying ? playbackRate : 0.0, elapsedTime: currentTime)
    }

    private func observeCurrentItemStatus(_ item: AVPlayerItem) {
        if let token = playerItemObserverToken {
            NotificationCenter.default.removeObserver(token)
            playerItemObserverToken = nil
        }
        if let token = playerFailedObserverToken {
            NotificationCenter.default.removeObserver(token)
            playerFailedObserverToken = nil
        }
        if let token = playerStalledObserverToken {
            NotificationCenter.default.removeObserver(token)
            playerStalledObserverToken = nil
        }

        currentItemStatusObserver = item.observe(\.status, options: [.initial, .new]) { [weak self] item, _ in
            Task { @MainActor in
                guard let self = self else { return }
                switch item.status {
                case .readyToPlay:
                    self.logger.info("AVPlayerItem ready to play (track \(self.currentTrackIndex))")
                    if let pendingSeek = self.pendingSeekTimeWithinTrack, pendingSeek > 0.1 {
                        self.pendingSeekTimeWithinTrack = nil
                        let cmTime = CMTime(seconds: pendingSeek, preferredTimescale: 600)
                        self.logger.info("Seeking ready AVPlayerItem to pending time: \(pendingSeek)s")
                        item.seek(to: cmTime, toleranceBefore: .zero, toleranceAfter: .zero) { [weak self] _ in
                            Task { @MainActor in
                                guard let self = self else { return }
                                if self.isPlaying {
                                    self.reconfigureAudioSession()
                                    self.player?.play()
                                    self.player?.rate = self.playbackRate
                                    self.updateNowPlaying(rate: self.playbackRate, elapsedTime: self.currentTime)
                                }
                            }
                        }
                    } else {
                        if self.isPlaying {
                            self.reconfigureAudioSession()
                            self.player?.play()
                            self.player?.rate = self.playbackRate
                            self.updateNowPlaying(rate: self.playbackRate, elapsedTime: self.currentTime)
                        }
                    }
                case .failed:
                    let errStr = item.error?.localizedDescription ?? "Unknown error"
                    self.logger.error("AVPlayerItem failed: \(errStr)")
                    self.handlePlaybackFailure(error: item.error)
                case .unknown:
                    break
                @unknown default:
                    break
                }
            }
        }

        playerItemObserverToken = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                guard let self = self, let session = self.session else { return }
                if self.currentTrackIndex == session.audioTracks.count - 1 {
                    self.logger.info("Finished last track.")
                    self.pause()
                    self.currentTime = self.duration
                    self.syncProgressImmediately()
                    self.syncWidgetState()
                } else {
                    self.logger.info("Finished track \(self.currentTrackIndex). AVQueuePlayer advancing automatically...")
                }
            }
        }

        playerFailedObserverToken = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemFailedToPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak self] notification in
            let error = notification.userInfo?[AVPlayerItemFailedToPlayToEndTimeErrorKey] as? Error
            Task { @MainActor in
                self?.logger.error("AVPlayerItemFailedToPlayToEndTime: \(error?.localizedDescription ?? "nil")")
                self?.handlePlaybackFailure(error: error)
            }
        }

        playerStalledObserverToken = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemPlaybackStalled,
            object: item,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.logger.warning("Playback stalled due to buffer underrun. Will attempt recovery.")
                self?.handlePlaybackStalled()
            }
        }
    }

    private func handlePlaybackFailure(error: Error?) {
        guard let session = session else { return }
        logger.error("Handling playback failure for track \(self.currentTrackIndex), retryCount=\(self.retryCount)")
        
        if retryCount < 3 {
            retryCount += 1
            let delay = Double(retryCount) * 1.5
            logger.info("Retrying track \(self.currentTrackIndex) after \(delay)s...")
            
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                guard self.session?.id == session.id else { return }
                
                let track = session.audioTracks[self.currentTrackIndex]
                let seekTimeWithinTrack = max(0, self.currentTime - track.startOffset)
                self.loadQueue(from: self.currentTrackIndex, seekTimeWithinTrack: seekTimeWithinTrack, autoPlay: self.isPlaying)
            }
        } else {
            logger.error("Exhausted retries for playback failure. Pausing.")
            retryCount = 0
            pause()
        }
    }

    private func handlePlaybackStalled() {
        guard isPlaying else { return }
        isBuffering = true
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            if self.isBuffering && self.isPlaying {
                self.logger.info("Re-triggering play() after stall recovery wait")
                self.player?.play()
                self.player?.rate = self.playbackRate
            }
        }
    }

    private func handlePeriodicTimeUpdate(time: CMTime) {
        guard isPlaying, let session = session, currentTrackIndex < session.audioTracks.count else { return }
        let track = session.audioTracks[currentTrackIndex]
        let trackStart = track.startOffset
        let absoluteTime = trackStart + time.seconds
        self.currentTime = absoluteTime

        self.updateNowPlaying(elapsedTime: absoluteTime)

        var trackDuration = track.duration
        trackDuration = self.session?.audioTracks[self.currentTrackIndex].duration ?? track.duration
        if let item = self.player?.currentItem, item.status == .readyToPlay {
            let itemDur = item.duration.seconds
            if itemDur > 0 && !itemDur.isNaN && (trackDuration <= 0 || abs(itemDur - trackDuration) > 2) {
                trackDuration = itemDur
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
    #endif

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

    private var remoteCommandTargetsSetup = false

    private func setupRemoteCommandCenter() {
        if remoteCommandTargetsSetup { return }
        remoteCommandTargetsSetup = true

        let commandCenter = MPRemoteCommandCenter.shared()

        commandCenter.playCommand.isEnabled = true
        commandCenter.playCommand.addTarget { [weak self] _ in
            self?.play()
            return .success
        }

        commandCenter.pauseCommand.isEnabled = true
        commandCenter.pauseCommand.addTarget { [weak self] _ in
            self?.pause()
            return .success
        }

        commandCenter.skipForwardCommand.isEnabled = true
        commandCenter.skipForwardCommand.preferredIntervals = [30]
        commandCenter.skipForwardCommand.addTarget { [weak self] _ in
            self?.skipForward(30)
            return .success
        }

        commandCenter.skipBackwardCommand.isEnabled = true
        commandCenter.skipBackwardCommand.preferredIntervals = [10]
        commandCenter.skipBackwardCommand.addTarget { [weak self] _ in
            self?.skipBackward(10)
            return .success
        }

        commandCenter.changePlaybackPositionCommand.isEnabled = true
        commandCenter.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let self = self, let positionEvent = event as? MPChangePlaybackPositionCommandEvent else {
                return .commandFailed
            }
            self.seek(to: positionEvent.positionTime)
            return .success
        }
    }
    #endif

    // MARK: - Progress Syncing

    private var offlineProgressQueueURL: URL {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        return paths[0].appendingPathComponent("abp_offlineProgressQueue.json")
    }
    private var isFlushingQueue = false

    private func queueOfflineProgress(item: ProgressSyncQueueItem) {
        var queue = getOfflineProgressQueue()
        // If we already have a pending sync for this session, replace it with the latest one
        if let idx = queue.firstIndex(where: { $0.sessionId == item.sessionId }) {
            if item.dateAdded >= queue[idx].dateAdded {
                // Accumulate timeListened so we don't lose metrics during extended offline periods!
                let accumulatedTimeListened = queue[idx].timeListened + item.timeListened
                let newItem = ProgressSyncQueueItem(
                    sessionId: item.sessionId,
                    episodeId: item.episodeId,
                    currentTime: item.currentTime,
                    duration: item.duration,
                    timeListened: accumulatedTimeListened,
                    dateAdded: item.dateAdded
                )
                queue[idx] = newItem
            }
        } else {
            queue.append(item)
        }
        
        if let data = try? JSONEncoder().encode(queue) {
            try? data.write(to: offlineProgressQueueURL, options: .atomic)
        }
        logger.info("Queued offline progress for session \(item.sessionId)")
    }

    private func removeOfflineProgressItem(sessionId: String, dateAdded: Date) {
        var queue = getOfflineProgressQueue()
        queue.removeAll { $0.sessionId == sessionId && $0.dateAdded == dateAdded }
        if let data = try? JSONEncoder().encode(queue) {
            try? data.write(to: offlineProgressQueueURL, options: .atomic)
        }
    }

    private func getOfflineProgressQueue() -> [ProgressSyncQueueItem] {
        if let data = try? Data(contentsOf: offlineProgressQueueURL),
           let queue = try? JSONDecoder().decode([ProgressSyncQueueItem].self, from: data) {
            return queue
        }
        return []
    }

    func flushOfflineProgressQueue() async {
        guard !isFlushingQueue else { return }
        isFlushingQueue = true
        defer { isFlushingQueue = false }

        let queue = getOfflineProgressQueue()
        guard !queue.isEmpty else { return }
        guard NetworkMonitor.shared.isConnected else { return }

        logger.info("Flushing \(queue.count) offline progress items via Bulk Sync")

        do {
            let syncedSessionIds = try await AudiobookphileAPI.shared.bulkSyncProgress(items: queue)
            logger.info(
                "Bulk sync completed. Synced \(syncedSessionIds.count) of \(queue.count) items."
            )

            if !syncedSessionIds.isEmpty {
                var currentQueue = getOfflineProgressQueue()
                for item in queue where syncedSessionIds.contains(item.sessionId) {
                    currentQueue.removeAll {
                        $0.sessionId == item.sessionId && $0.dateAdded <= item.dateAdded
                    }
                }
                if let data = try? JSONEncoder().encode(currentQueue) {
                    try? data.write(to: offlineProgressQueueURL, options: .atomic)
                }
            }
        } catch {
            logger.error("Bulk offline sync failed: \(error)")
        }
    }

    private func startSyncTimer() {
        stopSyncTimer()

        // Sync every 15 seconds
        progressSyncTimer = Timer.scheduledTimer(withTimeInterval: 15.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.syncProgress()
                await self?.flushOfflineProgressQueue()
            }
        }
    }

    private func stopSyncTimer() {
        progressSyncTimer?.invalidate()
        progressSyncTimer = nil
    }

    private func syncProgress() async {
        guard let session = session else { return }

        let elapsedListened = currentTime - lastSyncedTime
        guard elapsedListened >= 1.0 || abs(elapsedListened) > 5.0 else { return }

        let timeListenedToSync = elapsedListened > 0 ? elapsedListened : 0
        lastSyncedTime = currentTime

        guard NetworkMonitor.shared.isConnected else {
            logger.info("Device offline, queueing sync...")
            let item = ProgressSyncQueueItem(sessionId: session.id, episodeId: session.episodeId, currentTime: currentTime, duration: duration, timeListened: timeListenedToSync)
            queueOfflineProgress(item: item)
            return
        }

        do {
            try await AudiobookphileAPI.shared.syncProgress(
                sessionId: session.id,
                episodeId: session.episodeId,
                currentTime: currentTime,
                duration: duration,
                timeListened: timeListenedToSync
            )
            self.logger.info("Synced progress to server: \(self.currentTime)s / \(self.duration)s")
            self.syncWidgetState()
        } catch {
            logger.error("Progress sync failed: \(error). Queueing for later.")
            let item = ProgressSyncQueueItem(sessionId: session.id, episodeId: session.episodeId, currentTime: currentTime, duration: duration, timeListened: timeListenedToSync)
            queueOfflineProgress(item: item)
            self.syncWidgetState()
        }
    }

    private func syncProgressImmediately() {
        #if os(iOS)
        var bgTask: UIBackgroundTaskIdentifier = .invalid
        bgTask = UIApplication.shared.beginBackgroundTask(withName: "syncProgressImmediately") {
            UIApplication.shared.endBackgroundTask(bgTask)
            bgTask = .invalid
        }
        #endif

        Task { @MainActor in
            await syncProgress()
            await flushOfflineProgressQueue()

            #if os(iOS)
            if bgTask != .invalid {
                UIApplication.shared.endBackgroundTask(bgTask)
            }
            #endif
        }
    }

    // MARK: - URL Resolver

    private func getFullTrackURL(from trackPath: String, libraryItemId: String? = nil) -> URL? {
        let trimmedPath = trackPath.trimmingCharacters(in: .whitespacesAndNewlines)
        if let bookId = libraryItemId,
           let localURL = DownloadService.shared.getLocalTrackURL(bookId: bookId, trackPath: trimmedPath) {
            logger.info("Redirected streaming to local downloaded file: \(localURL)")
            return localURL
        }

        // Track URLs are pre-signed HTTP/HTTPS urls from the backend
        if trimmedPath.hasPrefix("http") {
            if let url = URL(string: trimmedPath) {
                return url
            }
            if let encodedString = trimmedPath.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) {
                return URL(string: encodedString)
            }
        }

        // Handle relative URLs by resolving against baseURL
        if trimmedPath.hasPrefix("/") {
            let base = UserDefaults.standard.string(forKey: "abp_serverURL") ?? ""
            let fullString = base + trimmedPath
            if let url = URL(string: fullString) {
                return url
            }
            if let encodedString = fullString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) {
                return URL(string: encodedString)
            }
        }

        logger.error("Error: trackPath is not a valid HTTP URL or local path: \(trackPath)")
        return nil
    }

    // MARK: - Bookmarks

    public func addBookmark(title: String) {
        guard let session = session else { return }
        
        let bookmarkTitle = title.isEmpty ? "Bookmark at \(formatTime(currentTime))" : title
        let timePos = currentTime

        // Optimistically update UI
        let tempBookmark = Bookmark(id: UUID().uuidString, userId: AppState.shared.currentUser?.id ?? "", libraryItemId: session.libraryItemId, timePos: timePos, title: bookmarkTitle, createdAt: Date())
        self.bookmarks.append(tempBookmark)
        self.bookmarks.sort(by: { $0.timePos < $1.timePos })

        Task {
            do {
                let savedBookmark = try await AudiobookphileAPI.shared.createBookmark(libraryItemId: session.libraryItemId, timePos: timePos, title: bookmarkTitle)
                if let index = self.bookmarks.firstIndex(where: { $0.id == tempBookmark.id }) {
                    self.bookmarks[index] = savedBookmark
                } else {
                    self.bookmarks.append(savedBookmark)
                    self.bookmarks.sort(by: { $0.timePos < $1.timePos })
                }
            } catch {
                self.logger.error("Failed to save bookmark: \(error)")
                // Revert optimistic update
                self.bookmarks.removeAll(where: { $0.id == tempBookmark.id })
            }
        }
    }

    public func deleteBookmark(_ bookmark: Bookmark) {
        // Optimistically update UI
        self.bookmarks.removeAll { $0.id == bookmark.id }

        Task {
            do {
                try await AudiobookphileAPI.shared.deleteBookmark(bookmarkId: bookmark.id)
            } catch {
                self.logger.error("Failed to delete bookmark: \(error)")
                // Revert optimistic update
                self.bookmarks.append(bookmark)
                self.bookmarks.sort(by: { $0.timePos < $1.timePos })
            }
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

    // MARK: - Widget State Sync

    private func syncWidgetState() {
        guard let session = session, let defaults = UserDefaults(suiteName: EnvironmentConfig.appGroupIdentifier) else { return }

        // Find current chapter
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
