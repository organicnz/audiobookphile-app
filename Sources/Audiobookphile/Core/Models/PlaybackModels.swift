//
//  PlaybackModels.swift
//  Audiobookphile
//
//  Core models for Playback and Session data.
//

import Foundation

// MARK: - Playback Session
public struct PlaybackSession: Codable, Sendable {
    public let id: String
    public let userId: String
    public let libraryId: String
    public let libraryItemId: String
    public let episodeId: String?

    // Display info
    public let displayTitle: String
    public let displayAuthor: String
    public let coverPath: String?

    // Playback info
    public let duration: TimeInterval
    public let playMethod: Int
    public let mediaPlayer: String
    public let mediaType: String

    // Audio tracks and chapters
    public var audioTracks: [AudioTrack]
    public let chapters: [Chapter]

    // State
    public let currentTime: TimeInterval
    public let playbackRate: Float
    public let startedAt: Date
    public let updatedAt: Date

    public enum CodingKeys: String, CodingKey {
        case id, userId, libraryId, libraryItemId, episodeId
        case displayTitle, displayAuthor, coverPath
        case duration, playMethod, mediaPlayer, mediaType
        case audioTracks, chapters
        case currentTime, playbackRate, startedAt, updatedAt
    }
}

// MARK: - Audio Track
public struct AudioTrack: Identifiable, Codable, Sendable {
    public let index: Int
    public var startOffset: TimeInterval
    public var duration: TimeInterval
    public let title: String?
    public let contentUrl: String
    public let mimeType: String
    public let codec: String?

    public var id: Int {
        index
    }
}

// MARK: - Media Progress
public struct MediaProgress: Codable, Hashable, Sendable {
    public let id: String
    public let libraryItemId: String
    public let episodeId: String?
    public let duration: TimeInterval
    public let progress: Double // 0.0 to 1.0
    public let currentTime: TimeInterval
    public let isFinished: Bool
    public let hideFromContinueListening: Bool?
    public let lastUpdate: Date
    public let startedAt: Date?
    public let finishedAt: Date?

    public var progressPercentage: Int {
        Int(progress * 100)
    }

    public var timeRemaining: TimeInterval {
        duration - currentTime
    }
}

// MARK: - Media Progress Row
public struct MediaProgressRow: Codable, Hashable, Sendable, Identifiable {
    public let id: String
    public let libraryItemId: String?
    public let duration: TimeInterval?
    public let progress: TimeInterval?
    public let isFinished: Bool?
    public let finishedAt: Date?
    public let lastUpdate: Date?
    public let startedAt: Date?
    public let title: String?

    public enum CodingKeys: String, CodingKey {
        case id, duration, progress, title
        case libraryItemId = "library_item_id"
        case isFinished = "is_finished"
        case finishedAt = "finished_at"
        case lastUpdate = "last_update"
        case startedAt = "started_at"
    }
}

// MARK: - Playback Session Row
public struct PlaybackSessionRow: Codable, Hashable, Sendable, Identifiable {
    public let id: String
    public let displayTitle: String?
    public let displayAuthor: String?
    public let timeListening: TimeInterval?
    public let sessionDate: String?
    public let updatedAt: Date?

    public enum CodingKeys: String, CodingKey {
        case id
        case displayTitle = "display_title"
        case displayAuthor = "display_author"
        case timeListening = "time_listening"
        case sessionDate = "session_date"
        case updatedAt = "updated_at"
    }
}

// MARK: - User Stats Data
public struct UserStatsData: Codable, Hashable, Sendable {
    public let mediaProgress: [MediaProgressRow]
    public let recentSessions: [PlaybackSessionRow]
}

// MARK: - Similar Items Response
public struct SimilarItemsResponse: Codable, Sendable {
    public let similarItems: [Book]
}
