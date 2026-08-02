//
//  BookshelfView.swift
//  Audiobookphile
//
//  Main library view with glass design and parallax.
//  Compatible with Swift 6.3 and Skip.
//

import SwiftUI
import Observation

/// Main bookshelf/library view
public struct BookshelfView: View {
    @State var viewModel = BookshelfViewModel()
    var proMotion = ProMotionManager.shared
    @Environment(AppState.self) private var appState
    @State var showSearch = false
    @State var searchText = ""
    @State var scrollOffset: CGFloat = 0
    @State var selectedBookForDetails: Book?

    @State var selectedPill: LibraryPill = .library
    
    enum LibraryPill: String, CaseIterable {
        case library = "Library"
        case authors = "Authors"
        case narrators = "Narrators"
    }

    public init() {}

    public var body: some View {
        ZStack {
            // Animated background with particles
            backgroundLayer

            // Main content
            ScrollView {
                VStack(spacing: 24) {
                    // Main library grid
                    if selectedPill == .library {
                        libraryGridSection
                    } else {
                        // Placeholder for Authors/Narrators
                        VStack(spacing: 20) {
                            Spacer().frame(height: 100)
                            Image(systemName: "person.2.slash")
                                .font(.largeTitle)
                                .foregroundStyle(.secondary)
                            Text("\(selectedPill.rawValue) Coming Soon")
                                .font(.headline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .background(GeometryReader { proxy in
                    Color.clear.preference(key: ScrollOffsetPreferenceKey.self, value: proxy.frame(in: .named("scroll")).minY)
                })
            }
            .coordinateSpace(name: "scroll")
            .onPreferenceChange(ScrollOffsetPreferenceKey.self) { value in
                scrollOffset = value
            }
            #if os(iOS) || SKIP
            .refreshable {
                await viewModel.refresh(libraryId: appState.currentLibraryId, isAuthenticated: appState.isAuthenticated)
            }
            #endif

            // Search overlay
            if showSearch {
                searchOverlay
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .navigationDestination(item: $selectedBookForDetails) { book in
            BookDetailView(book: book)
        }
        .audiobookphileNavigationToolbar(title: "Library")
        #if os(iOS) || SKIP
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .principal) {
                Picker("Library View", selection: $selectedPill) {
                    Text("Library").tag(LibraryPill.library)
                    Text("Authors").tag(LibraryPill.authors)
                    Text("Narrators").tag(LibraryPill.narrators)
                }
                .pickerStyle(.segmented)
                .controlSize(.large)
                .tint(.appPrimary)
            }
            #if os(iOS) || SKIP
            ToolbarItem(placement: .topBarTrailing) {
                if selectedPill == .library {
                    Button(action: viewModel.showFilterOptions) {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                    }
                    .tint(.primary)
                }
            }
            #else
            ToolbarItem(placement: .primaryAction) {
                if selectedPill == .library {
                    Button(action: viewModel.showFilterOptions) {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                    }
                    .tint(.primary)
                }
            }
            #endif
        }
        .task(id: LibraryLoadTrigger(libraryId: appState.currentLibraryId, isAuthenticated: appState.isAuthenticated)) {
            await viewModel.loadLibrary(libraryId: appState.currentLibraryId, isAuthenticated: appState.isAuthenticated)
        }
        .applySensoryFeedback(trigger: selectedBookForDetails != nil)
    }

    // MARK: - Background Layer

    private var backgroundLayer: some View {
        Color.appBackground.ignoresSafeArea()
    }

    // MARK: - Navigation Pills removed in favor of Toolbar Picker

    // (Continue listening moved to HomeView)

    // MARK: - Library Grid

    private var libraryGridSection: some View {
        VStack(alignment: .leading, spacing: 16) {

            // Virtualized grid (adaptive columns for iPhone / iPad / Mac)
            LazyVGrid(
                columns: [
                    GridItem(.adaptive(minimum: 105, maximum: 160), spacing: 16)
                ],
                spacing: 24
            ) {
                if viewModel.isLoading && viewModel.filteredBooks.isEmpty {
                    ForEach(0..<6, id: \.self) { _ in
                        BookCardSkeleton()
                    }
                } else {
                    ForEach(viewModel.filteredBooks) { book in
                        BookCard(
                            book: book,
                            aspectRatio: viewModel.coverAspectRatio
                        ) {
                            selectedBookForDetails = book
                        }
                        .applyBookshelfScrollTransition()
                        .onAppear {
                            Task {
                                await viewModel.loadNextPageIfNeeded(
                                    currentBook: book,
                                    libraryId: appState.currentLibraryId,
                                    isAuthenticated: appState.isAuthenticated
                                )
                            }
                        }
                    }
                }
            }
            .padding(.horizontal)

            // Dynamic bottom loader when fetching next page from backend
            if viewModel.isLoadingNextPage {
                HStack(spacing: 12) {
                    ProgressView()
                        .tint(.cyan)
                    Text("Loading more audiobooks...")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity)
            }

            // Connection error state
            if let errorMessage = viewModel.errorMessage {
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.largeTitle)
                        .foregroundStyle(.yellow)
                    Text("Connection Failed")
                        .font(.headline)
                        .foregroundStyle(.white)
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)

                    Button("Log Out") {
                        AppState.shared.logout()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                    .padding(.top, 8)
                }
                .padding()
                .frame(maxWidth: .infinity)
                .glassCard()
                .padding(.horizontal)
            }
        }
    }

    // MARK: - Search Overlay

    private var searchOverlay: some View {
        VStack(spacing: 0) {
            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)

                TextField("Search books...", text: $searchText)
                    .textFieldStyle(.plain)
                    .foregroundStyle(.white)

                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .glassCard()
            .padding()

            // Search results
            if !searchText.isEmpty {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(viewModel.searchResults(for: searchText)) { book in
                            GlassBookCard(book: book) {
                                selectedBookForDetails = book
                                showSearch = false
                            }
                        }
                    }
                    .padding()
                }
            }

            Spacer()
        }
        .glassCard(cornerRadius: 16)
    }

    // MARK: - End BookshelfView
}

