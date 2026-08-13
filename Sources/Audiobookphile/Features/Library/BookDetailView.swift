//
//  BookDetailView.swift
//  Audiobookphile
//
//  Detailed book view with premium Liquid Glass design, metadata, and chapters.
//

import SwiftUI

public struct BookDetailView: View {
    @State var viewModel: BookDetailViewModel
    @Environment(\.dismiss) var dismiss
    @Environment(AppState.self) private var appState

    public init(book: Book) {
        self._viewModel = State(wrappedValue: BookDetailViewModel(book: book))
    }

    public var body: some View {
        ZStack {
            // Background
            backgroundLayer

            ScrollView {
                VStack(spacing: 24) {
                    // Back / Close handle
                    dragHandle

                    if viewModel.isLoading {
                        loadingState
                    } else if let detailed = viewModel.detailedBook {
                        bookDetailsContent(detailed)
                    } else {
                        errorState
                    }

                    Spacer(minLength: 40)
                }
                .padding(.horizontal, 20)
            }
        }
        .preferredColorScheme(appState.settings.theme.colorScheme)
        .alert("Playback Error", isPresented: $viewModel.showPlaybackError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(viewModel.playbackError ?? "Unknown error")
        }
        .confirmationDialog(
            "Remove Download",
            isPresented: $viewModel.showRemoveDownloadConfirmation,
            titleVisibility: .visible
        ) {
            Button("Remove Downloaded File", role: .destructive) {
                viewModel.removeDownload()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to remove this downloaded audiobook from your device?")
        }
        .task {
            await viewModel.fetchDetails(appState: appState)
        }
    }

    // MARK: - Background Layer

    private var backgroundLayer: some View {
        ZStack {
            if viewModel.colorLoader.isLoaded {
                viewModel.colorLoader.backgroundColor
                    .ignoresSafeArea()

                LinearGradient(
                    colors: [
                        viewModel.colorLoader.backgroundColor.opacity(0.6),
                        viewModel.colorLoader.backgroundColor.opacity(0.2),
                        Color.appBackground
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
            } else {
                Color.appBackground
                    .ignoresSafeArea()
            }

            Color.appBackground.opacity(0.75)
                .ignoresSafeArea()
        }
    }

    private var dragHandle: some View {
        Capsule()
            .fill(.white.opacity(0.3))
            .frame(width: 40, height: 5)
            .padding(.top, 12)
            .padding(.bottom, 8)
    }

    // MARK: - Loading State

    private var loadingState: some View {
        VStack(spacing: 20) {
            Spacer(minLength: 100)
            ProgressView()
                .tint(.appPrimary)
                .scaleEffect(1.5)
            Text("Fetching book details...")
                .font(.headline)
                .foregroundStyle(.white.opacity(0.8))
            Spacer(minLength: 100)
        }
    }

    // MARK: - Error State

    private var errorState: some View {
        VStack(spacing: 16) {
            Spacer(minLength: 100)
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 50))
                .foregroundStyle(.yellow)
            Text("Failed to load details")
                .font(.headline)
                .foregroundStyle(.white)
            Button("Retry") {
                Task {
                    await viewModel.fetchDetails(appState: appState)
                }
            }
            .padding()
            .background(.white.opacity(0.1))
            .clipShape(Capsule())
            Spacer(minLength: 100)
        }
    }

    // MARK: - Book Content

    private func bookDetailsContent(_ detailed: Book) -> some View {
        VStack(spacing: 24) {
            // Header: Large Cover Art, Title & Authors
            BookDetailHeader(detailed: detailed, appState: appState, viewModel: viewModel)

            // Play & Download Actions
            BookActionRow(detailed: detailed, viewModel: viewModel)

            // Missing Files Warning
            if detailed.isMissing == true {
                missingFilesWarning
            }

            // Metadata Stats Row
            BookDetailStatsRow(detailed: detailed, viewModel: viewModel)

            // Description (Expandable)
            if let description = detailed.description, !description.isEmpty {
                BookDetailDescriptionSection(text: description, viewModel: viewModel)
            }

            // AudioBooth Metadata Section
            BookDetailMetadataSection(detailed: detailed, viewModel: viewModel)

            // Chapters List
            if !detailed.chapters.isEmpty {
                ChapterListView(detailed: detailed, viewModel: viewModel)
            }

            // Similar Books
            if !viewModel.similarBooks.isEmpty {
                BookDetailSimilarBooksSection(viewModel: viewModel)
            }
        }
    }

    private var missingFilesWarning: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.title2)
                .foregroundStyle(.red)

            VStack(alignment: .leading, spacing: 4) {
                Text("Missing Audio Files")
                    .font(.headline)
                    .foregroundStyle(.white)
                Text("The audio files for this book are missing from the server. Playback and downloads are unavailable.")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.8))
            }
        }
        .padding()
        .background(.red.opacity(0.2))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(.red.opacity(0.5), lineWidth: 1)
        )
    }


}
