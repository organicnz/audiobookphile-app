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

// MARK: - API Key
public struct ApiKey: Codable, Hashable, Sendable {
    public let id: String
    public let key: String
    public let createdAt: Date?
}

// MARK: - User Stats
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

public struct UserStatsData: Codable, Hashable, Sendable {
    public let mediaProgress: [MediaProgressRow]
    public let recentSessions: [PlaybackSessionRow]
}

public struct SimilarItemsResponse: Codable, Sendable {
    public let similarItems: [Book]
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
    public let hasOpenIDLink: Bool?
    public let isOldToken: Bool?
}

public struct Bookmark: Identifiable, Codable, Hashable, Sendable {
    public let id: String
    public let userId: String
    public let libraryItemId: String
    public let timePos: Double
    public let title: String?
    public let createdAt: Date?

    public enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case libraryItemId = "library_item_id"
        case timePos = "time_pos"
        case title
        case createdAt = "created_at"
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
    public let createEreader: Bool?
    public let selectedTagsNotAccessible: Bool?
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
    public var defaultPlaybackSpeed: Double = 1.0

    // Audio & Hardware Accessibility Settings
    public var spokenAudioModeEnabled: Bool = true
    public var vocalBoostEnabled: Bool = false
    public var volumeLevelerEnabled: Bool = false
    public var monoAudioEnabled: Bool = false
    public var highResAudioEnabled: Bool = true
    public var deEsserEnabled: Bool = false
    public var lowCutFilterEnabled: Bool = true

    public init() {}

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        jumpForwardTime = try container.decodeIfPresent(Int.self, forKey: .jumpForwardTime) ?? 30
        jumpBackwardsTime = try container.decodeIfPresent(Int.self, forKey: .jumpBackwardsTime) ?? 10
        lockScreenControls = try container.decodeIfPresent(Bool.self, forKey: .lockScreenControls) ?? true
        autoDownloadPodcasts = try container.decodeIfPresent(Bool.self, forKey: .autoDownloadPodcasts) ?? false
        sleepTimerAutoStart = try container.decodeIfPresent(Bool.self, forKey: .sleepTimerAutoStart) ?? false
        sleepTimerDefaultTime = try container.decodeIfPresent(Int.self, forKey: .sleepTimerDefaultTime) ?? 900
        theme = try container.decodeIfPresent(AppTheme.self, forKey: .theme) ?? .system
        bookCoverAspectRatio = try container.decodeIfPresent(BookCoverAspectRatio.self, forKey: .bookCoverAspectRatio) ?? .square
        autoResume = try container.decodeIfPresent(Bool.self, forKey: .autoResume) ?? true
        hapticsEnabled = try container.decodeIfPresent(Bool.self, forKey: .hapticsEnabled) ?? true
        lockOrientation = try container.decodeIfPresent(Bool.self, forKey: .lockOrientation) ?? false
        defaultPlaybackSpeed = try container.decodeIfPresent(Double.self, forKey: .defaultPlaybackSpeed) ?? 1.0
        spokenAudioModeEnabled = try container.decodeIfPresent(Bool.self, forKey: .spokenAudioModeEnabled) ?? true
        vocalBoostEnabled = try container.decodeIfPresent(Bool.self, forKey: .vocalBoostEnabled) ?? false
        volumeLevelerEnabled = try container.decodeIfPresent(Bool.self, forKey: .volumeLevelerEnabled) ?? false
        monoAudioEnabled = try container.decodeIfPresent(Bool.self, forKey: .monoAudioEnabled) ?? false
        highResAudioEnabled = try container.decodeIfPresent(Bool.self, forKey: .highResAudioEnabled) ?? true
        deEsserEnabled = try container.decodeIfPresent(Bool.self, forKey: .deEsserEnabled) ?? false
        lowCutFilterEnabled = try container.decodeIfPresent(Bool.self, forKey: .lowCutFilterEnabled) ?? true
    }

    public enum CodingKeys: String, CodingKey {
        case jumpForwardTime
        case jumpBackwardsTime
        case defaultPlaybackSpeed
        case lockScreenControls
        case autoDownloadPodcasts
        case sleepTimerAutoStart
        case sleepTimerDefaultTime
        case theme
        case bookCoverAspectRatio
        case autoResume
        case hapticsEnabled
        case lockOrientation
        case spokenAudioModeEnabled
        case vocalBoostEnabled
        case volumeLevelerEnabled
        case monoAudioEnabled
        case highResAudioEnabled
        case deEsserEnabled
        case lowCutFilterEnabled
    }
}

public enum AppTheme: String, Codable, Sendable {
    case light
    case dark
    case system
}

public enum BookCoverAspectRatio: Int, Codable, Sendable {
    case standard = 0 // 1:1.6
    case square = 1 // 1:1

    #if canImport(CoreGraphics)
    public var ratio: CGFloat {
        self == .square ? 1.0 : (1.0 / 1.6)
    }
    #else
    public var ratio: Double {
        self == .square ? 1.0 : (1.0 / 1.6)
    }
    #endif
}

// MARK: - API Error
public struct APIErrorResponse: Codable, Sendable {
    public struct ErrorDetail: Codable, Sendable {
        public let message: String
        public let code: String?

        public init(message: String, code: String? = nil) {
            self.message = message
            self.code = code
        }
    }
    public let error: ErrorDetail?
    public let message: String?
    public let success: Bool?