// MARK: - Continue Listening Card

public struct ContinueListeningCard: View {
    public let book: Book
    public let onTap: () -> Void

    public init(book: Book, onTap: @escaping () -> Void) {
        self.book = book
        self.onTap = onTap
    }

    public var body: some View {
        Button(action: {
            onTap()
        }) {
            VStack(alignment: .leading, spacing: 8) {
                // Cover image
                Color.clear
                    .frame(width: 120, height: 120)
                    .overlay {
                        if let url = coverURL {
                            ZStack {
                                // Blurred background
                                SmartAsyncImage(url: url) { image in
                                    image
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                } placeholder: {
                                    fallbackCover
                                }
                                .blur(radius: 15)
                                .overlay(Color.black.opacity(0.4))

                                // Fit image
                                SmartAsyncImage(url: url) { image in
                                    image
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                } placeholder: {
                                    Color.clear
                                }
                            }
                        } else {
                            fallbackCover
                        }
                    }
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(
                                LinearGradient(
                                    colors: [.white.opacity(0.35), .white.opacity(0.05)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
                    .shadow(color: Color.cyan.opacity(0.3), radius: 10, x: 0, y: 6)

                // Title & Progress with strict height
                VStack(alignment: .leading, spacing: 4) {
                    Text(book.title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .lineLimit(2)
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.leading)

                    if let progress = book.userMediaProgress {
                        HStack {
                            Text("\(Int(progress.progress * 100))%")
                                .font(.caption.bold())
                                .foregroundStyle(.cyan)

                            Spacer()

                            Image(systemName: "play.circle.fill")
                                .font(.body)
                                .foregroundStyle(.cyan)
                                .shadow(color: .cyan.opacity(0.6), radius: 4)
                        }
                    } else {
                        Spacer(minLength: 0)
                            .frame(height: 16)
                    }
                }
                .frame(height: 56, alignment: .topLeading)
            }
            .frame(width: 120)
            .contentShape(Rectangle())
        }
        .buttonStyle(.liquid)
    }

    private var fallbackCover: some View {
        ZStack {
            Color(white: 0.2)

            VStack(spacing: 6) {
                Image(systemName: "book.closed.fill")
                    .font(.headline)
                    .foregroundStyle(.white.opacity(0.3))

                Text(book.title)
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundStyle(.white.opacity(0.4))
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 6)
            }
        }
        .frame(width: 120, height: 120)
    }

    private var coverURL: URL? {
        if let path = book.coverPath, path.hasPrefix("http") {
            return URL(string: path)
        }
        return AppState.shared.getCoverURL(itemId: book.id, updatedAt: book.updatedAt)
    }
}

// MARK: - View Model

@Observable
@MainActor
public class BookshelfViewModel {
    public var books: [Book] = []
    public var filteredBooks: [Book] = []
    public var continueListening: [Book] = []
    public var currentLibrary: Library?
    public var selectedBook: Book?
    public var isLoading = false
    public var errorMessage: String?

    // Pagination State
    public var currentPage: Int = 0
    public var pageSize: Int = 0 // 0 means unlimited by default from backend
    public var totalBooksCount: Int = 0
    public var hasMorePages: Bool = false
    public var isLoadingNextPage: Bool = false
    public var currentSort: String = "addedAt"
    public var currentDesc: Bool = true

    public var totalBooks: Int { totalBooksCount > 0 ? totalBooksCount : books.count }
    public var inProgressCount: Int { continueListening.count }
    public var coverAspectRatio: CGFloat {
        // Enforce exact 1:1 square ratio for all audiobooks across all libraries
        return 1.0
    }

    public var totalDurationFormatted: String {
        let totalSeconds = books.reduce(0) { $0 + $1.duration }
        let hours = Int(totalSeconds) / 3600
        return "\(hours)"
    }

    private var customService: LibraryServiceProtocol?

    public init(service: LibraryServiceProtocol? = nil) {
        self.customService = service
    }

    public struct BookshelfCacheData: Codable, Sendable {
        public let books: [Book]
        public let total: Int
        public let page: Int
    }

    public func loadLibrary(libraryId: String?, isAuthenticated: Bool, sort: String = "addedAt", desc: Bool = true) async {
        let cacheKey = "bookshelf_\(libraryId ?? "default")_\(sort)_\(desc)"

        self.currentPage = 0
        self.currentSort = sort
        self.currentDesc = desc

        // Instantly populate from disk cache if available for smooth navigation
        if let cached = await LocalCacheService.shared.load(forKey: cacheKey, as: BookshelfCacheData.self), !cached.books.isEmpty {
            self.books = cached.books
            self.filteredBooks = cached.books
            self.totalBooksCount = cached.total
            self.currentPage = cached.page
            self.hasMorePages = pageSize > 0 && self.books.count < cached.total
        } else {
            isLoading = true
        }

        errorMessage = nil

        let service = customService ?? (isAuthenticated ? LiveLibraryService() : MockLibraryService())

        // Sync current library from AppState
        if let id = libraryId {
            self.currentLibrary = AppState.shared.libraries.first { $0.id == id }
        }

        do {
            let response = try await service.fetchPaginatedLibraryItems(
                libraryId: libraryId,
                page: 0,
                limit: pageSize,
                sort: sort,
                desc: desc
            )
            self.books = response.results
            self.filteredBooks = response.results
            self.totalBooksCount = response.total
            self.currentPage = 0
            self.hasMorePages = pageSize > 0 && self.books.count < response.total
            
            let cacheData = BookshelfCacheData(books: response.results, total: response.total, page: 0)
            await LocalCacheService.shared.save(cacheData, forKey: cacheKey)

            // Continue Listening is server-driven
            self.continueListening = try await service.fetchContinueListening(libraryId: libraryId)
        } catch {
            print("[BookshelfViewModel] Failed to load library items: \(error)")
            if books.isEmpty {
                self.errorMessage = error.localizedDescription
            }
        }

        isLoading = false
    }

    public func loadNextPageIfNeeded(currentBook book: Book, libraryId: String?, isAuthenticated: Bool) async {
        guard hasMorePages, !isLoadingNextPage, !isLoading else { return }

        // Trigger loading when reaching within 6 books of the end of the loaded list
        guard let index = filteredBooks.firstIndex(where: { $0.id == book.id }),
              index >= filteredBooks.count - 6 else {
            return
        }

        isLoadingNextPage = true
        let nextPage = currentPage + 1

        let service = customService ?? (isAuthenticated ? LiveLibraryService() : MockLibraryService())

        do {
            let response = try await service.fetchPaginatedLibraryItems(
                libraryId: libraryId,
                page: nextPage,
                limit: pageSize,
                sort: currentSort,
                desc: currentDesc
            )

            // Deduplicate items against already loaded items
            let existingIds = Set(self.books.map { $0.id })
            let newItems = response.results.filter { !existingIds.contains($0.id) }

            if !newItems.isEmpty {
                self.books.append(contentsOf: newItems)
                self.filteredBooks = self.books
                self.currentPage = nextPage
                self.totalBooksCount = response.total
            }

            self.hasMorePages = pageSize > 0 && self.books.count < response.total
        } catch {
            print("[BookshelfViewModel] Failed to fetch page \(nextPage): \(error)")
        }

        isLoadingNextPage = false
    }

    public func refresh(libraryId: String?, isAuthenticated: Bool) async {
        await loadLibrary(libraryId: libraryId, isAuthenticated: isAuthenticated, sort: currentSort, desc: currentDesc)
    }

    public func selectBook(_ book: Book) {
        selectedBook = book
    }

    public func playBook(_ book: Book) {
        print("Playing: \(book.title)")
    }

    public func searchResults(for query: String) -> [Book] {
        guard !query.isEmpty else { return [] }
        return books.filter {
            $0.title.localizedCaseInsensitiveContains(query) ||
            ($0.author?.localizedCaseInsensitiveContains(query) ?? false)
        }
    }

    public func showFilterOptions() {}
    public func showSettings() {}
    public func showDownloads() {}
    public func showStats() {}
}

public struct LibraryLoadTrigger: Equatable {
    public let libraryId: String?
    public let isAuthenticated: Bool
    
    public init(libraryId: String?, isAuthenticated: Bool) {
        self.libraryId = libraryId
        self.isAuthenticated = isAuthenticated
    }
}
