//
//  AudioPlayerView.swift
//  Audiobookshelf
//
//  Full-screen audio player with bleeding-edge Liquid Glass design.
//  Compatible with Swift 6.3 and Skip.
//

import SwiftUI

public struct AudioPlayerView: View {
    @StateObject var viewModel: AudioPlayerViewModel
    @StateObject var proMotion = ProMotionManager.shared
    @Environment(\.dismiss) var dismiss

    @State var showChapters = false
    @State var showMoreMenu = false
    @State var isDraggingSeeker = false
    @State var draggedTime: TimeInterval = 0

    @State var coverColor: Color = .blue
    @State var coverIsLight = false

    public init(session: PlaybackSession) {
        _viewModel = StateObject(wrappedValue: AudioPlayerViewModel(session: session))
    }

    public var body: some View {
        ZStack {
            // Background
            backgroundLayer

            // Full-screen player
            fullscreenPlayer
        }
        .ignoresSafeArea()
        .optimizedForProMotion()
        .sheet(isPresented: $showChapters) {
            ChapterListView(
                chapters: viewModel.chapters,
                currentChapter: viewModel.currentChapter,
                onSelect: { chapter in
                    viewModel.seek(to: chapter.start)
                    showChapters = false
                }
            )
        }
    }

    private var backgroundLayer: some View {
        ZStack {
            coverColor
                .ignoresSafeArea()

            LinearGradient(
                colors: [
                    coverColor.opacity(0.8),
                    coverColor.opacity(0.4),
                    Color.black.opacity(0.6)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            Rectangle()
                .fill(.ultraThinMaterial)
                .opacity(0.3)
                .ignoresSafeArea()
        }
    }

    private var fullscreenPlayer: some View {
        VStack(spacing: 0) {
            // Top bar
            topBar
                .padding(.top, 50)

            Spacer()

            // Cover art
            coverArtSection
                .padding(.vertical, 40)

            // Title and author
            titleSection
                .padding(.horizontal, 24)

            Spacer()

            // Playback controls
            VStack(spacing: 24) {
                if viewModel.useTotalTrack {
                    totalTrackView
                        .padding(.horizontal, 24)
                }

                quickActionsBar
                    .padding(.horizontal, 24)

                trackView
                    .padding(.horizontal, 24)

                playbackControls
                    .padding(.horizontal, 24)
                    .padding(.bottom, 40)
            }
        }
    }

    private var topBar: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.down")
                    .font(.title2)
                    .foregroundStyle(coverIsLight ? .black : .white)
            }

            Spacer()

            Button {
                showMoreMenu = true
            } label: {
                Image(systemName: "ellipsis")
                    .font(.title2)
                    .foregroundStyle(coverIsLight ? .black : .white)
            }
        }
        .padding(.horizontal, 24)
    }

    private var coverArtSection: some View {
        GeometryReader { geometry in
            Group {
                if let url = viewModel.coverURL {
                    AsyncImage(url: url) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                    } placeholder: {
                        placeholderCover
                    }
                } else {
                    placeholderCover
                }
            }
            .frame(width: geometry.size.width * 0.7)
            .frame(maxWidth: .infinity)
            .cornerRadius(20)
            .shadow(
                color: coverColor.opacity(0.5),
                radius: 30,
                y: 15
            )
        }
        .frame(height: 300)
    }

    private var placeholderCover: some View {
        RoundedRectangle(cornerRadius: 20)
            .fill(.ultraThinMaterial)
            .overlay {
                Image(systemName: "book.fill")
                    .font(.system(size: 80))
                    .foregroundStyle(.secondary)
            }
    }

    private var titleSection: some View {
        VStack(spacing: 8) {
            Text(viewModel.currentChapterTitle.isEmpty ? viewModel.title : viewModel.currentChapterTitle)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(coverIsLight ? .black : .white)
                .multilineTextAlignment(.center)
                .lineLimit(2)

            Text(viewModel.author)
                .font(.headline)
                .foregroundStyle((coverIsLight ? Color.black : .white).opacity(0.7))
                .multilineTextAlignment(.center)
                .lineLimit(1)
        }
    }

    private var totalTrackView: some View {
        VStack(spacing: 4) {
            HStack {
                Text(viewModel.currentTimePretty)
                    .font(.system(.caption, design: .monospaced))
                Spacer()
                Text(viewModel.totalTimeRemainingPretty)
                    .font(.system(.caption, design: .monospaced))
            }
            .foregroundStyle((coverIsLight ? Color.black : .white).opacity(0.7))

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(.white.opacity(0.2))
                        .frame(height: 2)

                    Capsule()
                        .fill(coverColor)
                        .frame(
                            width: geometry.size.width * CGFloat(viewModel.totalProgress),
                            height: 2
                        )
                }
            }
            .frame(height: 2)
        }
    }

    private var quickActionsBar: some View {
        HStack(spacing: 0) {
            GlassIconButton(
                icon: "bookmark",
                fill: viewModel.hasBookmarks,
                color: coverIsLight ? .black : .white,
                action: viewModel.showBookmarks
            )

            Spacer()

            Button {
                viewModel.showSpeedSelector()
            } label: {
                Text("\(viewModel.playbackRate, specifier: "%.1f")×")
                    .font(.system(.body, design: .monospaced))
                    .fontWeight(.medium)
                    .foregroundStyle(coverIsLight ? .black : .white)
            }

            Spacer()

            GlassIconButton(
                icon: "moon",
                fill: viewModel.sleepTimerActive,
                color: viewModel.sleepTimerActive ? .green : (coverIsLight ? .black : .white),
                action: viewModel.showSleepTimer
            )

            Spacer()

            GlassIconButton(
                icon: "list.bullet",
                fill: false,
                color: coverIsLight ? .black : .white,
                action: { showChapters = true }
            )
            .opacity(viewModel.chapters.isEmpty ? 0.3 : 1.0)
            .disabled(viewModel.chapters.isEmpty)
        }
    }

    private var trackView: some View {
        VStack(spacing: 8) {
            HStack {
                Text(viewModel.currentChapterTimePretty)
                    .font(.system(.caption, design: .monospaced))
                Spacer()
                Text(viewModel.timeRemainingPretty)
                    .font(.system(.caption, design: .monospaced))
            }
            .foregroundStyle(coverIsLight ? .black : .white)

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(.white.opacity(0.3))

                    Capsule()
                        .fill(.white.opacity(0.5))
                        .frame(width: geometry.size.width * CGFloat(viewModel.bufferedProgress))

                    Capsule()
                        .fill(coverColor)
                        .frame(width: geometry.size.width * CGFloat(viewModel.progress))

                    Circle()
                        .fill(.white)
                        .frame(width: 20, height: 20)
                        .shadow(color: .black.opacity(0.3), radius: 4)
                        .offset(x: geometry.size.width * CGFloat(viewModel.progress) - 10)
                }
                .frame(height: 6)
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            isDraggingSeeker = true
                            let progress = min(max(0, value.location.x / geometry.size.width), 1)
                            draggedTime = viewModel.duration * progress
                        }
                        .onEnded { value in
                            let progress = min(max(0, value.location.x / geometry.size.width), 1)
                            viewModel.seek(to: viewModel.duration * progress)
                            isDraggingSeeker = false
                        }
                )
            }
            .frame(height: 20)
        }
    }

    private var playbackControls: some View {
        HStack(spacing: 0) {
            GlassIconButton(
                icon: "backward.end.fill",
                size: .medium,
                color: coverIsLight ? .black : .white,
                action: viewModel.jumpToChapterStart
            )

            Spacer()

            GlassIconButton(
                icon: "gobackward.10",
                size: .medium,
                color: coverIsLight ? .black : .white,
                action: viewModel.jumpBackward
            )

            Spacer()

            playPauseButton

            Spacer()

            GlassIconButton(
                icon: "goforward.30",
                size: .medium,
                color: coverIsLight ? .black : .white,
                action: viewModel.jumpForward
            )

            Spacer()

            GlassIconButton(
                icon: "forward.end.fill",
                size: .medium,
                color: coverIsLight ? .black : .white,
                action: viewModel.jumpToNextChapter
            )
            .opacity(viewModel.hasNextChapter ? 1.0 : 0.3)
            .disabled(!viewModel.hasNextChapter)
        }
    }

    private var playPauseButton: some View {
        Button {
            viewModel.togglePlayPause()
        } label: {
            Image(systemName: viewModel.isPlaying ? "pause.fill" : "play.fill")
                .font(.system(size: 32))
                .foregroundStyle(coverIsLight ? .black : .white)
                .frame(width: 80, height: 80)
                .background {
                    Circle()
                        .fill(coverColor)
                        .overlay {
                            Circle()
                                .fill(.ultraThinMaterial)
                                .opacity(0.4)
                        }
                        .shadow(color: coverColor.opacity(0.5), radius: 20)
                }
        }
    }
}

