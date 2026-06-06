//
//  Models.swift
//  Audiobookphile
//
//  Core data models for Audiobookphile, fully Swift 6.3 and Skip compatible.
//

import Foundation

#if canImport(CoreGraphics)
import CoreGraphics
#else
import Foundation
#endif

// MARK: - Media Type
public enum MediaType: String, Codable, Sendable {
    case book = "book"
    case podcast = "podcast"
}

// MARK: - Book
public struct Book: Identifiable, Codable, Hashable, Sendable {
    public let id: String
    public let libraryId: String?
    public let folderId: String?
    public let path: String?
    public let relPath: String?
    public let isMissing: Bool?
    public let libraryFiles: [LibraryFile]?
    
    // Media Info
    public let media: BookMedia
    
    // Metadata
    public var title: String {
        media.metadata.title
    }
    
    public var author: String? {
        media.metadata.authorName
    }
    
    public var description: String? {
        media.metadata.description
    }
    
    public var coverPath: String? {
        media.coverPath
    }
    
    public var duration: TimeInterval {
        media.duration ?? 0
    }
    
    public var chapters: [Chapter] {
        media.chapters ?? []
    }
    
    // Progress
    public let userMediaProgress: MediaProgress?
    
    // Timestamps
    public let addedAt: Date?
    public let updatedAt: Date?
    
    public enum CodingKeys: String, CodingKey {
        case id, libraryId, folderId, path, relPath, media
        case userMediaProgress, addedAt, updatedAt, libraryFiles
        case isMissing
    }
}

// MARK: - Book Media
public struct BookMedia: Codable, Hashable, Sendable {
    public let libraryFiles: [LibraryFile]?
    public let chapters: [Chapter]?
    public let duration: TimeInterval?
    public let size: Int64?
    public let metadata: BookMetadata
    public let coverPath: String?
    public let tags: [String]?
    public let audioFiles: [AudioFile]?
    public let ebookFile: EbookFile?
    
    public enum CodingKeys: String, CodingKey {
        case libraryFiles, chapters, duration, size, metadata
        case coverPath, tags, audioFiles, ebookFile
    }
}

// MARK: - Book Metadata
public struct BookMetadata: Codable, Hashable, Sendable {
    public let title: String
    public let subtitle: String?
    public let authorName: String?
    public let narratorName: String?
    public let seriesName: String?
    public let genres: [String]
    public let publishedYear: String?
    public let publishedDate: String?
    public let publisher: String?
    public let description: String?
    public let isbn: String?
    public let asin: String?
    public let language: String?
    public let explicit: Bool
    
    public enum CodingKeys: String, CodingKey {
        case title, subtitle
        case authorName, narratorName, seriesName
        case genres, publishedYear, publishedDate, publisher
        case description, isbn, asin, language, explicit
    }
}

// MARK: - Chapter
public struct Chapter: Identifiable, Codable, Hashable, Sendable {
    public var id: Int
    public let title: String
    public let start: TimeInterval
    public let end: TimeInterval
    
    public var duration: TimeInterval {
        end - start
    }
}

// MARK: - Audio File
public struct AudioFile: Identifiable, Codable, Hashable, Sendable {
    public var id: String {
        ino
    }
    public let index: Int
    public let ino: String
    public let metadata: AudioMetadata
    public let duration: TimeInterval
    public let bitRate: Int?
    public let language: String?
    public let codec: String?
    public let mimeType: String
}

public struct AudioMetadata: Codable, Hashable, Sendable {
    public let filename: String?
    public let ext: String?
    public let path: String?
    public let relPath: String?
    public let size: Int64?
    public let mtimeMs: Int64?
    public let ctimeMs: Int64?
    public let birthtimeMs: Int64?
}

// MARK: - Library File
public struct LibraryFile: Identifiable, Codable, Hashable, Sendable {
    public var id: String {
        ino
    }
    public let ino: String
    public let metadata: FileMetadata?
    public let isSupplementary: Bool?
    public let fileType: String?
}

public struct FileMetadata: Codable, Hashable, Sendable {
    public let filename: String?
    public let ext: String?
    public let path: String?
    public let relPath: String?
    public let size: Int64?
    public let mtimeMs: Int64?
    public let ctimeMs: Int64?
    public let birthtimeMs: Int64?
}

// MARK: - Ebook File
public struct EbookFile: Codable, Hashable, Sendable {
    public let ino: String
    public let metadata: FileMetadata
    public let ebookFormat: String
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

// MARK: - Library
public struct Library: Identifiable, Codable, Sendable {
    public let id: String
    public let name: String
    public let folders: [LibraryFolder]?
    public let displayOrder: Int?
    public let icon: String?
    public let mediaType: String? // Changed to String? since MediaType enum might not match
    public let provider: String?
    public let settings: LibrarySettings?
    public let createdAt: Date?
    public let updatedAt: Date?
    
