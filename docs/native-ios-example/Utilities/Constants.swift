//
//  Constants.swift
//  AudiobookphileClient
//
//  App-wide constants and configuration
//

import SwiftUI

// MARK: - API Constants

enum APIConstants {
    static let defaultTimeout: TimeInterval = 30
    static let uploadTimeout: TimeInterval = 300
    static let syncInterval: TimeInterval = 30
    static let reconnectDelay: TimeInterval = 5
    static let maxReconnectAttempts = 5
}

// MARK: - Playback Constants

enum PlaybackConstants {
    static let defaultJumpForward = 30
    static let defaultJumpBackward = 10
    static let jumpOptions = [5, 10, 15, 20, 30, 45, 60]

    static let playbackRates: [Float] = [0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0, 2.5, 3.0]
    static let defaultPlaybackRate: Float = 1.0

    static let sleepTimerOptions = [5, 10, 15, 30, 45, 60, 90, 120] // minutes
    static let endOfChapterSleepTimer = -1
}

// MARK: - UI Constants

enum UIConstants {
    // Corner radii
    static let smallRadius: CGFloat = 8
    static let mediumRadius: CGFloat = 12
    static let largeRadius: CGFloat = 16
    static let xlRadius: CGFloat = 24

    // Spacing
    static let spacingXS: CGFloat = 4
    static let spacingSM: CGFloat = 8
    static let spacingMD: CGFloat = 16
    static let spacingLG: CGFloat = 24
    static let spacingXL: CGFloat = 32

    // Glass effect values
    static let glassBlurRadius: CGFloat = 20
    static let glassBorderOpacity: Double = 0.3
    static let glassBackgroundOpacity: Double = 0.1

    // Animation durations
    static let quickAnimation: Double = 0.15
    static let normalAnimation: Double = 0.3
    static let slowAnimation: Double = 0.5

    // Mini player
    static let miniPlayerHeight: CGFloat = 70

    // Book cover aspect ratios
    static let bookCoverAspectRatio: CGFloat = 1.5 // height/width
    static let squareCoverAspectRatio: CGFloat = 1.0
}

// MARK: - Storage Keys

enum StorageKeys {
    // Authentication
    static let serverURL = "serverURL"
    static let accessToken = "accessToken"
    static let refreshToken = "refreshToken"
    static let deviceId = "absDeviceId"

    // User preferences
    static let jumpForwardTime = "jumpForwardTime"
    static let jumpBackwardTime = "jumpBackwardTime"
    static let defaultPlaybackSpeed = "defaultPlaybackSpeed"
    static let autoSleepTimer = "autoSleepTimer"
    static let autoResume = "autoResume"
    static let hapticsEnabled = "hapticsEnabled"
    static let lockOrientation = "lockOrientation"

    // Player settings
    static let useChapterTrack = "useChapterTrack"
    static let useTotalTrack = "useTotalTrack"
    static let scaleElapsedTimeBySpeed = "scaleElapsedTimeBySpeed"
    static let playerLock = "playerLock"

    // Network settings
    static let streamingUsingCellular = "streamingUsingCellular"
    static let downloadUsingCellular = "downloadUsingCellular"

    // App state
    static let lastLibraryId = "lastLibraryId"
    static let recentServers = "recentServers"
}

// MARK: - App Colors

extension Color {
    static let appBackground = Color(red: 0.08, green: 0.08, blue: 0.12)
    static let appSecondaryBackground = Color(red: 0.12, green: 0.12, blue: 0.16)

    static let appPrimary = Color.cyan
    static let appSecondary = Color.blue
    static let appAccent = Color.purple

    static let appSuccess = Color.green
    static let appWarning = Color.orange
    static let appError = Color.red

    static let textPrimary = Color.white
    static let textSecondary = Color.white.opacity(0.7)
    static let textTertiary = Color.white.opacity(0.5)
}

// MARK: - Gradient Presets

enum GradientPresets {
    static let primaryGradient = LinearGradient(
        colors: [.cyan, .blue],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let secondaryGradient = LinearGradient(
        colors: [.blue, .purple],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let accentGradient = LinearGradient(
        colors: [.purple, .pink],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let backgroundGradient = LinearGradient(
        colors: [Color.appBackground, Color.appSecondaryBackground],
        startPoint: .top,
        endPoint: .bottom
    )
}



// MARK: - Play Methods

enum PlayMethod: Int {
    case directPlay = 0
    case directStream = 1
    case transcode = 2
    case local = 3
}

// MARK: - Sync Status

enum SyncStatus: Int {
    case idle = 0
    case syncing = 1
    case success = 2
    case failed = 3
}

// MARK: - Error Types

enum AudiobookphileError: LocalizedError {
    case noServerConfigured
    case notAuthenticated
    case networkUnavailable
    case serverUnreachable
    case invalidResponse
    case playbackFailed(String)
    case downloadFailed(String)

    var errorDescription: String? {
        switch self {
        case .noServerConfigured:
            return "No server configured. Please connect to a server."
        case .notAuthenticated:
            return "Not authenticated. Please log in."
        case .networkUnavailable:
            return "Network unavailable. Please check your connection."
        case .serverUnreachable:
            return "Server is unreachable. Please check the server URL."
        case .invalidResponse:
            return "Invalid response from server."
        case .playbackFailed(let message):
            return "Playback failed: \(message)"
        case .downloadFailed(let message):
            return "Download failed: \(message)"
        }
    }
}
