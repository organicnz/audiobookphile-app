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
        .preferredColorScheme(.dark)
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
            statsRowSection(detailed)

            // Description (Expandable)
            if let description = detailed.description, !description.isEmpty {
                descriptionSection(description)
            }

            // AudioBooth Metadata Section
            audiobookphileMetadataSection(detailed)

            // Chapters List
            if !detailed.chapters.isEmpty {
                ChapterListView(detailed: detailed, viewModel: viewModel)
            }

            // Similar Books
            if !viewModel.similarBooks.isEmpty {
                similarBooksSection
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

    private func statsRowSection(_ detailed: Book) -> some View {
        HStack(spacing: 12) {
            statBadge(icon: "clock", value: viewModel.formatDuration(detailed.duration), label: "Duration")
            if let year = detailed.media.metadata.publishedYear {
                statBadge(icon: "calendar", value: year, label: "Published")
            }
            statBadge(icon: "list.bullet", value: "\(detailed.chapters.count)", label: "Chapters")
        }
    }

    private func statBadge(icon: String, value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                    .font(.subheadline)
                    .foregroundStyle(Color.appPrimary)
            Text(value)
                .font(.subheadline)
                .fontWeight(.bold)
                .foregroundStyle(.white)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .glassCard()
    }

    private func descriptionSection(_ text: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Synopsis")
                .font(.headline)
                .foregroundStyle(.white)

            Text(cleanHTML(text))
                .font(.body)
                .foregroundStyle(.white.opacity(0.8))
                .lineLimit(viewModel.isDescriptionExpanded ? nil : 4)
                .animation(.easeInOut, value: viewModel.isDescriptionExpanded)

            Button {
                viewModel.isDescriptionExpanded.toggle()
            } label: {
                Text(viewModel.isDescriptionExpanded ? "Show Less" : "Read More")
                    .font(.subheadline.bold())
                    .foregroundStyle(Color.appPrimary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard()
    }

    private func audiobookphileMetadataSection(_ detailed: Book) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Metadata")
                .font(.headline)
                .foregroundStyle(.white)

            VStack(alignment: .leading, spacing: 10) {
                if let publisher = detailed.media.metadata.publisher, !publisher.isEmpty {
                    metadataRow(icon: "building.2", label: "Publisher", value: publisher)
                }
                if let publishedYear = detailed.media.metadata.publishedYear, !publishedYear.isEmpty {
                    metadataRow(icon: "calendar", label: "Published", value: publishedYear)
                }
                if let language = detailed.media.metadata.language, !language.isEmpty {
                    metadataRow(icon: "globe", label: "Language", value: language)
                }
                if let narrator = detailed.media.metadata.narratorName, !narrator.isEmpty {
                    metadataRow(icon: "person.wave.2", label: "Narrator", value: narrator)
                }
                if let series = detailed.media.metadata.seriesName, !series.isEmpty {
                    metadataRow(icon: "books.vertical", label: "Series", value: series)
                }
                metadataRow(icon: "clock", label: "Duration", value: viewModel.formatDuration(detailed.duration))
                if !detailed.media.metadata.genres.isEmpty {
                    metadataRow(icon: "tag", label: "Genres", value: detailed.media.metadata.genres.joined(separator: ", "))
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard()
    }

    private func metadataRow(icon: String, label: String, value: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundStyle(Color.appPrimary)
                .frame(width: 20)
            HStack(spacing: 4) {
                Text(label + ":")
                    .font(.subheadline.bold())
                    .foregroundStyle(.white)
                Text(value)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.85))
            }
        }
    }

    private func cleanHTML(_ html: String) -> String {
        // Strip basic HTML tag patterns for cleaner text display
        html.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
    }

    // MARK: - Similar Books Section

    private var similarBooksSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Similar Books")
                .font(.title3)
                .bold()
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, alignment: .leading)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(viewModel.similarBooks) { similarBook in
                        NavigationLink(destination: BookDetailView(book: similarBook)) {
                            BookCard(book: similarBook) {}
                                .frame(width: 140)
                        }
                    }
                }
            }
        }
        .padding(.vertical, 8)
    }
}
