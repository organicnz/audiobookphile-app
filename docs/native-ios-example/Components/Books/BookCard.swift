//
//  BookCard.swift
//  AudiobookphileClient
//
//  Book card component with Liquid Glass design
//  Translates: components/cards/ from Vue app
//

import SwiftUI

/// Book card for library grid display
struct BookCard: View {
    let book: Book
    var aspectRatio: CGFloat = 1.0
    let onTap: () -> Void
    
    @State private var coverColor: Color = .gray
    @ObservedObject private var proMotion = ProMotionManager.shared
    
    var body: some View {
        Button(action: {
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()
            onTap()
        }) {
            VStack(alignment: .leading, spacing: 12) {
                // Cover image with glass shadow
                coverImage
                
                // Book info
                VStack(alignment: .leading, spacing: 4) {
                    Text(book.title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .lineLimit(2)
                        .foregroundStyle(.primary)
                    
                    if let author = book.author {
                        Text(author)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    
                    // Progress indicator
                    if let progress = book.userMediaProgress {
                        progressBar(progress: progress.progress)
                    }
                }
            }
        }
        .buttonStyle(ScaleButtonStyle())
    }
    
    // MARK: - Cover Image
    
    private var coverImage: some View {
        GeometryReader { geometry in
            ZStack(alignment: .topTrailing) {
                // Cover
                AsyncImage(url: coverURL) { phase in
                    switch phase {
                    case .empty:
                        placeholderCover
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .onAppear {
                                // Extract color in real implementation
                            }
                    case .failure:
                        placeholderCover
                    @unknown default:
                        placeholderCover
                    }
                }
                .frame(width: geometry.size.width, height: geometry.size.height)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .shadow(
                    color: coverColor.opacity(0.4),
                    radius: 15,
                    y: 8
                )
                
                // Download badge (if downloaded)
                if isDownloaded {
                    downloadBadge
                        .padding(8)
                }
            }
        }
        .aspectRatio(aspectRatio, contentMode: .fit)
    }
    
    private var placeholderCover: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(.ultraThinMaterial)
            .overlay {
                Image(systemName: "book.fill")
                    .font(.largeTitle)
                    .foregroundStyle(.secondary)
            }
    }
    
    private var downloadBadge: some View {
        Image(systemName: "arrow.down.circle.fill")
            .font(.title3)
            .foregroundStyle(.white)
            .background {
                Circle()
                    .fill(.green)
                    .padding(-4)
            }
            .shadow(radius: 4)
    }
    
    // MARK: - Progress Bar
    
    private func progressBar(progress: Double) -> some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Background
                Capsule()
                    .fill(.quaternary)
                    .frame(height: 3)
                
                // Progress
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [.blue, .purple],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(
                        width: geometry.size.width * progress,
                        height: 3
                    )
            }
        }
        .frame(height: 3)
    }
    
    // MARK: - Helpers
    
    private var coverURL: URL? {
        guard let path = book.coverPath else { return nil }
        // In real implementation, construct full URL with server
        return URL(string: path)
    }
    
    private var isDownloaded: Bool {
        // In real implementation, check download status
        false
    }
}

// MARK: - Scale Button Style

struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

// MARK: - Glass Book Card Variant

struct GlassBookCard: View {
    let book: Book
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                // Small cover
                AsyncImage(url: coverURL) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Color.gray.opacity(0.3)
                }
                .frame(width: 60, height: 60)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                
                // Info
                VStack(alignment: .leading, spacing: 6) {
                    Text(book.title)
                        .font(.headline)
                        .lineLimit(2)
                    
                    if let author = book.author {
                        Text(author)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    
                    if let progress = book.userMediaProgress {
                        HStack {
                            Image(systemName: "clock.fill")
                                .font(.caption2)
                            Text("\(progress.progressPercentage)% complete")
                                .font(.caption)
                        }
                        .foregroundStyle(.blue)
                    }
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .glassCard()
    }
    
    private var coverURL: URL? {
        guard let path = book.coverPath else { return nil }
        return URL(string: path)
    }
}

// MARK: - Preview

#Preview("Book Cards") {
    ScrollView {
        VStack(spacing: 30) {
            // Grid of standard cards
            LazyVGrid(
                columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ],
                spacing: 20
            ) {
                ForEach(0..<6) { index in
                    BookCard(
                        book: sampleBook(index: index),
                        aspectRatio: 1.0
                    ) {
                        print("Tapped book \(index)")
                    }
                }
            }
            .padding()
            
            // Glass card variant
            VStack(spacing: 12) {
                ForEach(0..<3) { index in
                    GlassBookCard(
                        book: sampleBook(index: index)
                    ) {
                        print("Tapped glass card \(index)")
                    }
                }
            }
            .padding()
        }
    }
    .background {
        LinearGradient(
            colors: [.indigo, .purple],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
}

// MARK: - Sample Data

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
            duration: 28800,
            size: 0,
            metadata: BookMetadata(
                title: "Sample Book \(index + 1)",
                subtitle: nil,
                authorName: "Author Name",
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
        userMediaProgress: index % 2 == 0 ? MediaProgress(
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
