//
//  MediaModels.swift
//  Audiobookphile
//
//  Core data models for Audiobookphile, fully Swift 6.3 and Skip compatible.
//

import Foundation
import CoreGraphics

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

extension Book {
    public init(id: String, title: String, author: String?, duration: TimeInterval? = nil) {
        self.id = id
        self.libraryId = nil
        self.folderId = nil
        self.path = nil
        self.relPath = nil
        self.isMissing = false
        self.libraryFiles = nil
        self.media = BookMedia(
            libraryFiles: nil,
            chapters: nil,
            duration: duration,
            size: nil,
            metadata: BookMetadata(title: title, authorName: author),
            coverPath: nil,
            tags: nil,
            audioFiles: nil,
            ebookFile: nil
        )
        self.userMediaProgress = nil
        self.addedAt = nil
        self.updatedAt = nil
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

    public init(title: String, subtitle: String? = nil, authorName: String? = nil, narratorName: String? = nil, seriesName: String? = nil, genres: [String] = [], publishedYear: String? = nil, publishedDate: String? = nil, publisher: String? = nil, description: String? = nil, isbn: String? = nil, asin: String? = nil, language: String? = nil, explicit: Bool = false) {
        self.title = title
        self.subtitle = subtitle
        self.authorName = authorName
        self.narratorName = narratorName
        self.seriesName = seriesName
        self.genres = genres
        self.publishedYear = publishedYear
        self.publishedDate = publishedDate
        self.publisher = publisher
        self.description = description
        self.isbn = isbn
        self.asin = asin
        self.language = language
        self.explicit = explicit
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        title = (try container.decodeIfPresent(String.self, forKey: .title)) ?? "Unknown Title"
        subtitle = try container.decodeIfPresent(String.self, forKey: .subtitle)
        authorName = try container.decodeIfPresent(String.self, forKey: .authorName)
        narratorName = try container.decodeIfPresent(String.self, forKey: .narratorName)
        seriesName = try container.decodeIfPresent(String.self, forKey: .seriesName)
        genres = (try container.decodeIfPresent([String].self, forKey: .genres)) ?? []
        publishedYear = try container.decodeIfPresent(String.self, forKey: .publishedYear)
        publishedDate = try container.decodeIfPresent(String.self, forKey: .publishedDate)
        publisher = try container.decodeIfPresent(String.self, forKey: .publisher)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        isbn = try container.decodeIfPresent(String.self, forKey: .isbn)
        asin = try container.decodeIfPresent(String.self, forKey: .asin)
        language = try container.decodeIfPresent(String.self, forKey: .language)
        explicit = (try container.decodeIfPresent(Bool.self, forKey: .explicit)) ?? false
    }
}

extension BookMetadata {
    public init(title: String, authorName: String?) {
        self.title = title
        self.subtitle = nil
        self.authorName = authorName
        self.narratorName = nil
        self.seriesName = nil
        self.genres = []
        self.publishedYear = nil
        self.publishedDate = nil
        self.publisher = nil
        self.description = nil
        self.isbn = nil
        self.asin = nil
        self.language = nil
        self.explicit = false
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
