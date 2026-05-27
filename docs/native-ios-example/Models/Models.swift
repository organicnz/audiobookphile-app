//
//  Models.swift
//  AudiobookshelfClient
//
//  Core data models for Audiobookshelf
//

import Foundation

// MARK: - Media Type
enum MediaType: String, Codable {
    case book = "book"
    case podcast = "podcast"
}

// MARK: - Book
struct Book: Identifiable, Codable, Hashable {
    let id: String
    let libraryId: String
    let folderId: String?
    let path: String
    let relPath: String
    
    // Media Info
    let media: BookMedia
    
    // Metadata
    var title: String {
        media.metadata.title
    }
    
    var author: String? {
        media.metadata.authorName
    }
    
    var description: String? {
        media.metadata.description
    }
    
    var coverPath: String? {
        media.coverPath
    }
    
    var duration: TimeInterval {
        media.duration
    }
    
    var chapters: [Chapter] {
        media.chapters
    }
    
    // Progress
    let userMediaProgress: MediaProgress?
    
    // Timestamps
    let addedAt: Date
    let updatedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id, libraryId, folderId, path, relPath, media
        case userMediaProgress, addedAt, updatedAt
    }
}

// MARK: - Book Media
struct BookMedia: Codable, Hashable {
    let libraryFiles: [LibraryFile]
    let chapters: [Chapter]
    let duration: TimeInterval
    let size: Int64
    let metadata: BookMetadata
    let coverPath: String?
    let tags: [String]
    let audioFiles: [AudioFile]
    let ebookFile: EbookFile?
    
    enum CodingKeys: String, CodingKey {
        case libraryFiles, chapters, duration, size, metadata
        case coverPath, tags, audioFiles, ebookFile
    }
}

// MARK: - Book Metadata
struct BookMetadata: Codable, Hashable {
    let title: String
    let subtitle: String?
    let authorName: String?
    let narratorName: String?
    let seriesName: String?
    let genres: [String]
    let publishedYear: String?
    let publishedDate: String?
    let publisher: String?
    let description: String?
    let isbn: String?
    let asin: String?
    let language: String?
    let explicit: Bool
    
    enum CodingKeys: String, CodingKey {
        case title, subtitle
        case authorName, narratorName, seriesName
        case genres, publishedYear, publishedDate, publisher
        case description, isbn, asin, language, explicit
    }
}

// MARK: - Chapter
struct Chapter: Identifiable, Codable, Hashable {
    var id: Int
    let title: String
    let start: TimeInterval
    let end: TimeInterval
    
    var duration: TimeInterval {
        end - start
    }
}

// MARK: - Audio File
struct AudioFile: Identifiable, Codable, Hashable {
    var id: String {
        ino
    }
    let index: Int
    let ino: String
    let metadata: AudioMetadata
    let duration: TimeInterval
    let bitRate: Int?
    let language: String?
    let codec: String?
    let mimeType: String
}

struct AudioMetadata: Codable, Hashable {
    let filename: String
    let ext: String
    let path: String
    let relPath: String
    let size: Int64
    let mtimeMs: Int64
    let ctimeMs: Int64
    let birthtimeMs: Int64
}

// MARK: - Library File
struct LibraryFile: Identifiable, Codable, Hashable {
    var id: String {
        ino
    }
    let ino: String
    let metadata: FileMetadata
    let isSupplementary: Bool?
    let fileType: String
}

struct FileMetadata: Codable, Hashable {
    let filename: String
    let ext: String
    let path: String
    let relPath: String
    let size: Int64
    let mtimeMs: Int64
    let ctimeMs: Int64
    let birthtimeMs: Int64
}

// MARK: - Ebook File
struct EbookFile: Codable, Hashable {
    let ino: String
    let metadata: FileMetadata
    let ebookFormat: String
}

// MARK: - Media Progress
struct MediaProgress: Codable, Hashable {
    let id: String
    let libraryItemId: String
    let episodeId: String?
    let duration: TimeInterval
    let progress: Double // 0.0 to 1.0
    let currentTime: TimeInterval
    let isFinished: Bool
    let hideFromContinueListening: Bool
    let lastUpdate: Date
    let startedAt: Date
    let finishedAt: Date?
    
    var progressPercentage: Int {
        Int(progress * 100)
    }
    
    var timeRemaining: TimeInterval {
        duration - currentTime
    }
}

// MARK: - Playback Session
struct PlaybackSession: Codable {
    let id: String
    let userId: String
    let libraryId: String
    let libraryItemId: String
    let episodeId: String?
    
