import Foundation

@MainActor
public protocol LibraryServiceProtocol {
    func fetchLibraryItems(libraryId: String?) async throws -> [Book]
}

@MainActor
public class LiveLibraryService: LibraryServiceProtocol {
    public init() {}
    
    public func fetchLibraryItems(libraryId: String?) async throws -> [Book] {
        guard let libId = libraryId else {
            return []
        }
        let response = try await AudiobookshelfAPI.shared.getLibraryItems(libraryId: libId)
        return response.results
    }
}

@MainActor
public class MockLibraryService: LibraryServiceProtocol {
    public init() {}
    
    private let mockCovers = [
        "https://images.unsplash.com/photo-1544947950-fa07a98d237f?auto=format&fit=crop&q=80&w=400", // The Midnight Library
        "https://images.unsplash.com/photo-1451187580459-43490279c0fa?auto=format&fit=crop&q=80&w=400", // Project Hail Mary
        "https://images.unsplash.com/photo-1587876931567-564ce588bfbd?auto=format&fit=crop&q=80&w=400", // The Thursday Murder Club
        "https://images.unsplash.com/photo-1506126613408-eca07ce68773?auto=format&fit=crop&q=80&w=400", // Atomic Habits
        "https://images.unsplash.com/photo-1509316975850-ff9c5deb0cd9?auto=format&fit=crop&q=80&w=400", // Dune
        "https://images.unsplash.com/photo-1543002588-bfa74002ed7e?auto=format&fit=crop&q=80&w=400", // 1984
        "https://images.unsplash.com/photo-1448375240586-882707db888b?auto=format&fit=crop&q=80&w=400"  // The Hobbit
    ]
    
    private let bookTitles = [
        "The Midnight Library",
        "Project Hail Mary",
        "The Thursday Murder Club",
        "Atomic Habits",
        "Dune",
        "1984",
        "The Hobbit"
    ]
    
    private let authors = [
        "Matt Haig",
        "Andy Weir",
        "Richard Osman",
        "James Clear",
        "Frank Herbert",
        "George Orwell",
        "J.R.R. Tolkien"
    ]
    
    public func fetchLibraryItems(libraryId: String?) async throws -> [Book] {
        // Simulate network delay
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        return (0..<20).map { index in
            let titleIndex = index % bookTitles.count
            let coverURL = mockCovers[titleIndex]
            
            return Book(
                id: "book-\(index)",
                libraryId: libraryId ?? "lib1",
                folderId: nil,
                path: "/books/book\(index)",
                relPath: "book\(index)",
                isMissing: nil,
                libraryFiles: nil,
                media: BookMedia(
                    libraryFiles: [],
                    chapters: [],
                    duration: TimeInterval.random(in: 10000...50000),
                    size: 0,
                    metadata: BookMetadata(
                        title: bookTitles[titleIndex],
                        subtitle: nil,
                        authorName: authors[titleIndex],
                        narratorName: "Narrator \(index)",
                        seriesName: nil,
                        genres: ["Fiction", "Audiobookshelf Mock"],
                        publishedYear: "2024",
                        publishedDate: nil,
                        publisher: nil,
                        description: "This is a beautiful mock book description for \(bookTitles[titleIndex]) by \(authors[titleIndex]). Audiobookshelf app brings your personal audiobooks to life.",
                        isbn: nil,
                        asin: nil,
                        language: "en",
                        explicit: false
                    ),
                    coverPath: coverURL, // Set Unsplash URL as the coverPath!
                    tags: [],
                    audioFiles: [],
                    ebookFile: nil
                ),
                userMediaProgress: index % 3 == 0 ? MediaProgress(
                    id: "progress-\(index)",
                    libraryItemId: "book-\(index)",
                    episodeId: nil,
                    duration: 28800,
                    progress: Double.random(in: 0.1...0.9),
                    currentTime: 10000,
                    isFinished: false,
                    hideFromContinueListening: false,
                    lastUpdate: Date(),
                    startedAt: Date(),
                    finishedAt: nil
                ) : nil,
                addedAt: Date(),
                updatedAt: Date()
            )
        }
    }
}
