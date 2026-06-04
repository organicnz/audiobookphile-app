//
//  SearchView.swift
//  AudiobookphileClient
//
//  Search interface with Liquid Glass design
//

import SwiftUI

struct SearchView: View {
    @State private var query = ""
    @State private var results: [Book] = []
    @State private var isSearching = false
    @State private var searchTask: Task<Void, Never>?
    @State private var selectedBook: Book?

    // Recent searches (mock for now, would use UserDefaults)
    @State private var recentSearches = ["Project Hail Mary", "Sandman", "Dune"]

    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                Color.appBackground.ignoresSafeArea()

                // Content
                ScrollView {
                    VStack(spacing: 24) {
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
            .navigationBarTitleDisplayMode(.inline)
            .searchable(
                text: $query,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: "Title, Author, or Series"
            )
            .onChange(of: query) { newQuery in
                performSearch(newQuery)
            }
            .navigationDestination(
                isPresented: Binding(
                    get: { selectedBook != nil },
                    set: { if !$0 { selectedBook = nil } }
                )
            ) {
                if let book = selectedBook {
                    BookDetailView(book: book)
                }
            }
        }
    }

    // MARK: - Views

    private var resultsGrid: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 160), spacing: 16)], spacing: 24) {
            ForEach(results) { book in
                BookCard(book: book) {
                    selectedBook = book
                }
                    .scaleEffect(0.95)
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
                    withAnimation {
                        recentSearches.removeAll()
                    }
                }
                .font(.caption)
                .foregroundStyle(.cyan)
            }
            .padding(.horizontal, 16)

            // List
            VStack(spacing: 0) {
                ForEach(recentSearches, id: \.self) { term in
                    Button {
                        query = term
                    } label: {
                        HStack(spacing: 16) {
                            Image(systemName: "clock")
                                .foregroundStyle(.white.opacity(0.4))

                            Text(term)
                                .foregroundStyle(.white.opacity(0.9))

                            Spacer()

                            Image(systemName: "arrow.up.left")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.3))
                        }
                        .padding(16)
                        .background(.white.opacity(0.05))
                    }

                    if term != recentSearches.last {
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
                                        colors: [.cyan.opacity(0.2), .blue.opacity(0.2)],
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
                if let credentials = try? KeychainManager.shared.loadCredentials(),
                   let url = URL(string: "\(credentials.serverURL)/api/libraries/\(UserDefaults.standard.string(forKey: StorageKeys.lastLibraryId) ?? "")/search?q=\(text.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")") {

                    var request = URLRequest(url: url)
                    request.setValue("Bearer \(credentials.token)", forHTTPHeaderField: "Authorization")

                    let (data, _) = try await URLSession.shared.data(for: request)
                    let response = try JSONDecoder().decode(SearchResponse.self, from: data)

                    await MainActor.run {
                        self.results = response.results.map { $0.libraryItem }
                        self.isSearching = false
                    }
                }
            } catch {
                print("Search failed: \(error)")
                await MainActor.run { isSearching = false }
            }
        }
    }
}



#Preview {
    SearchView()
}
