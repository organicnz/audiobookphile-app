//
//  BookshelfView.swift
//  Audiobookshelf
//
//  Main library view with glass design and parallax.
//  Compatible with Swift 6.3 and Skip.
//

import SwiftUI

/// Main bookshelf/library view
public struct BookshelfView: View {
    @StateObject var viewModel = BookshelfViewModel()
    @StateObject var proMotion = ProMotionManager.shared
    @State var showSearch = false
    @State var searchText = ""
    @State var scrollOffset: CGFloat = 0
    
    public init() {}
    
    public var body: some View {
        ZStack {
            // Animated background with particles
            backgroundLayer
            
            // Main content
            ScrollView {
                VStack(spacing: 24) {
                    // Header section with parallax
                    headerSection
                        .offset(y: scrollOffset * 0.3)
                    
                    // Continue listening section
                    if !viewModel.continueListening.isEmpty {
                        continueListeningSection
                    }
                    
                    // Main library grid
                    libraryGridSection
                }
                .background(
                    GeometryReader { geometry in
                        Color.clear
                            .preference(
                                key: ScrollOffsetPreferenceKey.self,
                                value: geometry.frame(in: .global).minY
                            )
                    }
                )
            }
            .coordinateSpace(name: "scroll")
            .onPreferenceChange(ScrollOffsetPreferenceKey.self) { value in
                scrollOffset = value
            }
            #if os(iOS) || SKIP
            .refreshable {
                await viewModel.refresh()
            }
            #endif
            
            // Search overlay
            if showSearch {
                searchOverlay
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .ignoresSafeArea(edges: .top)
        #if os(iOS) || SKIP
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            toolbarContent
        }
        .sheet(item: $viewModel.selectedBook) { book in
            BookDetailView(book: book)
        }
        .task {
            await viewModel.loadLibrary()
        }
    }
    
    // MARK: - Background Layer
    
    private var backgroundLayer: some View {
        ZStack {
            // Base gradient
            LinearGradient(
                colors: [
                    Color(red: 0.1, green: 0.1, blue: 0.2),
                    Color(red: 0.15, green: 0.1, blue: 0.25),
                    Color(red: 0.1, green: 0.05, blue: 0.15)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            // Particles
            GlassParticlesView(
                particleCount: 30,
                colors: [.blue, .purple, .cyan]
            )
            .opacity(0.4)
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(spacing: 16) {
            // Library name
            Text(viewModel.currentLibrary?.name ?? "Library")
                .font(.system(size: 42, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .shadow(radius: 10)
            
            // Stats row
            HStack(spacing: 16) {
                statItem(
                    icon: "book.fill",
                    value: "\(viewModel.totalBooks)",
                    label: "Books"
                )
                
                statItem(
                    icon: "clock.fill",
                    value: viewModel.totalDurationFormatted,
                    label: "Hours"
                )
                
                statItem(
                    icon: "headphones",
                    value: "\(viewModel.inProgressCount)",
                    label: "In Progress"
                )
            }
            .glassCard()
            .padding(.horizontal)
        }
        .padding(.top, 40)
    }
    
    private func statItem(icon: String, value: String, label: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.cyan)
            
            Text(value)
                .font(.headline)
                .fontWeight(.bold)
                .foregroundStyle(.white)
            
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - Continue Listening
    
    private var continueListeningSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Continue Listening")
                .font(.title3)
                .fontWeight(.bold)
                .foregroundStyle(.white)
                .padding(.horizontal)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(viewModel.continueListening) { book in
                        ContinueListeningCard(book: book) {
                            viewModel.playBook(book)
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
    }
    
    // MARK: - Library Grid
    
    private var libraryGridSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Section header
            HStack {
                Text("All Books")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
                
                Spacer()
                
                // Filter/sort button
                Button(action: viewModel.showFilterOptions) {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                        .font(.title3)
                        .foregroundStyle(.white)
                }
            }
            .padding(.horizontal)
            
            // Virtualized grid (optimized for 1000+ books)
            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: 16),
                    GridItem(.flexible(), spacing: 16),
                    GridItem(.flexible(), spacing: 16)
                ],
                spacing: 24
            ) {
                ForEach(viewModel.filteredBooks) { book in
                    BookCard(
                        book: book,
                        aspectRatio: viewModel.coverAspectRatio
                    ) {
                        viewModel.selectBook(book)
                    }
                }
            }
            .padding(.horizontal)
            
            // Loading indicator
            if viewModel.isLoading {
                HStack {
                    Spacer()
                    ProgressView()
                        .tint(.white)
                    Spacer()
                }
                .padding()
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
                                viewModel.selectBook(book)
                                showSearch = false
                            }
                        }
                    }
                    .padding()
                }
            }
            
