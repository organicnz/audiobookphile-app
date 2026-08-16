import SwiftUI
import Observation

public struct BookshelfGridSection: View {
    @Bindable var viewModel: BookshelfViewModel
    @Environment(AppState.self) private var appState
    @Binding var selectedBookForDetails: Book?

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            LazyVGrid(
                columns: [
                    GridItem(.adaptive(minimum: 105, maximum: 160), spacing: 16)
                ],
                spacing: 24
            ) {
                if (appState.isLoading || viewModel.isLoading) && viewModel.filteredBooks.isEmpty {
                    ForEach(0..<12, id: \.self) { _ in
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

            if viewModel.isLoadingNextPage {
                HStack(spacing: 12) {
                    ProgressView()
                        .tint(DesignTokens.Color.accentSecondary)
                    Text("Loading more audiobooks...")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity)
            }

            if let errorMessage = viewModel.errorMessage {
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.largeTitle)
                        .foregroundStyle(.yellow)
                    Text("Connection Failed")
                        .font(.headline)
                        .foregroundStyle(DesignTokens.Color.foreground)
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)

                    Button("Log Out") {
                        AuthManager.shared.logout(appState: appState)
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
}
