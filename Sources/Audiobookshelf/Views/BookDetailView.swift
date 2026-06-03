//
//  BookDetailView.swift
//  Audiobookshelf
//
//  Detailed book view with premium Liquid Glass design, metadata, and chapters.
//

import SwiftUI

public struct BookDetailView: View {
    public let book: Book
    @Environment(\.dismiss) var dismiss
    
    @State var detailedBook: Book?
    @State var isLoading = true
    @State private var playbackError: String? = nil
    @State private var showPlaybackError = false
    @State var isDescriptionExpanded = false
    @State var colorLoader = DynamicColorLoader()
    @ObservedObject var downloadService = DownloadService.shared
    
    public init(book: Book) {
        self.book = book
    }
    
    public var body: some View {
        ZStack {
            // Background
            backgroundLayer
            
            ScrollView {
                VStack(spacing: 24) {
                    // Back / Close handle
                    dragHandle
                    
                    if isLoading {
                        loadingState
                    } else if let detailed = detailedBook {
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
        .alert("Playback Error", isPresented: $showPlaybackError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(playbackError ?? "Unknown error")
        }
        .task {
            await fetchDetails()
        }
    }
    
    // MARK: - Background Layer
    
    private var backgroundLayer: some View {
        ZStack {
            if colorLoader.isLoaded {
                colorLoader.backgroundColor
                    .ignoresSafeArea()
                
                LinearGradient(
                    colors: [
                        colorLoader.backgroundColor.opacity(0.6),
                        colorLoader.backgroundColor.opacity(0.2),
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
                    await fetchDetails()
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
            // Large Cover Art
            coverArtSection(detailed)
            
            // Title & Authors
            VStack(spacing: 6) {
                Text(detailed.title)
                    .font(.title2)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white)
                
                if let author = detailed.author {
                    Text("by \(author)")
                        .font(.headline)
                        .foregroundStyle(Color.appPrimary)
                        .multilineTextAlignment(.center)
                }
                
                if let narrator = detailed.media.metadata.narratorName {
                    Text("Narrated by \(narrator)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            
            // Play & Download Actions
            actionButtonsSection(detailed)
            
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
            
            // Chapters List
            if !detailed.chapters.isEmpty {
                chaptersSection(detailed)
            }
        }
    }
    
    private func coverArtSection(_ detailed: Book) -> some View {
        CachedAsyncImage(url: AudiobookshelfAPI.shared.getCoverURL(itemId: detailed.id, width: 600)) { image in
            image
                .resizable()
                .aspectRatio(contentMode: .fit)
        } placeholder: {
            placeholderCover
        }
        .frame(height: 240)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.5), radius: 20, y: 10)
    }
    
    private var placeholderCover: some View {
        ZStack {
            Image("BookPlaceholder", bundle: .module)
                .resizable()
                .aspectRatio(contentMode: .fill)
            
            Color.black.opacity(0.15)
        }
        .frame(width: 160, height: 240)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    private func actionButtonsSection(_ detailed: Book) -> some View {
        HStack(spacing: 16) {
            // Main Play / Continue Button
            Button {
                playBook(detailed)
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: hasProgress(detailed) ? "play.circle.fill" : "play.fill")
                        .font(.title3)
                    Text(hasProgress(detailed) ? "Continue (\(detailed.userMediaProgress?.progressPercentage ?? 0)%)" : "Play")
                        .fontWeight(.bold)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .foregroundStyle(detailed.isMissing == true ? .white.opacity(0.5) : .white)
                .background(
                    detailed.isMissing == true ?
                    LinearGradient(colors: [.gray.opacity(0.3), .gray.opacity(0.2)], startPoint: .leading, endPoint: .trailing) :
                    LinearGradient(colors: [.appPrimary, .appSecondary], startPoint: .leading, endPoint: .trailing)
                )
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .shadow(color: detailed.isMissing == true ? .clear : .appPrimary.opacity(0.3), radius: 10)
            }
            .disabled(detailed.isMissing == true)
            
            // Dynamic Download Button
            if detailed.isMissing == true {
                Button {
                    // Disabled
                } label: {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.title3)
                        .foregroundStyle(.white.opacity(0.5))
                        .padding()
                        .background(.white.opacity(0.05))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .disabled(true)
            } else if let download = downloadService.downloads.first(where: { $0.libraryItemId == detailed.id }) {
                switch download.status {
                case .pending:
                    Button {
                        downloadService.cancelDownload(bookId: detailed.id)
                    } label: {
                        HStack(spacing: 6) {
                            ProgressView()
                                .tint(.orange)
                            Text("Pending...")
                                .font(.caption.bold())
                                .foregroundStyle(.orange)
                        }
                        .padding()
                        .background(.white.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    
                case .downloading:
                    Button {
                        downloadService.cancelDownload(bookId: detailed.id)
                    } label: {
                        HStack(spacing: 6) {
                            ProgressView(value: download.progress)
                                .progressViewStyle(.circular)
                                .tint(.appPrimary)
                            Text("\(Int(download.progress * 100))%")
                                .font(.caption.bold())
                                .foregroundStyle(Color.appPrimary)
                        }
                        .padding()
                        .background(.white.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    
                case .completed:
                    Button {
                        try? downloadService.deleteDownload(bookId: detailed.id)
                    } label: {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title3)
                            .foregroundStyle(.green)
                            .padding()
                            .background(.white.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    
                case .failed:
                    Button {
                        Task {
                            await downloadService.downloadBook(detailed)
                        }
                    } label: {
                        Image(systemName: "exclamationmark.circle.fill")
                            .font(.title3)
                            .foregroundStyle(.red)
                            .padding()
                            .background(.white.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                case .paused:
                    Button {
                        Task {
                            await downloadService.downloadBook(detailed)
                        }
                    } label: {
                        Image(systemName: "play.circle.fill")
                            .font(.title3)
                            .foregroundStyle(.yellow)
                            .padding()
                            .background(.white.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
            } else {
                Button {
                    Task {
                        await downloadService.downloadBook(detailed)
                    }
                } label: {
                    Image(systemName: "arrow.down.circle")
                        .font(.title3)
                        .foregroundStyle(.white)
                        .padding()
                        .background(.white.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
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
            statBadge(icon: "clock", value: formatDuration(detailed.duration), label: "Duration")
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
                .lineLimit(isDescriptionExpanded ? nil : 4)
                .animation(.easeInOut, value: isDescriptionExpanded)
            
            Button {
                isDescriptionExpanded.toggle()
            } label: {
                Text(isDescriptionExpanded ? "Show Less" : "Read More")
                    .font(.subheadline.bold())
                    .foregroundStyle(Color.appPrimary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard()
    }
    
    private func chaptersSection(_ detailed: Book) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Chapters")
                .font(.headline)
                .foregroundStyle(.white)
                .padding(.horizontal, 4)
            
            VStack(spacing: 8) {
                ForEach(detailed.chapters) { chapter in
                    Button {
                        playBook(detailed, seekToTime: chapter.start)
                    } label: {
                        HStack {
                            Text(chapter.title)
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundStyle(.white)
                                .multilineTextAlignment(.leading)
                            
                            Spacer()
                            
                            Text(formatDuration(chapter.duration))
                                .font(.caption.monospaced())
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 10)
                        .padding(.horizontal, 12)
                        .background(.white.opacity(0.05))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
            }
        }
    }
    
    // MARK: - Operations / Helpers
    
    private func fetchDetails() async {
        isLoading = true
        do {
            let detailed = try await AudiobookshelfAPI.shared.getLibraryItem(id: book.id)
            self.detailedBook = detailed
            if let coverUrl = AudiobookshelfAPI.shared.getCoverURL(itemId: detailed.id, width: 600) {
                await colorLoader.loadColor(from: coverUrl)
            }
        } catch {
            print("[BookDetailView] Error fetching detailed metadata: \(error)")
            playbackError = error.localizedDescription
            showPlaybackError = true
        }
        isLoading = false
    }
    
    private func playBook(_ detailed: Book, seekToTime: TimeInterval? = nil) {
        Task {
            do {
                let session = try await AudiobookshelfAPI.shared.startPlaybackSession(libraryItemId: detailed.id)
                
                // If a seek time is supplied (e.g. from tapping a chapter), store it before starting
                if let seekTime = seekToTime {
                    UserDefaults.standard.set(seekTime, forKey: "pendingSeekTime-\(session.id)")
                }
                
                // Actually start playback (loads tracks, sets up AVPlayer, starts playing)
                AudioPlayerService.shared.startPlayback(session: session)
                
                dismiss()
                
                // Open full player using the Coordinator with a slight delay
                // to allow the dismissal animation to complete.
                PlayerCoordinator.shared.presentPlayer(delayMilliseconds: 500)
                
            } catch {
                print("Failed to start playback session: \(error)")
                playbackError = String(describing: error)
                showPlaybackError = true
                playbackError = error.localizedDescription
                showPlaybackError = true
            }
        }
    }
    
    private func hasProgress(_ detailed: Book) -> Bool {
        if let progress = detailed.userMediaProgress, !progress.isFinished, progress.progress > 0 {
            return true
        }
        return false
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
    
    private func cleanHTML(_ html: String) -> String {
        // Strip basic HTML tag patterns for cleaner text display
        html.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
    }
}
