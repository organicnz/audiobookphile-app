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

            if !appState.isAuthenticated || (viewModel.books.isEmpty && viewModel.continueListening.isEmpty) {
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
                            RoundedRectangle(cornerRadius: 14)
                                .fill(Color.gray.opacity(0.2))
                                .frame(width: 200, height: 100)
                                .overlay(
                                    Image(systemName: "books.vertical.fill")
                                        .font(.largeTitle)
                                        .foregroundStyle(.secondary)
                                )
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
