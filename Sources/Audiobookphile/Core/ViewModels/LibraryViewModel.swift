//
//  LibraryViewModel.swift
//  Audiobookphile
//
//  View model for library browsing: library selection, loading,
//  filtering and search.
//

import Foundation
import Observation

@MainActor
@Observable
public final class LibraryViewModel: BaseViewModel {
    public static let shared = LibraryViewModel()

    // MARK: - Public state

    /// All books loaded for the current library.
    public var books: [Book] = []

    /// The books after the active filter or search has been applied.
    public var filteredBooks: [Book] = []

    /// Books the user has started but not finished.
    public var continueListening: [Book] = []

    /// Whether the library is currently being loaded.
    public var isLoading = false

    /// The sort key used when fetching library items.
    public var currentSort = "addedAt"

    /// Whether the sort is descending.
    public var sortDescending = true

    // MARK: - Derived state

    /// The libraries available on the connected server.
    public var libraries: [Library] { AppState.shared.libraries }

    /// The library currently selected by the user.
    public var currentLibrary: Library? { AppState.shared.currentLibrary }

    /// The number of books in the loaded library.
    public var totalBooks: Int { books.count }

    /// The number of books with listening progress.
    public var inProgressCount: Int { continueListening.count }

    /// The library currently selected by the user.
    public var selectedLibraryId: String? {
        get { AppState.shared.currentLibraryId }
        set {
            AppState.shared.currentLibraryId = newValue
            if let id = newValue {
                UserDefaults.standard.set(id, forKey: StorageKeys.lastLibraryId)
            }
        }
    }

    private var service: LibraryServiceProtocol

    public init(service: LibraryServiceProtocol? = nil) {
        self.service = service ?? LiveLibraryService()
    }

    // MARK: - Loading

    /// Loads the books of the current library. When not authenticated, a
    /// mock service is used so previews and onboarding stay usable.
    public func load(isAuthenticated: Bool) async {
        let libraryId = selectedLibraryId
        isLoading = true
        errorMessage = nil

        let activeService = isAuthenticated ? service : MockLibraryService()
        do {
            let response = try await activeService.fetchPaginatedLibraryItems(
                libraryId: libraryId,
                page: 0,
                limit: 0,
                sort: currentSort,
                desc: sortDescending
            )
            books = response.results
            filteredBooks = response.results
            continueListening = try await activeService.fetchContinueListening(libraryId: libraryId)
        } catch {
            print("[LibraryViewModel] Failed to load library: \(error)")
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    /// Reloads the current library with the existing sort settings.
    public func refresh(isAuthenticated: Bool) async {
        await load(isAuthenticated: isAuthenticated)
    }

    /// Switches to the given library and loads its books.
    public func selectLibrary(_ libraryId: String?) async {
        selectedLibraryId = libraryId
        await load(isAuthenticated: AppState.shared.isAuthenticated)
    }

    // MARK: - Filtering & search

    /// Returns books matching the query against title or author.
    public func searchResults(for query: String) -> [Book] {
        guard !query.isEmpty else { return books }
        return books.filter {
            $0.title.localizedCaseInsensitiveContains(query) ||
            ($0.author?.localizedCaseInsensitiveContains(query) ?? false)
        }
    }

    /// Restricts the displayed books to a single genre.
    public func filter(byGenre genre: String) {
        filteredBooks = books.filter { $0.media.metadata.genres.contains(genre) }
    }

    /// Restricts the displayed books to a single author.
    public func filter(byAuthor author: String) {
        filteredBooks = books.filter { $0.author == author }
    }

    /// Removes the active genre or author filter.
    public func clearFilters() {
        filteredBooks = books
    }
}
