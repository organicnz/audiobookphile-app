//
//  BookCard.swift
//  Audiobookphile
//
//  Book card component with Liquid Glass design.
//  Compatible with Swift 6.3 and Skip.
//

import SwiftUI

/// Book card for library grid display
public struct BookCard: View {
    @Environment(AppState.self) private var appState
    let book: Book
    public var aspectRatio: CGFloat = 1.0
    public let onTap: () -> Void
    @State var coverColor: Color = .gray
    var proMotion = ProMotionManager.shared
    var downloadService = DownloadService.shared

    public init(book: Book, aspectRatio: CGFloat = 1.0, onTap: @escaping () -> Void) {
        self.book = book
        self.aspectRatio = aspectRatio
        self.onTap = onTap
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Cover image with glass shadow
            coverImage

            // Book info
            VStack(alignment: .leading, spacing: 3) {
                Text(book.title)
                    .font(.system(.subheadline, design: .rounded))
                    .fontWeight(.semibold)
                    .lineLimit(2)
                    .foregroundStyle(.white)

                if let author = book.author, !author.isEmpty, author != "Unknown Author" {
                    Text(author)
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(.white.opacity(0.65))
                        .lineLimit(1)
                } else {
                    Text(" ")
                        .font(.system(.caption, design: .rounded))
                        .hidden()
                }

                Spacer(minLength: 0)

                // Progress indicator
                if let progress = book.userMediaProgress {
                    progressBar(progress: progress.progress)
                } else {
                    Color.clear
                        .frame(height: 4)
                }
            }
            .frame(height: 68, alignment: .topLeading)
        }
        .contentShape(Rectangle())
    }

    // MARK: - Cover Image

    private var coverImage: some View {
        ZStack(alignment: .topTrailing) {
            Color.clear
                .aspectRatio(aspectRatio, contentMode: .fill)
                .overlay {
                    SmartAsyncImage(url: coverURL) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        placeholderCover
                    }
                }
                .clipped()

            // Badges
            Group {
                if isDownloaded {
                    downloadBadge
                } else if book.isMissing == true {
                    missingBadge
                }
            }
            .padding(8)
        }
        .aspectRatio(aspectRatio, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [.white.opacity(0.3), .white.opacity(0.05)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .shadow(
            color: (coverColor == .gray ? Color.appPrimary : coverColor).opacity(0.35),
            radius: 14,
            x: 0,
            y: 8
        )
    }

    private var placeholderCover: some View {
        ZStack {
            Color.white.opacity(0.08)

            Image(systemName: "book.fill")
                .font(.largeTitle)
                .foregroundStyle(.white.opacity(0.4))
        }
    }

    private var downloadBadge: some View {
        Image(systemName: "arrow.down.circle.fill")
            .font(.title3)
            .foregroundStyle(.white)
            .padding(4)
            .background {
                Circle()
                    .fill(
                        LinearGradient(colors: [.green, .teal], startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
            }
            .background(.ultraThinMaterial, in: Circle())
            .shadow(color: .green.opacity(0.5), radius: 6, x: 0, y: 2)
    }

    private var missingBadge: some View {
        Image(systemName: "exclamationmark.triangle.fill")
            .font(.title3)
            .foregroundStyle(.white)
            .padding(4)
            .background {
                Circle()
                    .fill(
                        LinearGradient(colors: [.red, .orange], startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
            }
            .background(.ultraThinMaterial, in: Circle())
            .shadow(color: .red.opacity(0.5), radius: 6, x: 0, y: 2)
    }

    // MARK: - Progress Bar

    private func progressBar(progress: Double) -> some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Background
                Capsule()
                    .fill(.white.opacity(0.15))
                    .frame(height: 4)

                // Progress
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [Color.cyan, Color.purple],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(
                        width: geometry.size.width * progress,
                        height: 4
                    )
                    .shadow(color: Color.cyan.opacity(0.5), radius: 4)
            }
        }
        .frame(height: 4)
    }

    // MARK: - Helpers

    private var coverURL: URL? {
        if let path = book.coverPath {
            if path.hasPrefix("http") { return URL(string: path) }
        }
        return appState.getCoverURL(itemId: book.id, updatedAt: book.updatedAt)
    }

    private var isDownloaded: Bool {
        let downloads = downloadService.downloads
        let targetId = book.id
        return downloads.contains { item in
            item.libraryItemId == targetId && item.status == .completed
        }
    }
}

// MARK: - Scale Button Style

public struct ScaleButtonStyle: ButtonStyle {
    public init() {}
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

// MARK: - Glass Book Card Variant

public struct GlassBookCard: View {
    @Environment(AppState.self) private var appState
    let book: Book
    public let onTap: () -> Void

    public init(book: Book, onTap: @escaping () -> Void) {
        self.book = book
        self.onTap = onTap
    }

    public var body: some View {
        HStack(spacing: 16) {
            // Small cover
            Color.clear
                .frame(width: 60, height: 60)
                .overlay {
                    SmartAsyncImage(url: coverURL) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Color.white.opacity(0.1)
                    }
                }
                .clipped()
                .cornerRadius(8)

            // Info
            VStack(alignment: .leading, spacing: 6) {
                Text(book.title)
                    .font(.headline)
                    .lineLimit(2)
                    .foregroundStyle(.white)

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
                } else if book.isMissing == true {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.caption2)
                        Text("Missing Files")
                            .font(.caption)
                    }
                    .foregroundStyle(.red)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
        .glassCard()
    }

    private var coverURL: URL? {
        if let path = book.coverPath, path.hasPrefix("http") {
            return URL(string: path)
        }
        return appState.getCoverURL(itemId: book.id, updatedAt: book.updatedAt)
    }
}