// MARK: - Mini Player View

public struct MiniPlayerView: View {
    @State var audioPlayer: AudioPlayerService
    let onTap: () -> Void
    let onClose: () -> Void

    public init(audioPlayer: AudioPlayerService, onTap: @escaping () -> Void, onClose: @escaping () -> Void) {
        self.audioPlayer = audioPlayer
        self.onTap = onTap
        self.onClose = onClose
    }

    public var body: some View {
        HStack {
            Image(systemName: "music.note")
                .foregroundStyle(.cyan)
                .padding()
                .background(.white.opacity(0.1))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(audioPlayer.session?.displayTitle ?? "Sample Book Title")
                    .font(.subheadline.bold())
                    .foregroundStyle(.white)
                Text(audioPlayer.session?.displayAuthor ?? "Sample Author")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.6))
            }

            Spacer()

            Button {
                onTap()
            } label: {
                Image(systemName: "play.fill")
                    .font(.title2)
                    .foregroundStyle(.white)
            }
            .padding(.horizontal)

            Button {
                onClose()
            } label: {
                Image(systemName: "xmark")
                    .foregroundStyle(.white.opacity(0.6))
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(16)
        .padding(.horizontal)
        .onTapGesture {
            onTap()
        }
    }
}

// MARK: - Supporting Components