    public var parsedMessage: String? {
        if let detailMsg = error?.message, !detailMsg.isEmpty {
            return detailMsg
        }
        if let directMsg = message, !directMsg.isEmpty {
            return directMsg
        }
        return nil
    }

    enum CodingKeys: String, CodingKey {
        case error
        case message
        case success
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.success = try container.decodeIfPresent(Bool.self, forKey: .success)

        if let detail = try? container.decodeIfPresent(ErrorDetail.self, forKey: .error) {
            self.error = detail
            self.message = nil
        } else if let errorString = try? container.decodeIfPresent(String.self, forKey: .error) {
            self.error = ErrorDetail(message: errorString)
            self.message = nil
        } else {
            self.error = nil
            self.message = try container.decodeIfPresent(String.self, forKey: .message)
        }
    }
}

public struct ProgressSyncQueueItem: Codable, Sendable {
    public let sessionId: String
    public let episodeId: String?
    public let currentTime: TimeInterval
    public let duration: TimeInterval
    public let timeListened: TimeInterval
    public let dateAdded: Date

    public init(sessionId: String, episodeId: String? = nil, currentTime: TimeInterval, duration: TimeInterval, timeListened: TimeInterval, dateAdded: Date = Date()) {
        self.sessionId = sessionId
        self.episodeId = episodeId
        self.currentTime = currentTime
        self.duration = duration
        self.timeListened = timeListened
        self.dateAdded = dateAdded
    }
}

// MARK: - Library Stats (from /api/libraries/:id/stats)

public struct GenreCount: Codable, Sendable, Identifiable {
    public let genre: String
    public let count: Int

    public var id: String { genre }
}

public struct AuthorCount: Codable, Sendable, Identifiable {
    public let id: String
    public let name: String
    public let count: Int
}

public struct ItemStat: Codable, Sendable, Identifiable {
    public let id: String
    public let title: String
    public let duration: TimeInterval?
    public let size: Int64?
}

public struct LibraryStats: Codable, Sendable {
    public let totalItems: Int
    public let totalBooks: Int
    public let totalAuthors: Int
    public let totalSeries: Int
    public let totalDuration: TimeInterval
    public let totalSize: Int64
    public let addedLast30Days: Int
    public let numAudioTracks: Int
    public let genresWithCount: [GenreCount]
    public let authorsWithCount: [AuthorCount]
    public let longestItems: [ItemStat]
    public let largestItems: [ItemStat]
}

// MARK: - Author Summary (from /api/libraries/:id/authors)

public struct AuthorSummary: Identifiable, Codable, Sendable {
    public let id: String
    public let name: String
    public let asin: String?
    public let description: String?
    public let imagePath: String?
    public let libraryId: String?
    public let addedAt: Double?
    public let updatedAt: Double?
    public let numBooks: Int
}

// MARK: - Series Summary (from /api/libraries/:id/series)

public struct SeriesBookSummary: Identifiable, Codable, Sendable {
    public let id: String
    public let sequence: String?
    public let title: String
    public let cover: String?
}

public struct SeriesSummary: Identifiable, Codable, Sendable {
    public let id: String
    public let name: String
    public let nameIgnorePrefix: String?
    public let description: String?
    public let libraryId: String?
    public let addedAt: Double?
    public let updatedAt: Double?
    public let books: [SeriesBookSummary]?
    public let numBooks: Int?
}

// MARK: - Collection Summary (from /api/libraries/:id/collections)

public struct CollectionBookSummary: Identifiable, Codable, Sendable {
    public let id: String
    public let order: Int?
    public let title: String
    public let cover: String?
}

public struct CollectionSummary: Identifiable, Codable, Sendable {
    public let id: String
    public let name: String
    public let description: String?
    public let libraryId: String?
    public let addedAt: Double?
    public let updatedAt: Double?
    public let books: [CollectionBookSummary]?
    public let numBooks: Int?
}

// MARK: - Playlist Summary (from /api/libraries/:id/playlists)

public struct PlaylistItemSummary: Identifiable, Codable, Sendable {
    public let id: String
    public let order: Int?
    public let title: String
    public let cover: String?
}

public struct PlaylistSummary: Identifiable, Codable, Sendable {
    public let id: String
    public let name: String
    public let description: String?
    public let libraryId: String?
    public let userId: String?
    public let addedAt: Double?
    public let updatedAt: Double?
    public let items: [PlaylistItemSummary]?
}

// MARK: - Paginated Response

public struct PaginatedResponse<T: Codable & Sendable>: Codable, Sendable {
    public let results: [T]
    public let total: Int
    public let limit: Int
    public let page: Int
}

// MARK: - Downloads

public struct DownloadManifest: Codable, Sendable {
    public let libraryItemId: String
    public let title: String
    public let author: String
    public let duration: Double
    public let totalSize: Int64
    public let tracks: [DownloadManifestTrack]
}

public struct DownloadManifestTrack: Codable, Sendable {
    public let index: Int
    public let title: String
    public let url: String
    public let size: Int64
    public let duration: Double
    public let mimeType: String
}

public struct BookmarksResponse: Codable, Sendable {
    public let bookmarks: [Bookmark]
}


public struct SearchHistoryItem: Codable, Identifiable, Hashable, Sendable {
    public let id: String
    public let query: String
    public let createdAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case query
        case createdAt = "created_at"
    }
}
