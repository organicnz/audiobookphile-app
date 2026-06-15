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
    @StateObject var proMotion = ProMotionManager.shared
    @ObservedObject var downloadService = DownloadService.shared
    
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
            VStack(alignment: .leading, spacing: 4) {
                Text(book.title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .lineLimit(2)
                    .foregroundStyle(.white)
                
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
            .frame(height: 68, alignment: .topLeading)
        }
        .contentShape(Rectangle())
    }
    
    // MARK: - Cover Image
    
    private var coverImage: some View {
        ZStack(alignment: .topTrailing) {
            // Background blur layer (Audiobookphile best practice for off-ratio covers)
            SmartAsyncImage(url: coverURL) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                placeholderCover
            }
            .blur(radius: 15)
            .overlay(Color.black.opacity(0.4))
            .frame(minWidth: 0, maxWidth: .infinity)
            .aspectRatio(aspectRatio, contentMode: .fit)
            .clipped()
            
            // Actual cover fitted
            SmartAsyncImage(url: coverURL) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } placeholder: {
                Color.clear
            }
            .frame(minWidth: 0, maxWidth: .infinity)
            .aspectRatio(aspectRatio, contentMode: .fit)
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
        .cornerRadius(12)
        .shadow(
            color: coverColor.opacity(0.4),
            radius: 15,
            y: 8
        )
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
    
    private var missingBadge: some View {
        Image(systemName: "exclamationmark.triangle.fill")
            .font(.title3)
            .foregroundStyle(.white)
            .background {
                Circle()
                    .fill(.red)
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
                    .fill(.white.opacity(0.2))
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
        if let path = book.coverPath {
            if path == "missing" { return nil }
            if path.hasPrefix("http") { return URL(string: path) }
        }
        return appState.getCoverURL(itemId: book.id, updatedAt: book.updatedAt)
    }
    
    private var isDownloaded: Bool {
        downloadService.downloads.contains { $0.libraryItemId == book.id && $0.status == .completed }
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
            SmartAsyncImage(url: coverURL) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Color.gray.opacity(0.3)
            }
            .frame(width: 60, height: 60)
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