    // Display info
    let displayTitle: String
    let displayAuthor: String
    let coverPath: String?
    
    // Playback info
    let duration: TimeInterval
    let playMethod: Int
    let mediaPlayer: String
    let mediaType: String
    
    // Audio tracks and chapters
    let audioTracks: [AudioTrack]
    let chapters: [Chapter]
    
    // State
    let currentTime: TimeInterval
    let playbackRate: Float
    let startedAt: Date
    let updatedAt: Date
}

// MARK: - Audio Track
struct AudioTrack: Identifiable, Codable {
    let index: Int
    let startOffset: TimeInterval
    let duration: TimeInterval
    let title: String?
    let contentUrl: String
    let mimeType: String
    let codec: String?
    
    var id: Int {
        index
    }
}

// MARK: - Library
struct Library: Identifiable, Codable {
    let id: String
    let name: String
    let folders: [LibraryFolder]
    let displayOrder: Int
    let icon: String
    let mediaType: MediaType
    let provider: String
    let settings: LibrarySettings
    let createdAt: Date
    let lastUpdate: Date
}

struct LibraryFolder: Identifiable, Codable {
    let id: String
    let fullPath: String
    let libraryId: String
    let addedAt: Date
}

struct LibrarySettings: Codable {
    let coverAspectRatio: Int
    let disableWatcher: Bool
    let skipMatchingMediaWithAsin: Bool
    let skipMatchingMediaWithIsbn: Bool
    let autoScanCronExpression: String?
}

// MARK: - User
struct User: Identifiable, Codable {
    let id: String
    let username: String
    let email: String?
    let type: String
    let token: String
    let refreshToken: String?
    let mediaProgress: [MediaProgress]
    let seriesHideFromContinueListening: [String]
    let bookmarks: [Bookmark]
    let isActive: Bool
    let isLocked: Bool
    let lastSeen: Date?
    let createdAt: Date
    let permissions: UserPermissions
    let librariesAccessible: [String]
    let itemTagsAccessible: [String]
}

struct Bookmark: Identifiable, Codable {
    let libraryItemId: String
    let title: String
    let time: TimeInterval
    let createdAt: Date
    
    var id: String {
        "\(libraryItemId)-\(time)"
    }
}

struct UserPermissions: Codable {
    let download: Bool
    let update: Bool
    let delete: Bool
    let upload: Bool
    let accessAllLibraries: Bool
    let accessAllTags: Bool
    let accessExplicitContent: Bool
}

// MARK: - Podcast (for future support)
struct Podcast: Identifiable, Codable {
    let id: String
    let libraryId: String
    let media: PodcastMedia
    let addedAt: Date
    let updatedAt: Date
}

struct PodcastMedia: Codable {
    let metadata: PodcastMetadata
    let coverPath: String?
    let tags: [String]
    let episodes: [PodcastEpisode]
    let autoDownloadEpisodes: Bool
    let autoDownloadSchedule: String?
}

struct PodcastMetadata: Codable {
    let title: String
    let author: String?
    let description: String?
    let releaseDate: String?
    let genres: [String]
    let feedUrl: String?
    let imageUrl: String?
    let itunesPageUrl: String?
    let itunesId: String?
    let itunesArtistId: String?
    let explicit: Bool
    let language: String?
}

struct PodcastEpisode: Identifiable, Codable {
    let id: String
    let index: Int
    let title: String
    let subtitle: String?
    let description: String?
    let pubDate: String?
    let audioFile: AudioFile?
    let publishedAt: Date?
    let addedAt: Date
    let updatedAt: Date
}

// MARK: - Server Connection
struct ServerConnection: Codable {
    let url: String
    let name: String?
    let lastConnected: Date
    
    var displayName: String {
        name ?? url
    }
}

struct RecentServer: Identifiable, Codable, Hashable {
    let id: String
    let address: String
    let username: String?
}

// MARK: - App Settings
struct AppSettings: Codable {
    var jumpForwardTime: Int = 30
    var jumpBackwardsTime: Int = 10
    var lockScreenControls: Bool = true
    var autoDownloadPodcasts: Bool = false
    var sleepTimerAutoStart: Bool = false
    var sleepTimerDefaultTime: Int = 900 // 15 minutes
    var theme: AppTheme = .system
    var bookCoverAspectRatio: BookCoverAspectRatio = .square
}

enum AppTheme: String, Codable {
    case light
    case dark
    case system
}

enum BookCoverAspectRatio: Int, Codable {
    case square = 1
    case standard = 16 // 1.6:1
    
    var ratio: CGFloat {
        self == .square ? 1.0 : 1.6
    }
}