    public enum CodingKeys: String, CodingKey {
        case id, name, folders, displayOrder, icon, mediaType, provider, settings, createdAt
        case updatedAt = "updatedAt"
    }
}

public struct LibraryFolder: Identifiable, Codable, Sendable {
    public let id: String
    public let fullPath: String?
    public let libraryId: String?
    public let addedAt: Date?
}

public struct LibrarySettings: Codable, Sendable {
    public let coverAspectRatio: Int?
    public let disableWatcher: Bool?
    public let skipMatchingMediaWithAsin: Bool?
    public let skipMatchingMediaWithIsbn: Bool?
    public let autoScanCronExpression: String?
}

// MARK: - User
public struct User: Identifiable, Codable, Sendable {
    public let id: String
    public let username: String
    public let email: String?
    public let type: String
    public let token: String
    public let refreshToken: String?
    public let mediaProgress: [MediaProgress]
    public let seriesHideFromContinueListening: [String]
    public let bookmarks: [Bookmark]
    public let isActive: Bool
    public let isLocked: Bool
    public let lastSeen: Date?
    public let createdAt: Date
    public let permissions: UserPermissions
    public let librariesAccessible: [String]
    public let itemTagsAccessible: [String]
}

public struct Bookmark: Identifiable, Codable, Sendable {
    public let libraryItemId: String
    public let title: String
    public let time: TimeInterval
    public let createdAt: Date
    
    public var id: String {
        "\(libraryItemId)-\(time)"
    }
}

public struct UserPermissions: Codable, Sendable {
    public let download: Bool
    public let update: Bool
    public let delete: Bool
    public let upload: Bool
    public let accessAllLibraries: Bool
    public let accessAllTags: Bool
    public let accessExplicitContent: Bool
}

// MARK: - Podcast (for future support)
public struct Podcast: Identifiable, Codable, Sendable {
    public let id: String
    public let libraryId: String
    public let media: PodcastMedia
    public let addedAt: Date
    public let updatedAt: Date
}

public struct PodcastMedia: Codable, Sendable {
    public let metadata: PodcastMetadata
    public let coverPath: String?
    public let tags: [String]
    public let episodes: [PodcastEpisode]
    public let autoDownloadEpisodes: Bool
    public let autoDownloadSchedule: String?
}

public struct PodcastMetadata: Codable, Sendable {
    public let title: String
    public let author: String?
    public let description: String?
    public let releaseDate: String?
    public let genres: [String]
    public let feedUrl: String?
    public let imageUrl: String?
    public let itunesPageUrl: String?
    public let itunesId: String?
    public let itunesArtistId: String?
    public let explicit: Bool
    public let language: String?
}

public struct PodcastEpisode: Identifiable, Codable, Sendable {
    public let id: String
    public let index: Int
    public let title: String
    public let subtitle: String?
    public let description: String?
    public let pubDate: String?
    public let audioFile: AudioFile?
    public let publishedAt: Date?
    public let addedAt: Date
    public let updatedAt: Date
}

// MARK: - Server Connection
public struct ServerConnection: Codable, Sendable {
    public let url: String
    public let name: String?
    public let lastConnected: Date
    
    public var displayName: String {
        name ?? url
    }
}

// MARK: - App Settings
public struct AppSettings: Codable, Sendable {
    public var jumpForwardTime: Int = 30
    public var jumpBackwardsTime: Int = 10
    public var lockScreenControls: Bool = true
    public var autoDownloadPodcasts: Bool = false
    public var sleepTimerAutoStart: Bool = false
    public var sleepTimerDefaultTime: Int = 900 // 15 minutes
    public var theme: AppTheme = .system
    public var bookCoverAspectRatio: BookCoverAspectRatio = .square
    
    // UI Settings
    public var autoResume: Bool = true
    public var hapticsEnabled: Bool = true
    public var lockOrientation: Bool = false
    
    public init() {}
}

public enum AppTheme: String, Codable, Sendable {
    case light
    case dark
    case system
}

public enum BookCoverAspectRatio: Int, Codable, Sendable {
    case square = 1
    case standard = 16 // 1.6:1
    
    #if canImport(CoreGraphics)
    public var ratio: CGFloat {
        self == .square ? 1.0 : 1.6
    }
    #else
    public var ratio: Double {
        self == .square ? 1.0 : 1.6
    }
    #endif
}

// MARK: - API Error
public struct APIErrorResponse: Codable, Sendable {
    public struct ErrorDetail: Codable, Sendable {
        public let message: String
        public let code: String?
    }
    public let error: ErrorDetail?
    public let success: Bool
}

public struct ProgressSyncQueueItem: Codable, Sendable {
    public let sessionId: String
    public let currentTime: TimeInterval
    public let duration: TimeInterval
    public let timeListened: TimeInterval
    public let dateAdded: Date
    
    public init(sessionId: String, currentTime: TimeInterval, duration: TimeInterval, timeListened: TimeInterval, dateAdded: Date = Date()) {
        self.sessionId = sessionId
        self.currentTime = currentTime
        self.duration = duration
        self.timeListened = timeListened
        self.dateAdded = dateAdded
    }
}


