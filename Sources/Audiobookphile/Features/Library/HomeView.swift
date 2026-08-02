import SwiftUI

public struct HomeView: View {
    @State var viewModel = BookshelfViewModel()
    @Environment(AppState.self) private var appState
    @State var scrollOffset: CGFloat = 0
    @State var selectedBookForDetails: Book?

    public init() {}

    public var body: some View {
        ZStack {
            // Background
            backgroundLayer

            if appState.isLoading || (appState.isAuthenticated && viewModel.isLoading && viewModel.books.isEmpty && viewModel.continueListening.isEmpty) {
                // Cold-start: show beautiful skeleton while auth check or data fetch is in flight
                skeletonLoadingState
            } else if !appState.isAuthenticated {
                emptyState
            } else if !viewModel.isLoading && viewModel.books.isEmpty && viewModel.continueListening.isEmpty {
                // Truly empty after load completed
                emptyState
            } else {
                ScrollView {
                    VStack(spacing: 32) {
                        // Continue Listening
                        if !viewModel.continueListening.isEmpty {
                            continueListeningSection
                                .padding(.top, 16)
                        }

                        // Recently Added
                        recentlyAddedSection
                            .padding(.top, viewModel.continueListening.isEmpty ? 16 : 0)

                        // Continue Series
                        continueSeriesSection
                        
                        Spacer().frame(height: 100) // Bottom padding
                    }
                }
                #if os(iOS) || SKIP
                .refreshable {
                    await viewModel.refresh(libraryId: appState.currentLibraryId, isAuthenticated: appState.isAuthenticated)
                }
                #endif
            }
        }
        .audiobookphileNavigationToolbar(title: "Home")
        .navigationDestination(item: $selectedBookForDetails) { book in
            BookDetailView(book: book)
        }
        .task(id: LibraryLoadTrigger(libraryId: appState.currentLibraryId, isAuthenticated: appState.isAuthenticated)) {
            await viewModel.loadLibrary(libraryId: appState.currentLibraryId, isAuthenticated: appState.isAuthenticated)
        }
    }

    private var backgroundLayer: some View {
        Color.appBackground.ignoresSafeArea()
    }


    private var continueListeningSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Continue Listening")
                .font(.title3)
                .fontWeight(.bold)
                .foregroundStyle(Color.textPrimary)
                .padding(.horizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 16) {
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

    private var recentlyAddedSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recently Added")
                .font(.title3)
                .fontWeight(.bold)
                .foregroundStyle(Color.textPrimary)
                .padding(.horizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 16) {
                    if viewModel.books.isEmpty {
                        ForEach(0..<4, id: \.self) { _ in
                            BookCardSkeleton()
                                .frame(width: 140)
                        }
                    } else {
                        // Show first 5 books as "Recently Added"
                        ForEach(viewModel.books.prefix(5)) { book in
                            BookCard(book: book, aspectRatio: 1.0) {
                                selectedBookForDetails = book
                            }
                            .frame(width: 140)
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    private var continueSeriesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Continue Series")
                .font(.title3)
                .fontWeight(.bold)
                .foregroundStyle(Color.textPrimary)
                .padding(.horizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    // Dummy placeholders for series
                    ForEach(0..<3, id: \.self) { _ in
                        VStack(alignment: .leading, spacing: 8) {
                            Color.clear
                                .frame(width: 200, height: 100)
                                .overlay(
                                    Image(systemName: "books.vertical.fill")
                                        .font(.largeTitle)
                                        .foregroundStyle(.secondary)
                                )
                                .glassCard(cornerRadius: 14)
                            Text("Series Title")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundStyle(Color.textPrimary)
                            Text("Book 2 of 4")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    // MARK: - Skeleton Loading State (Cold Start)

    private var skeletonLoadingState: some View {
        ScrollView {
            VStack(spacing: 32) {
                // Skeleton: Continue Listening
                VStack(alignment: .leading, spacing: 12) {
                    skeletonTextBar(width: 180)
                        .padding(.horizontal)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 16) {
                            ForEach(0..<2, id: \.self) { _ in
                                VStack(alignment: .leading, spacing: 10) {
                                    HStack(spacing: 14) {
                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .fill(Color.white.opacity(0.08))
                                            .frame(width: 70, height: 70)

                                        VStack(alignment: .leading, spacing: 6) {
                                            skeletonTextBar(width: 120)
                                            skeletonTextBar(width: 80, height: 10)
                                            // Progress bar skeleton
                                            RoundedRectangle(cornerRadius: 3, style: .continuous)
                                                .fill(Color.white.opacity(0.06))
                                                .frame(height: 6)
                                                .frame(maxWidth: .infinity)
                                        }
                                    }
                                }
                                .padding(14)
                                .frame(width: 280)
                                .glassCard(cornerRadius: 16)
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.top, 16)

                // Skeleton: Recently Added
                VStack(alignment: .leading, spacing: 12) {
                    skeletonTextBar(width: 150)
                        .padding(.horizontal)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 16) {
                            ForEach(0..<4, id: \.self) { _ in
                                BookCardSkeleton()
                                    .frame(width: 140)
                            }
                        }
                        .padding(.horizontal)
                    }
                }

                // Skeleton: Continue Series
                VStack(alignment: .leading, spacing: 12) {
                    skeletonTextBar(width: 140)
                        .padding(.horizontal)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 16) {
                            ForEach(0..<3, id: \.self) { _ in
                                VStack(alignment: .leading, spacing: 8) {
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .fill(Color.white.opacity(0.06))
                                        .frame(width: 200, height: 100)
                                    skeletonTextBar(width: 120)
                                    skeletonTextBar(width: 80, height: 10)
                                }
                                .shimmer()
                            }
                        }
                        .padding(.horizontal)
                    }
                }

                Spacer().frame(height: 100)
            }
        }
        .transition(.opacity.animation(.easeOut(duration: 0.3)))
    }

    /// Reusable skeleton text bar with shimmer
    private func skeletonTextBar(width: CGFloat, height: CGFloat = 14) -> some View {
        RoundedRectangle(cornerRadius: 4, style: .continuous)
            .fill(Color.white.opacity(0.10))
            .frame(width: width, height: height)
            .shimmer()
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "headphones")
                .font(.system(size: 60))
                .foregroundStyle(Color.secondary.opacity(0.6))

            Text("No Content Available")
                .font(.title2)
                .fontWeight(.medium)
                .foregroundStyle(Color.textPrimary)

            Text("Your personalized content will appear here")
                .font(.body)
                .foregroundStyle(Color.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