public struct GlassIconButton: View {
    public let icon: String
    public var fill: Bool = false
    public var size: ButtonSize = .medium
    public var color: Color = .white
    public let action: () -> Void

    public enum ButtonSize {
        case small, medium, large

        var iconSize: CGFloat {
            switch self {
            case .small: return 20
            case .medium: return 24
            case .large: return 32
            }
        }
    }

    public init(icon: String, fill: Bool = false, size: ButtonSize = .medium, color: Color = .white, action: @escaping () -> Void) {
        self.icon = icon
        self.fill = fill
        self.size = size
        self.color = color
        self.action = action
    }

    public var body: some View {
        Button {
            #if os(iOS) && !SKIP
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()
            #endif
            action()
        } label: {
            Image(systemName: icon)
                .font(.system(size: size.iconSize))
                .symbolVariant(fill ? .fill : .none)
                .foregroundStyle(color)
        }
    }
}

public struct ChapterListView: View {
    public let chapters: [Chapter]
    public let currentChapter: Chapter?
    public let onSelect: (Chapter) -> Void

    @Environment(\.dismiss) var dismiss

    private var trailingPlacement: ToolbarItemPlacement {
        #if os(iOS) || SKIP
        return .navigationBarTrailing
        #else
        return .primaryAction
        #endif
    }

    public init(chapters: [Chapter], currentChapter: Chapter?, onSelect: @escaping (Chapter) -> Void) {
        self.chapters = chapters
        self.currentChapter = currentChapter
        self.onSelect = onSelect
    }

    public var body: some View {
        NavigationStack {
            List(chapters) { chapter in
                Button {
                    onSelect(chapter)
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(chapter.title)
                                .font(.headline)

                            Text(formatDuration(chapter.duration))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        if chapter.id == currentChapter?.id {
                            Image(systemName: "speaker.wave.2.fill")
                                .foregroundStyle(.cyan)
                        }
                    }
                }
            }
            .navigationTitle("Chapters")
            #if os(iOS) || SKIP
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: trailingPlacement) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - ViewModel

@MainActor
public class AudioPlayerViewModel: ObservableObject {
    @Published public var isPlaying = false
    @Published public var progress: Double = 0.0
    @Published public var bufferedProgress: Double = 0.0
    @Published public var currentTime: TimeInterval = 0
    @Published public var playbackRate: Float = 1.0
    @Published public var sleepTimerActive = false
    @Published public var hasBookmarks = false
    @Published public var useTotalTrack = true

    public let session: PlaybackSession

    public var title: String { session.displayTitle }
    public var author: String { session.displayAuthor }
    public var duration: TimeInterval { session.duration }
    public var chapters: [Chapter] { session.chapters }

    public var coverURL: URL? {
        guard let path = session.coverPath else { return nil }
        return URL(string: path)
    }

    public var currentChapter: Chapter? {
        chapters.first { $0.start <= currentTime && $0.end > currentTime }
    }

    public var currentChapterTitle: String {
        currentChapter?.title ?? ""
    }

    public var hasNextChapter: Bool {
        chapters.contains { $0.start > currentTime }
    }

    public var totalProgress: Double {
        duration > 0 ? currentTime / duration : 0
    }

    public var currentTimePretty: String {
        formatTime(currentTime)
    }

    public var totalTimeRemainingPretty: String {
        "-" + formatTime(duration - currentTime)
    }

    public var currentChapterTimePretty: String {
        guard let chapter = currentChapter else { return currentTimePretty }
        return formatTime(currentTime - chapter.start)
    }

    public var timeRemainingPretty: String {
        guard let chapter = currentChapter else { return totalTimeRemainingPretty }
        return "-" + formatTime(chapter.end - currentTime)
    }

    public init(session: PlaybackSession) {
        self.session = session
        self.currentTime = session.currentTime
        self.playbackRate = session.playbackRate
    }

    public func togglePlayPause() {
        isPlaying.toggle()
    }

    public func seek(to time: TimeInterval) {
        currentTime = time
    }

    public func jumpForward() {
        seek(to: currentTime + 30)
    }

    public func jumpBackward() {
        seek(to: max(0, currentTime - 10))
    }

    public func jumpToChapterStart() {
        if let chapter = currentChapter {
            seek(to: chapter.start)
        }
    }

    public func jumpToNextChapter() {
        if let nextChapter = chapters.first(where: { $0.start > currentTime }) {
            seek(to: nextChapter.start)
        }
    }

    public func showBookmarks() {}
    public func showSpeedSelector() {}
    public func showSleepTimer() {}

    private func formatTime(_ time: TimeInterval) -> String {
        let hours = Int(time) / 3600
        let minutes = (Int(time) % 3600) / 60
        let seconds = Int(time) % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }
}
