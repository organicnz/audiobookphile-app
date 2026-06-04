//
//  BookshelfView.swift
//  AudiobookphileClient
//
//  Main library view with glass design and parallax
//  Translates: pages/bookshelf.vue
//

import SwiftUI

/// Main bookshelf/library view
struct BookshelfView: View {
    @StateObject private var viewModel = BookshelfViewModel()
    @ObservedObject private var proMotion = ProMotionManager.shared
    @State private var showSearch = false
    @State private var searchText = ""
    @State private var scrollOffset: CGFloat = 0
    
    var body: some View {
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
            .onPreferenceChange(ScrollOffsetPreferenceKey.self) { value in
                scrollOffset = value
            }
            .refreshable {
                await viewModel.refresh()
            }
            
            // Search overlay
            if showSearch {
                searchOverlay
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .ignoresSafeArea(edges: .top)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            toolbarContent
        }
        .sheet(item: $viewModel.selectedBook) { book in
            BookDetailView(book: book)
        }
        .optimizedForProMotion()
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
                particleCount: 50,
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
                .font(.system(size: 52, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .shadow(radius: 10)
            
            // Stats row
            HStack(spacing: 24) {
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
            .glassCard(padding: 20)
            .padding(.horizontal)
        }
        .padding(.top, 60)
    }
    
    private func statItem(icon: String, value: String, label: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(.blue)
            
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
            
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
                .font(.title2)
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
                    .font(.title2)
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
                            BookCard(book: book, aspectRatio: viewModel.coverAspectRatio) {
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
        .ignoresSafeArea()
    }
    
    // MARK: - Toolbar
    
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .navigationBarLeading) {
            Button(action: { showSearch.toggle() }) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.white)
            }
        }
        
        ToolbarItem(placement: .navigationBarTrailing) {
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

struct ContinueListeningCard: View {
    let book: Book
    let onTap: () -> Void
    
    var body: some View {
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
                .frame(width: 160, height: 160)
                .clipShape(RoundedRectangle(cornerRadius: 12))
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
                            .foregroundStyle(.blue)
                        
                        Spacer()
                        
                        Image(systemName: "play.circle.fill")
                            .foregroundStyle(.blue)
                    }
                }
            }
            .frame(width: 160)
        }
    }
    
    private var coverURL: URL? {
        guard let path = book.coverPath else { return nil }
        return URL(string: path)
    }
}

// MARK: - View Model

@MainActor
class BookshelfViewModel: ObservableObject {
    @Published var books: [Book] = []
    @Published var filteredBooks: [Book] = []
    @Published var continueListening: [Book] = []
    @Published var currentLibrary: Library?
    @Published var selectedBook: Book?
    @Published var isLoading = false
    
    var totalBooks: Int { books.count }
    var inProgressCount: Int { continueListening.count }
    var coverAspectRatio: CGFloat = 1.0
    
    var totalDurationFormatted: String {
        let totalSeconds = books.reduce(0) { $0 + $1.duration }
        let hours = Int(totalSeconds) / 3600
        return "\(hours)"
    }
    
    func loadLibrary() async {
        isLoading = true
        
        // Simulate loading - in real app, fetch from API
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        
        // Generate sample books
        books = (0..<20).map { sampleBook(index: $0) }
        filteredBooks = books
        continueListening = books.filter { $0.userMediaProgress != nil }.prefix(5).map { $0 }
        
        isLoading = false
    }
    
    func refresh() async {
        await loadLibrary()
    }
    
    func selectBook(_ book: Book) {
        selectedBook = book
    }
    
    func playBook(_ book: Book) {
        // Start playback
        print("Playing: \(book.title)")
    }
    
    func searchResults(for query: String) -> [Book] {
        guard !query.isEmpty else { return [] }
        return books.filter {
            $0.title.localizedCaseInsensitiveContains(query) ||
            ($0.author?.localizedCaseInsensitiveContains(query) ?? false)
        }
    }
    
    func showFilterOptions() {}
    func showSettings() {}
    func showDownloads() {}
    func showStats() {}
}



// MARK: - Preview

#Preview("Bookshelf") {
    NavigationStack {
        BookshelfView()
    }
    .preferredColorScheme(.dark)
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
