//
//  SearchView.swift
//  Audiobookphile
//
//  Search interface with Liquid Glass design.
//  Compatible with Swift 6.3 and Skip.
//

import SwiftUI
import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public struct SearchView: View {
    @Environment(AppState.self) private var appState
    @State var query = ""
    @State var results: [Book] = []
    @State var isSearching = false
    @State var searchTask: Task<Void, Never>?
    @State var selectedBook: Book?
    @State var useSemanticSearch = false

    // Recent searches via API
    @State var recentSearches: [SearchHistoryItem] = []

    public init() {}

    public var body: some View {
        NavigationStack {
            ZStack {
                // Background
                FluidAuraBackground()

                // Content
                ScrollView {
                    VStack(spacing: 24) {
                        // Smart AI Search Toggle
                        Toggle(isOn: $useSemanticSearch) {
                            HStack {
                                Image(systemName: "sparkles")
                                    .foregroundStyle(Color.appPrimary)
                                Text("Smart AI Search")
                                    .font(.subheadline.weight(.medium))
                            }
                        }
                        .toggleStyle(SwitchToggleStyle(tint: .appPrimary))
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                        .onChange(of: useSemanticSearch) { _, _ in
                            if !query.isEmpty {
                                performSearch(query)
                            }
                        }

                        // Search results
                        if !query.isEmpty {
                            if isSearching {
                                LoadingView(message: "Searching library...")
                                    .padding(.top, 40)
                            } else if results.isEmpty {
                                emptyResultsView
                            } else {
                                resultsGrid
                            }
                        } else {
                            // Initial state / Recent
                            recentSearchesData
                        }
                    }
                    .padding(.bottom, 100) // Space for mini player
                }
            }
            .navigationTitle("Search")
            #if os(iOS) || SKIP
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .searchable(
                text: $query,
                placement: .automatic,
                prompt: "Title, Author, or Series"
            )
            .onChange(of: query) { _, newValue in
                if newValue.isEmpty {
                    results = []
                }
            }
            .onSubmit(of: .search) {
                if !query.isEmpty {
                    Task {
                        _ = try? await AudiobookphileAPI.shared.addSearchHistory(query: query)
                        await fetchRecentSearches()
                    }
                    performSearch(query)
                }
            }
            .task {
                await fetchRecentSearches()
            }
            .audiobookphileNavigationToolbar(title: "Search")
            .sheet(item: $selectedBook) { book in
                BookDetailView(book: book)
            }
        }
    }

    // MARK: - Views

    private var resultsGrid: some View {
        LazyVGrid(
            columns: [
                GridItem(.flexible(), spacing: 16),
                GridItem(.flexible(), spacing: 16),
                GridItem(.flexible(), spacing: 16)
            ],
            spacing: 24
        ) {
            ForEach(results) { book in
                BookCard(book: book, aspectRatio: 1.0) {
                    selectedBook = book
                }
            }
        }
        .padding(16)
    }

    private var emptyResultsView: some View {
        VStack(spacing: 16) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 48))
                .foregroundStyle(.white.opacity(0.3))

            Text("No results found")
                .font(.headline)
                .foregroundStyle(.white.opacity(0.7))

            Text("Try searching for something else")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.5))
        }
        .padding(.top, 60)
    }

    private var recentSearchesData: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Header
            HStack {
                Text("Recent Searches")
                    .font(.headline)
                    .foregroundStyle(.white)

                Spacer()

                Button("Clear") {
                    Task {
                        try? await AudiobookphileAPI.shared.clearSearchHistory()
                        await fetchRecentSearches()
                    }
                }
                .font(.caption)
                .foregroundStyle(Color.appPrimary)
            }
            .padding(.horizontal, 16)

            // List
            VStack(spacing: 0) {
                ForEach(recentSearches) { item in
                    Button {
                        query = item.query
                    } label: {
                        HStack(spacing: 16) {
                            Image(systemName: "clock")
                                .foregroundStyle(.white.opacity(0.4))

                            Text(item.query)
                                .foregroundStyle(.white.opacity(0.9))

                            Spacer()

                            Image(systemName: "arrow.up.left")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.3))
                        }
                        .padding(16)
                        .background(.white.opacity(0.05))
                    }
                    if item != recentSearches.last {
                        Divider()
                            .background(.white.opacity(0.1))
                            .padding(.leading, 48)
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .padding(.horizontal, 16)

            // Browse Categories (Mock)
            VStack(alignment: .leading, spacing: 16) {
                Text("Browse Categories")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(["Sci-Fi", "Fantasy", "Mystery", "Non-Fiction", "History"], id: \.self) { genre in
                            Text(genre)
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 12)
                                .background(
                                    LinearGradient(
                                        colors: [.appPrimary.opacity(0.15), .appSecondary.opacity(0.15)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .clipShape(Capsule())
                                .overlay(
                                    Capsule()
                                        .stroke(.white.opacity(0.1), lineWidth: 1)
                                )
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }
            .padding(.top, 24)
        }
        .padding(.top, 8)
    }

    // MARK: - Logic

    private func performSearch(_ text: String) {
        searchTask?.cancel()

        guard !text.isEmpty else {
            results = []
            isSearching = false
            return
        }

        guard text.count >= 2 else { return }

        searchTask = Task {
            // Debounce
            try? await Task.sleep(nanoseconds: 300_000_000)
            if Task.isCancelled { return }

            await MainActor.run { isSearching = true }

            do {
                let libraryId = await MainActor.run { appState.currentLibraryId ?? "" }
                let isSemantic = await MainActor.run { useSemanticSearch }

                let response = try await isSemantic
                    ? AudiobookphileAPI.shared.searchSemantic(query: text)
                    : AudiobookphileAPI.shared.searchLibrary(libraryId: libraryId, query: text)

                await MainActor.run {
                    self.results = response.results.map { $0.libraryItem }
                    self.isSearching = false
                }
            } catch {
                print("Search failed: \(error)")
                await MainActor.run { isSearching = false }
            }
        }
    }

    private func fetchRecentSearches() async {
        do {
            let history = try await AudiobookphileAPI.shared.fetchSearchHistory()
            withAnimation {
                self.recentSearches = history
            }
        } catch {
            print("Failed to fetch recent searches: \(error)")
        }
    }
}