            Spacer()
        }
        .background(.ultraThinMaterial)
    }
    
    private var leadingPlacement: ToolbarItemPlacement {
        #if os(iOS) || SKIP
        return .navigationBarLeading
        #else
        return .navigation
        #endif
    }
    
    private var trailingPlacement: ToolbarItemPlacement {
        #if os(iOS) || SKIP
        return .navigationBarTrailing
        #else
        return .primaryAction
        #endif
    }

    // MARK: - Toolbar
    
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: leadingPlacement) {
            Button(action: { showSearch.toggle() }) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.white)
            }
        }
        
        ToolbarItem(placement: trailingPlacement) {
            Menu {
                Button(action: viewModel.showSettings) {
                    Label("Settings", systemImage: "gear")
                }
                
                Button(action: viewModel.showDownloads) {
                    Label("Downloads", systemImage: "arrow.down.circle")
                }
                
                Button(action: viewModel.showStats) {
                    Label("Stats", systemImage: "chart.bar")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .foregroundStyle(.white)
            }
        }
    }
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
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                // Cover
                AsyncImage(url: coverURL) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Color.gray.opacity(0.3)
                }
                .frame(width: 140, height: 140)
                .cornerRadius(12)
                .shadow(radius: 10)
                
                // Title
                Text(book.title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .lineLimit(2)
                    .foregroundStyle(.white)
                
                // Progress
                if let progress = book.userMediaProgress {
                    HStack {
                        Text("\(progress.progressPercentage)%")
                            .font(.caption)
                            .foregroundStyle(.cyan)
                        
                        Spacer()
                        
                        Image(systemName: "play.circle.fill")
                            .foregroundStyle(.cyan)
                    }
                }
            }
            .frame(width: 140)
        }
    }
    
    private var coverURL: URL? {
        guard let path = book.coverPath else { return nil }
        return URL(string: path)
    }
}

// MARK: - View Model

@MainActor
public class BookshelfViewModel: ObservableObject {
    @Published public var books: [Book] = []
    @Published public var filteredBooks: [Book] = []
    @Published public var continueListening: [Book] = []
    @Published public var currentLibrary: Library?
    @Published public var selectedBook: Book?
    @Published public var isLoading = false
    
    public var totalBooks: Int { books.count }
    public var inProgressCount: Int { continueListening.count }
    public var coverAspectRatio: CGFloat = 1.0
    
    public var totalDurationFormatted: String {
        let totalSeconds = books.reduce(0) { $0 + $1.duration }
        let hours = Int(totalSeconds) / 3600
        return "\(hours)"
    }
    
    public init() {}
    
    public func loadLibrary() async {
        isLoading = true
        
        // Generate mock books
        books = (0..<20).map { sampleBook(index: $0) }
        filteredBooks = books
        continueListening = books.filter { $0.userMediaProgress != nil }.prefix(5).map { $0 }
        
        isLoading = false
    }
    
    public func refresh() async {
        await loadLibrary()
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

// MARK: - Book Detail View

public struct BookDetailView: View {
    public let book: Book
    
    public init(book: Book) {
        self.book = book
    }
    
    public var body: some View {
        NavigationStack {
            ZStack {
                AnimatedGradientBackground()
                ScrollView {
                    VStack(spacing: 24) {
                        Text(book.title)
                            .font(.title.bold())
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.center)
                            .padding()
                        
                        if let author = book.author {
                            Text(author)
                                .font(.headline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }
}

// Sample data helper
private func sampleBook(index: Int) -> Book {
    Book(
        id: "book-\(index)",
        libraryId: "lib1",
        folderId: nil,
        path: "/books/book\(index)",
        relPath: "book\(index)",
        media: BookMedia(
            libraryFiles: [],
            chapters: [],
            duration: TimeInterval.random(in: 10000...50000),
            size: 0,
            metadata: BookMetadata(
                title: [
                    "The Midnight Library",
                    "Project Hail Mary",
                    "The Thursday Murder Club",
                    "Atomic Habits",
                    "Dune",
                    "1984",
                    "The Hobbit"
                ].randomElement() ?? "Book \(index)",
                subtitle: nil,
                authorName: [
                    "Matt Haig",
                    "Andy Weir",
                    "Richard Osman",
                    "James Clear",
                    "Frank Herbert"
                ].randomElement(),
                narratorName: nil,
                seriesName: nil,
                genres: [],
                publishedYear: "2024",
                publishedDate: nil,
                publisher: nil,
                description: nil,
                isbn: nil,
                asin: nil,
                language: "en",
                explicit: false
            ),
            coverPath: nil,
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
