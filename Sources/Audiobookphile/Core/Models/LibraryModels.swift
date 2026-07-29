//
//  LibraryModels.swift
//  Audiobookphile
//
//  Core models for Library-related data.
//

import Foundation

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
