import Foundation
import SkipFuse
import SwiftUI
#if !SKIP && os(iOS)
import BackgroundTasks
import Sentry
#endif

/// A logger for the Audiobookphile module.
let logger: Logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Audiobookphile", category: "Audiobookphile")

/* SKIP @bridge */
/// The shared top-level view for the app, loaded from the platform-specific App delegates below.
///
/// The default implementation merely loads the `ContentView` for the app and logs a message.
public struct AudiobookphileRootView: View {
    @State private var appState = AppState.shared
    @State private var audioPlayer = AudioPlayerService.shared
    @State private var playerCoordinator = PlayerCoordinator.shared

    /* SKIP @bridge */public init() {
    }

    public var body: some View {
        ContentView()
            .environment(appState)
            .environment(audioPlayer)
            .environment(playerCoordinator)
            .task {
                logger.info(
                    "Skip app logs are viewable in the Xcode console for iOS; Android logs via Studio/adb logcat"
                )
            }
    }
}

/* SKIP @bridge */
/// Global application delegate functions.
///
/// These functions can update a shared observable object to communicate app state changes to interested views.
public final class AudiobookphileAppDelegate: Sendable {
    /* SKIP @bridge */public static let shared = AudiobookphileAppDelegate()

    private init() {
    }

    /* SKIP @bridge */public func onInit() {
        logger.debug("onInit")
        migrateLegacyKeys()

        #if !SKIP && os(iOS)
        // Native crash reporting via sentry-cocoa (already a package
        // dependency). Started only when a DSN is configured; otherwise fall
        // back to the lightweight on-device CrashReporter so crashes are still
        // captured locally and surfaced in Settings → Crash Diagnostics.
        // Installing both would double-report: Sentry replaces the process
        // signal/exception handlers when it starts.
        let sentryDSN = EnvironmentConfig.sentryDSN
        if sentryDSN.isEmpty {
            CrashReporter.install()
        } else {
            let info = Bundle.main.infoDictionary ?? [:]
            let version = info["CFBundleShortVersionString"] as? String ?? "0.0.0"
            let build = info["CFBundleVersion"] as? String ?? "0"
            SentrySDK.start { options in
                options.dsn = sentryDSN
                options.releaseName = "audiobookphile-app@\(version)+\(build)"
                #if DEBUG
                options.environment = "development"
                #else
                options.environment = "production"
                #endif
            }
        }

        // Deliver any crash retained from a previous session: forwards to
        // Sentry when telemetry is configured, otherwise mirrors the report to
        // the system log and keeps it on disk for Crash Diagnostics.
        TelemetryService.shared.configure()
        TelemetryService.shared.handlePendingCrashReport()
        #endif
        // TelemetryService is also the cross-platform Sentry envelope transport
        // for Android (Skip), which has no native sentry-cocoa.
        #if SKIP
        TelemetryService.shared.configure()
        TelemetryService.shared.handlePendingCrashReport()
        #endif

        #if !SKIP && os(iOS)
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: "club.foodshare.audiobookphile.progress-sync",
            using: nil
        ) { task in
            guard let processingTask = task as? BGProcessingTask else { return }
            self.handleProgressSync(task: processingTask)
        }
        #endif

        // Configure global URLCache for AsyncImage and network requests
        let memoryCapacity = 50 * 1024 * 1024 // 50 MB
        let diskCapacity = 200 * 1024 * 1024 // 200 MB
        #if os(iOS)
        URLCache.shared = URLCache(
            memoryCapacity: memoryCapacity,
            diskCapacity: diskCapacity,
            diskPath: "audiobookphile_images"
        )
        #else
        // Configure for Skip if needed, but URLCache.shared works natively on most platforms.
        URLCache.shared = URLCache(
            memoryCapacity: memoryCapacity,
            diskCapacity: diskCapacity,
            diskPath: "audiobookphile_images"
        )
        #endif
    }

    /* SKIP @bridge */public func onLaunch() {
        logger.debug("onLaunch")
    }

    /* SKIP @bridge */public func onResume() {
        logger.debug("onResume")
    }

    /* SKIP @bridge */public func onPause() {
        logger.debug("onPause")
    }

    /* SKIP @bridge */public func onStop() {
        logger.debug("onStop")
    }

    /* SKIP @bridge */public func onDestroy() {
        logger.debug("onDestroy")
    }

    /* SKIP @bridge */public func onLowMemory() {
        logger.debug("onLowMemory")
    }

    #if !SKIP && os(iOS)
    private struct UncheckedSendableTask: @unchecked Sendable {
        let task: BGProcessingTask
    }

    /// Completion state for one background run. Per the background-execution
    /// contract: setTaskCompleted must fire EXACTLY once, and an expiring run
    /// must complete early with success:false — running past expiration
    /// without completing can get the app killed and scheduling penalized.
    private final class ProgressSyncRun: @unchecked Sendable {
        private let lock = NSLock()
        private var completed = false
        private var expired = false

        func markExpired() { lock.withLock { expired = true } }

        func finish(_ task: BGProcessingTask, completedSuccessfully: Bool) {
            let shouldComplete: Bool = lock.withLock {
                if completed { return false }
                completed = true
                return true
            }
            guard shouldComplete else { return }
            task.setTaskCompleted(success: completedSuccessfully && !expired)
        }
    }

    private func handleProgressSync(task: BGProcessingTask) {
        let run = ProgressSyncRun()
        let sendableTask = UncheckedSendableTask(task: task)
        task.expirationHandler = { [run] in
            run.markExpired()
        }

        Task {
            await AudioPlayerService.shared.flushOfflineProgressQueue()
            run.finish(sendableTask.task, completedSuccessfully: true)
        }
    }
    #endif

    private func migrateLegacyKeys() {
        let standard = UserDefaults.standard
        let migrations = [
            "abs_serverURL": "abp_serverURL",
            "abs_token": "abp_token",
            "abs_refreshToken": "abp_refreshToken",
            "abs_offlineProgressQueue": "abp_offlineProgressQueue",
            "abs_recent_servers": "abp_recent_servers"
        ]
        for (oldKey, newKey) in migrations {
            if let value = standard.value(forKey: oldKey) {
                standard.set(value, forKey: newKey)
                standard.removeObject(forKey: oldKey)
                logger.info("Migrated UserDefaults key \(oldKey) to \(newKey)")
            }
        }
        // Migrate dynamic bookmarks keys
        let allKeys = standard.dictionaryRepresentation().keys
        for oldKey in allKeys where oldKey.hasPrefix("abs_bookmarks_") {
            let newKey = oldKey.replacingOccurrences(of: "abs_bookmarks_", with: "abp_bookmarks_")
            if let value = standard.value(forKey: oldKey) {
                standard.set(value, forKey: newKey)
                standard.removeObject(forKey: oldKey)
                logger.info("Migrated UserDefaults bookmark key \(oldKey) to \(newKey)")
            }
        }
    }
}
