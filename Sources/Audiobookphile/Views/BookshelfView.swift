//
//  BookshelfView.swift
//  Audiobookphile
//
//  Main library view with glass design and parallax.
//  Compatible with Swift 6.3 and Skip.
//

import SwiftUI

/// Main bookshelf/library view
public struct BookshelfView: View {
    @StateObject var viewModel = BookshelfViewModel()
    @StateObject var proMotion = ProMotionManager.shared
    @Environment(AppState.self) private var appState
    @State var showSearch = false
    @State var searchText = ""
    @State var scrollOffset: CGFloat = 0
    @State var selectedBookForDetails: Book?
    
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
        #if os(iOS) || SKIP
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            toolbarContent
        }
        .task {
            await viewModel.loadLibrary(libraryId: appState.currentLibraryId, isAuthenticated: appState.isAuthenticated)
        }
        .onChange(of: appState.currentLibraryId) { _, newId in
            Task {
                await viewModel.loadLibrary(libraryId: newId, isAuthenticated: appState.isAuthenticated)
            }
        }
        .onChange(of: appState.isAuthenticated) { _, isAuth in
            if isAuth {
                Task {
                    await viewModel.loadLibrary(libraryId: appState.currentLibraryId, isAuthenticated: isAuth)
                }
            }
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
        }
        .allowsHitTesting(false)
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
                            selectedBookForDetails = book
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
                        selectedBookForDetails = book
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedBookForDetails = book
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
            } else if let errorMessage = viewModel.errorMessage {
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
        Button(action: {
            #if os(iOS) && !SKIP
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()
            #endif
            onTap()
        }) {
            VStack(alignment: .leading, spacing: 8) {
            // Cover image
            Group {
                if let url = coverURL {
                    CachedAsyncImage(url: url) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 120, height: 120)
                            .clipped()
                    } placeholder: {
                        fallbackCover
                    }
                    .frame(width: 120, height: 120)
                } else {
                    fallbackCover
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 12))
            
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
                            .font(.caption)
                            .foregroundStyle(.cyan)
                        
                        Spacer()
                        
                        Image(systemName: "play.circle.fill")
                            .foregroundStyle(.cyan)
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
        .buttonStyle(.plain)
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
        return AppState.shared.getCoverURL(itemId: book.id)
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
    @Published public var errorMessage: String? = nil
    
    public var totalBooks: Int { books.count }
    public var inProgressCount: Int { continueListening.count }
    public var coverAspectRatio: CGFloat = 1.0
    
    public var totalDurationFormatted: String {
        let totalSeconds = books.reduce(0) { $0 + $1.duration }
        let hours = Int(totalSeconds) / 3600
        return "\(hours)"
    }
    
    private var customService: LibraryServiceProtocol? = nil
    
    public init(service: LibraryServiceProtocol? = nil) {
        self.customService = service
    }
    
    public func loadLibrary(libraryId: String?, isAuthenticated: Bool) async {
        isLoading = true
        errorMessage = nil
        
        let service = customService ?? (isAuthenticated ? LiveLibraryService() : MockLibraryService())
        
        do {
            let fetched = try await service.fetchLibraryItems(libraryId: libraryId)
            self.books = fetched
            self.filteredBooks = fetched
            self.continueListening = fetched.filter { $0.userMediaProgress != nil }.prefix(5).map { $0 }
        } catch {
            print("[BookshelfViewModel] Failed to load library items: \(error)")
            self.errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    public func refresh(libraryId: String?, isAuthenticated: Bool) async {
        await loadLibrary(libraryId: libraryId, isAuthenticated: isAuthenticated)
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
