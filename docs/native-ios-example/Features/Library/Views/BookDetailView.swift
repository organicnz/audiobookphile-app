//
//  BookDetailView.swift
//  AudiobookshelfClient
//
//  Book detail view with Liquid Glass design
//

import SwiftUI

struct BookDetailView: View {
    let book: Book
    @Environment(\.dismiss) private var dismiss

    @StateObject private var colorLoader = DynamicColorLoader()
    @State private var showChapters = false
    @State private var isPlaying = false
    @State private var showingPlayer = false

    var body: some View {
        ZStack {
            // Dynamic background
            dynamicBackground

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 0) {
                    // Header with cover
                    headerSection

                    // Book info
                    infoSection

                    // Action buttons
                    actionButtons

                    // Description
                    if let description = book.description {
                        descriptionSection(description)
                    }

                    // Chapters
                    let chapters = book.chapters
                    if !chapters.isEmpty {
                        chaptersSection(chapters)
                    }

                    Spacer(minLength: 120)
                }
            }
            .ignoresSafeArea(edges: .top)
        }
        .navigationBarHidden(true)
        .overlay(alignment: .topLeading) {
            backButton
        }
        .task {
            if let coverURL = getCoverURL() {
                await colorLoader.loadColor(from: coverURL)
            }
        }
        .fullScreenCover(isPresented: $showingPlayer) {
            if let session = AudioPlayerService.shared.session {
                AudioPlayerView(session: session)
            } else {
                LoadingView(message: "Loading Player...")
            }
        }
    }

    // MARK: - Background

    private var dynamicBackground: some View {
        ZStack {
            if colorLoader.isLoaded {
                LinearGradient(
                    colors: colorLoader.gradientColors,
                    startPoint: .top,
                    endPoint: .bottom
                )
            } else {
                Color.black
            }
        }
        .ignoresSafeArea()
    }

    // MARK: - Back Button

    private var backButton: some View {
        Button {
            dismiss()
        } label: {
            Image(systemName: "chevron.left")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(.ultraThinMaterial)
                .clipShape(Circle())
        }
        .padding(.leading, 16)
        .padding(.top, 50)
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(spacing: 20) {
            Spacer(minLength: 100)

            // Cover image
            AsyncImage(url: getCoverURL()) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                case .failure:
                    Image(systemName: "book.fill")
                        .font(.system(size: 60))
                        .foregroundStyle(.white.opacity(0.6))
                case .empty:
                    ProgressView()
                        .tint(.white)
                @unknown default:
                    Color.gray.opacity(0.3)
                }
            }
            .frame(width: 220, height: 330)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.4), radius: 20, y: 10)
        }
        .frame(maxWidth: .infinity)
        .padding(.bottom, 24)
    }

    // MARK: - Info Section

    private var infoSection: some View {
        VStack(spacing: 8) {
            Text(book.title)
                .font(.title2.weight(.bold))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)

            if let author = book.author {
                Text("by \(author)")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.8))
            }

            // Duration and progress
            HStack(spacing: 16) {
                let duration = book.duration
                Label(formatDuration(duration), systemImage: "clock")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.7))

                if let progress = book.userMediaProgress {
                    Label("\(Int(progress.progress * 100))%", systemImage: "chart.bar")
                        .font(.caption)
                        .foregroundStyle(.cyan)
                }
            }
            .padding(.top, 8)
        }
        .padding(.horizontal, 24)
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        HStack(spacing: 16) {
            // Play button
            GlassButton(
                book.userMediaProgress?.isFinished == true ? "Listen Again" : "Play",
                icon: "play.fill",
                size: .large,
                colors: [.blue, .purple]
            ) {
                startPlayback()
            }
            .frame(maxWidth: .infinity)

            // Download button
            GlassButton(
                "Download",
                icon: "arrow.down.circle",
                size: .medium,
                colors: [.green, .cyan]
            ) {
                // Download action
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 24)
    }

    // MARK: - Description Section

    private func descriptionSection(_ description: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Description")
                .font(.headline)
                .foregroundStyle(.white)

            Text(description)
                .font(.body)
                .foregroundStyle(.white.opacity(0.8))
                .lineLimit(8)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal, 16)
    }

    // MARK: - Chapters Section

    private func chaptersSection(_ chapters: [Chapter]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Chapters (\(chapters.count))")
                    .font(.headline)
                    .foregroundStyle(.white)

                Spacer()

                Button {
                    withAnimation {
                        showChapters.toggle()
                    }
                } label: {
                    Image(systemName: showChapters ? "chevron.up" : "chevron.down")
                        .foregroundStyle(.white.opacity(0.7))
                }
            }

            if showChapters {
                ForEach(Array(chapters.enumerated()), id: \.element.id) { index, chapter in
                    ChapterRow(
                        index: index + 1,
                        chapter: chapter,
                        isCurrentChapter: false
                    ) {
                        // Play from chapter
                    }
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal, 16)
        .padding(.top, 16)
    }

    // MARK: - Helpers

    private func getCoverURL() -> URL? {
        return AudiobookshelfAPI.shared.getCoverURL(itemId: book.id)
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes) min"
    }

    private func startPlayback() {
        Task {
            do {
                let session = try await AudiobookshelfAPI.shared.startPlaybackSession(libraryItemId: book.id)
                // Initialize player with session
                showingPlayer = true
            } catch {
                print("Failed to start playback: \(error)")
            }
        }
    }
}

// MARK: - Chapter Row

struct ChapterRow: View {
    let index: Int
    let chapter: Chapter
    let isCurrentChapter: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Text("\(index)")
                    .font(.caption)
                    .foregroundStyle(isCurrentChapter ? .cyan : .white.opacity(0.5))
                    .frame(width: 24)

                Text(chapter.title)
                    .font(.subheadline)
                    .foregroundStyle(isCurrentChapter ? .cyan : .white)
                    .lineLimit(1)

                Spacer()

                Text(formatChapterDuration(chapter.end - chapter.start))
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.5))

                if isCurrentChapter {
                    Image(systemName: "speaker.wave.2.fill")
                        .font(.caption)
                        .foregroundStyle(.cyan)
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(isCurrentChapter ? Color.cyan.opacity(0.15) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }

    private func formatChapterDuration(_ seconds: TimeInterval) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }
}

// MARK: - Preview

#Preview("Book Detail") {
    BookDetailView(book: Book.preview)
}

// MARK: - Preview Helper

extension Book {
    static var preview: Book {
        let metadata = BookMetadata(
            title: "The Martian",
            subtitle: nil,
            authorName: "Andy Weir",
            narratorName: "R.C. Bray",
            seriesName: nil,
            genres: ["Science Fiction"],
            publishedYear: "2014",
            publishedDate: nil,
            publisher: "Crown",
            description: "Six days ago, astronaut Mark Watney became one of the first people to walk on Mars. Now, he's sure he'll be the first person to die there.",
            isbn: nil,
            asin: nil,
            language: "English",
            explicit: false
        )
        let media = BookMedia(
            libraryFiles: [],
            chapters: [
                Chapter(id: 1, title: "Chapter 1", start: 0, end: 3600),
                Chapter(id: 2, title: "Chapter 2", start: 3600, end: 7200)
            ],
            duration: 7200,
            size: 1000000,
            metadata: metadata,
            coverPath: nil,
            tags: [],
            audioFiles: [],
            ebookFile: nil
        )
        return Book(
            id: "preview-book",
            libraryId: "lib1",
            folderId: "folder1",
            path: "/books/preview",
            relPath: "preview",
            media: media,
            userMediaProgress: nil,
            addedAt: Date(),
            updatedAt: Date()
        )
    }
}
