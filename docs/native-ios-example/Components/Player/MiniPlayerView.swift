//
//  MiniPlayerView.swift
//  AudiobookshelfClient
//
//  Persistent mini player bar with Liquid Glass design
//

import SwiftUI

struct MiniPlayerView: View {
    @ObservedObject var audioPlayer: AudioPlayerService
    @StateObject private var colorLoader = DynamicColorLoader()

    let onTap: () -> Void
    let onClose: () -> Void

    @State private var dragOffset: CGFloat = 0
    @State private var isDragging = false

    var body: some View {
        VStack(spacing: 0) {
            // Progress bar (thin line at top)
            progressBar

            // Main content
            HStack(spacing: 12) {
                // Cover image
                coverImage

                // Title and author
                titleSection

                Spacer()

                // Controls
                controlButtons
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background {
            // Dynamic glass background
            glassBackground
        }
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.3), radius: 10, y: -5)
        .padding(.horizontal, 8)
        .padding(.bottom, 8)
        .offset(y: dragOffset)
        .gesture(
            DragGesture()
                .onChanged { value in
                    if value.translation.height > 0 {
                        dragOffset = value.translation.height
                        isDragging = true
                    } else {
                        // Swipe up to expand
                        if value.translation.height < -30 {
                            onTap()
                        }
                    }
                }
                .onEnded { value in
                    if value.translation.height > 100 {
                        // Swipe down to close
                        withAnimation(.spring()) {
                            onClose()
                        }
                    } else {
                        withAnimation(.spring()) {
                            dragOffset = 0
                        }
                    }
                    isDragging = false
                }
        )
        .onTapGesture {
            onTap()
        }
        .task {
            if let coverURL = audioPlayer.currentCoverURL {
                await colorLoader.loadColor(from: coverURL)
            }
        }
    }

    // MARK: - Progress Bar

    private var progressBar: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Background
                Rectangle()
                    .fill(.white.opacity(0.2))

                // Progress
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [.cyan, .blue],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: geometry.size.width * audioPlayer.progress)
            }
        }
        .frame(height: 3)
    }

    // MARK: - Cover Image

    private var coverImage: some View {
        AsyncImage(url: audioPlayer.currentCoverURL) { phase in
            switch phase {
            case .success(let image):
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            case .failure:
                Image(systemName: "book.fill")
                    .font(.title2)
                    .foregroundStyle(.white.opacity(0.6))
            case .empty:
                ProgressView()
                    .tint(.white)
            @unknown default:
                Color.gray.opacity(0.3)
            }
        }
        .frame(width: 48, height: 48)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .shadow(color: .black.opacity(0.2), radius: 4)
    }

    // MARK: - Title Section

    private var titleSection: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(audioPlayer.currentTitle)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(.white)
                .lineLimit(1)

            Text(audioPlayer.currentAuthor)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.7))
                .lineLimit(1)
        }
    }

    // MARK: - Control Buttons

    private var controlButtons: some View {
        HStack(spacing: 16) {
            // Skip backward
            Button {
                Task {
                    await audioPlayer.seekBackward()
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                }
            } label: {
                Image(systemName: "gobackward.10")
                    .font(.title3)
                    .foregroundStyle(.white.opacity(0.8))
            }
            .accessibilityLabel("Skip backward 10 seconds")

            // Play/Pause
            Button {
                Task {
                    await audioPlayer.togglePlayPause()
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                }
            } label: {
                ZStack {
                    Circle()
                        .fill(.white.opacity(0.2))
                        .frame(width: 44, height: 44)

                    if audioPlayer.isLoading {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Image(systemName: audioPlayer.isPlaying ? "pause.fill" : "play.fill")
                            .font(.title3)
                            .foregroundStyle(.white)
                    }
                }
            }
            .accessibilityLabel(audioPlayer.isPlaying ? "Pause" : "Play")

            // Skip forward
            Button {
                Task {
                    await audioPlayer.seekForward()
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                }
            } label: {
                Image(systemName: "goforward.30")
                    .font(.title3)
                    .foregroundStyle(.white.opacity(0.8))
            }
            .accessibilityLabel("Skip forward 30 seconds")
        }
    }

    // MARK: - Glass Background

    private var glassBackground: some View {
        ZStack {
            // Dynamic color base
            if colorLoader.isLoaded {
                colorLoader.backgroundColor
            } else {
                Color(red: 0.15, green: 0.15, blue: 0.2)
            }

            // Glass overlay
            Rectangle()
                .fill(.ultraThinMaterial)

            // Gradient overlay
            LinearGradient(
                colors: [.white.opacity(0.1), .clear],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }
}

// MARK: - Audio Player Service Extension (for mini player)

extension AudioPlayerService {
    var currentTitle: String {
        session?.displayTitle ?? "Unknown Book"
    }

    var currentAuthor: String {
        session?.displayAuthor ?? "Unknown Author"
    }

    var currentCoverURL: URL? {
        guard let session = session else { return nil }
        return AudiobookshelfAPI.shared.getCoverURL(itemId: session.libraryItemId)
    }

    var progress: Double {
        guard duration > 0 else { return 0 }
        return currentTime / duration
    }

    func seekBackward() async {
        seek(by: -10)
    }

    func seekForward() async {
        seek(by: 30)
    }

    func togglePlayPause() async {
        if isPlaying {
            pause()
        } else {
            play()
        }
    }
}

// MARK: - Preview

#Preview("Mini Player") {
    ZStack {
        Color.black.ignoresSafeArea()

        VStack {
            Spacer()

            MiniPlayerView(
                audioPlayer: AudioPlayerService.shared,
                onTap: { print("Expand player") },
                onClose: { print("Close player") }
            )
        }
    }
}
