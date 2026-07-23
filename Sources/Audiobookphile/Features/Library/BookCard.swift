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
        Button(action: onTap) {
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
                        .multilineTextAlignment(.leading)

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
        .buttonStyle(.liquid)
    }

    // MARK: - Cover Image

    private var coverImage: some View {
        ZStack(alignment: .topTrailing) {
            Color.clear
                .aspectRatio(aspectRatio, contentMode: .fill)
                .overlay {
                    if let url = coverURL {
                        ZStack {
                            // Glass blurred backdrop to fill container
                            SmartAsyncImage(url: url) { image in
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                            } placeholder: {
                                placeholderCover
                            }
                            .blur(radius: 15)
                            .overlay(Color.black.opacity(0.4))

                            // Fit image to show full uncropped cover
                            SmartAsyncImage(url: url) { image in
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                            } placeholder: {
                                Color.clear
                            }
                        }
                    } else {
                        placeholderCover
                    }
                }
                .clipped()

            // Badges
            Group {
                if let activeDownload = downloadService.downloads.first(where: { $0.libraryItemId == book.id }) {
                    CircularDownloadProgressBadge(progress: activeDownload.progress, status: activeDownload.status)
                } else if isDownloaded {
                    CircularDownloadProgressBadge(status: .completed)
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

// MARK: - Book Card Skeleton Loader
public struct BookCardSkeleton: View {
    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.08))
                .aspectRatio(1.0, contentMode: .fit)

            VStack(alignment: .leading, spacing: 6) {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(Color.white.opacity(0.12))
                    .frame(height: 14)

                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(Color.white.opacity(0.08))
                    .frame(width: 80, height: 10)
            }
            .frame(height: 68, alignment: .topLeading)
        }
        .shimmer()
    }
}

// MARK: - Circular Download Progress Badge Component
public struct CircularDownloadProgressBadge: View {
    public let progress: Double
    public let status: DownloadStatus?

    public init(progress: Double = 0, status: DownloadStatus? = nil) {
        self.progress = progress
        self.status = status
    }

    public var body: some View {
        ZStack {
            if let status = status {
                switch status {
                case .pending:
                    ZStack {
                        Circle()
                            .stroke(Color.orange.opacity(0.3), lineWidth: 2.5)
                        Circle()
                            .trim(from: 0, to: 0.3)
                            .stroke(Color.orange, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                            .applyConnectPulseEffect(isAnimating: true)
                        Image(systemName: "arrow.down")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(.orange)
                    }
                    .frame(width: 24, height: 24)
                    .padding(3)
                    .background(.ultraThinMaterial, in: Circle())
                    .shadow(color: .orange.opacity(0.5), radius: 6, x: 0, y: 2)

                case .downloading:
                    ZStack {
                        // Background track
                        Circle()
                            .stroke(Color.white.opacity(0.2), lineWidth: 2.5)

                        // Animated progress fill
                        Circle()
                            .trim(from: 0, to: max(0.05, CGFloat(progress)))
                            .stroke(
                                LinearGradient(colors: [.cyan, .teal], startPoint: .topLeading, endPoint: .bottomTrailing),
                                style: StrokeStyle(lineWidth: 2.5, lineCap: .round)
                            )
                            .rotationEffect(.degrees(-90))
                            .animation(.spring(response: 0.35, dampingFraction: 0.8), value: progress)

                        // Percentage label
                        Text("\(Int(progress * 100))")
                            .font(.system(size: 7, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                    }
                    .frame(width: 26, height: 26)
                    .padding(3)
                    .background(.ultraThinMaterial, in: Circle())
                    .shadow(color: .cyan.opacity(0.6), radius: 8, x: 0, y: 2)

                case .paused:
                    ZStack {
                        Circle()
                            .stroke(Color.yellow.opacity(0.4), lineWidth: 2.5)
                        Image(systemName: "pause.fill")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(.yellow)
                    }
                    .frame(width: 24, height: 24)
                    .padding(3)
                    .background(.ultraThinMaterial, in: Circle())
                    .shadow(color: .yellow.opacity(0.5), radius: 6, x: 0, y: 2)

                case .completed:
                    completedBadge

                case .failed:
                    ZStack {
                        Circle()
                            .fill(Color.red)
                        Image(systemName: "exclamationmark")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.white)
                    }
                    .frame(width: 24, height: 24)
                    .padding(3)
                    .background(.ultraThinMaterial, in: Circle())
                    .shadow(color: .red.opacity(0.5), radius: 6, x: 0, y: 2)
                }
            } else {
                completedBadge
            }
        }
    }

    private var completedBadge: some View {
        Image(systemName: "checkmark.circle.fill")
            .font(.system(size: 18, weight: .bold))
            .foregroundStyle(.white)
            .padding(3)
            .background {
                Circle()
                    .fill(
                        LinearGradient(colors: [.green, .teal], startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
            }
            .background(.ultraThinMaterial, in: Circle())
            .shadow(color: .green.opacity(0.5), radius: 6, x: 0, y: 2)
    }
}
