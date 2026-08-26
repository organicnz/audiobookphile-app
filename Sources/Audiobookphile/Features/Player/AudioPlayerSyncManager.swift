import Foundation
#if canImport(OSLog)
import OSLog
#endif
#if !SKIP && os(iOS)
import UIKit
import BackgroundTasks
#endif

@MainActor
public class AudioPlayerSyncManager {
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Audiobookphile", category: "SyncManager")

    private var offlineProgressQueueURL: URL {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        return paths[0].appendingPathComponent("abp_offlineProgressQueue.json")
    }
    private var isFlushingQueue = false
    private var progressSyncTimer: Timer?
    private var progressSyncTask: Task<Void, Never>?
    private var lastSyncedTime: TimeInterval = 0

    public init() {}

    public func setLastSyncedTime(_ time: TimeInterval) {
        self.lastSyncedTime = time
    }

    private func queueOfflineProgress(item: ProgressSyncQueueItem) {
        var queue = getOfflineProgressQueue()
        if let idx = queue.firstIndex(where: { $0.sessionId == item.sessionId }) {
            if item.dateAdded >= queue[idx].dateAdded {
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

    private func getOfflineProgressQueue() -> [ProgressSyncQueueItem] {
        if let data = try? Data(contentsOf: offlineProgressQueueURL),
           let queue = try? JSONDecoder().decode([ProgressSyncQueueItem].self, from: data) {
            return queue
        }
        return []
    }

    public func flushOfflineProgressQueue() async {
        guard !isFlushingQueue else { return }
        isFlushingQueue = true
        defer { isFlushingQueue = false }

        let queue = getOfflineProgressQueue()
        guard !queue.isEmpty else { return }
        guard NetworkMonitor.shared.isConnected else { return }

        logger.info("Flushing \(queue.count) offline progress items via Bulk Sync")

        do {
            let syncedSessionIds = try await AudiobookphileAPI.shared.bulkSyncProgress(items: queue)
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

    public func startSyncTimer(getSessionData: @escaping @MainActor () -> (PlaybackSession?, TimeInterval, TimeInterval), onSyncComplete: @escaping @MainActor () -> Void) {
        stopSyncTimer()

        progressSyncTimer = Timer.scheduledTimer(withTimeInterval: 15.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.syncProgress(getSessionData: getSessionData, onSyncComplete: onSyncComplete)
                await self?.flushOfflineProgressQueue()
            }
        }
    }

    public func stopSyncTimer() {
        progressSyncTimer?.invalidate()
        progressSyncTimer = nil
    }

    private func syncProgress(getSessionData: @escaping @MainActor () -> (PlaybackSession?, TimeInterval, TimeInterval), onSyncComplete: @MainActor () -> Void) async {
        let (sessionOpt, currentTime, duration) = getSessionData()
        guard let session = sessionOpt else { return }

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
            onSyncComplete()
        } catch {
            logger.error("Progress sync failed: \(error). Queueing for later.")
            TelemetryService.shared.captureError(error, tags: ["area": "progress_sync"])
            let item = ProgressSyncQueueItem(sessionId: session.id, episodeId: session.episodeId, currentTime: currentTime, duration: duration, timeListened: timeListenedToSync)
            queueOfflineProgress(item: item)
            onSyncComplete()
        }
    }

    public func debounceProgressSync(getSessionData: @escaping @MainActor () -> (PlaybackSession?, TimeInterval, TimeInterval), onSyncComplete: @escaping @MainActor () -> Void) {
        progressSyncTask?.cancel()
        progressSyncTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            guard !Task.isCancelled else { return }
            self?.syncProgressImmediately(getSessionData: getSessionData, onSyncComplete: onSyncComplete)
        }
    }

    public func syncProgressImmediately(getSessionData: @escaping @MainActor () -> (PlaybackSession?, TimeInterval, TimeInterval), onSyncComplete: @escaping @MainActor () -> Void) {
        #if os(iOS)
        var bgTask: UIBackgroundTaskIdentifier = .invalid
        bgTask = UIApplication.shared.beginBackgroundTask(withName: "syncProgressImmediately") {
            UIApplication.shared.endBackgroundTask(bgTask)
            bgTask = .invalid
        }
        #endif

        Task { @MainActor in
            await syncProgress(getSessionData: getSessionData, onSyncComplete: onSyncComplete)
            await flushOfflineProgressQueue()

            #if os(iOS)
            if bgTask != .invalid {
                UIApplication.shared.endBackgroundTask(bgTask)
            }
            #endif
        }
    }

    public func enqueueOfflineSyncOnBackground() {
        #if os(iOS)
        let queue = getOfflineProgressQueue()
        if !queue.isEmpty {
            let request = BGProcessingTaskRequest(identifier: "club.foodshare.audiobookphile.progress-sync")
            request.requiresNetworkConnectivity = true
            request.requiresExternalPower = false
            do {
                try BGTaskScheduler.shared.submit(request)
                logger.info("Submitted BGTaskScheduler request for \(queue.count) offline items.")
            } catch {
                logger.error("Could not schedule BGTask: \(error)")
            }
        }
        #endif
    }
    
    public func recordClosedSession(session: PlaybackSession, syncTime: TimeInterval, syncDuration: TimeInterval) {
        let syncId = session.id
        let episodeId = session.episodeId
        let timeListened = max(0, syncTime - lastSyncedTime)

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
                logger.error("Failed to close session: \(error). Queueing for offline sync.")
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
}
