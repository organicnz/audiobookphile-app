import Foundation
import SkipFuse
import SwiftUI
#if !SKIP && os(iOS)
import BackgroundTasks
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
        CrashReporter.install()
        #endif
        // TelemetryService is the cross-platform Sentry envelope transport for
        // Android (Skip). On Darwin, sentry-cocoa (Main.swift) handles native
        // crash reporting — initializing both would double-report errors.
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

    private func handleProgressSync(task: BGProcessingTask) {
        task.expirationHandler = {
            // OS requested us to stop early
        }

        let sendableTask = UncheckedSendableTask(task: task)
        Task {
            await AudioPlayerService.shared.flushOfflineProgressQueue()
            sendableTask.task.setTaskCompleted(success: true)
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
