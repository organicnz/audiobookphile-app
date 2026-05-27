//
//  AudioPlayerView.swift
//  AudiobookshelfClient
//
//  Full-screen audio player with bleeding-edge Liquid Glass design
//  Translates: components/app/AudioPlayer.vue
//

import SwiftUI
import AVFoundation

/// Full-screen audio player with heavy Liquid Glass treatment
struct AudioPlayerView: View {
    
    // MARK: - Properties
    @StateObject private var viewModel: AudioPlayerViewModel
    @ObservedObject private var proMotion = ProMotionManager.shared
    @Environment(\.dismiss) private var dismiss
    
    // UI State
    @State private var showFullscreen = true
    @State private var showChapters = false
    @State private var showMoreMenu = false
    @State private var isDraggingSeeker = false
    @State private var draggedTime: TimeInterval = 0
    
    // Visual effects
    @State private var coverColor: Color = .blue
    @State private var coverIsLight = false
    @GestureState private var dragOffset: CGFloat = 0
    
    init(session: PlaybackSession) {
        _viewModel = StateObject(wrappedValue: AudioPlayerViewModel(session: session))
    }
    
    var body: some View {
        ZStack {
            // Dynamic background with glass overlay
            backgroundLayer
            
            // Main content
            if showFullscreen {
                fullscreenPlayer
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            } else {
                miniPlayer
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .ignoresSafeArea()
        .optimizedForProMotion()
        .sheet(isPresented: $showChapters) {
            ChapterListView(
                chapters: viewModel.chapters,
                currentChapter: viewModel.currentChapter,
                currentTime: viewModel.currentTime,
                playbackRate: viewModel.playbackRate,
                onSelectChapter: { chapter in
                    viewModel.seek(to: chapter.start)
                    showChapters = false
                }
            )
        }
    }
    
    // MARK: - Background Layer
    
    private var backgroundLayer: some View {
        ZStack {
            // Dynamic color from cover
            coverColor
                .ignoresSafeArea()
            
            // Liquid gradient overlay
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
            
            // Glass overlay
            Rectangle()
                .fill(.ultraThinMaterial)
                .opacity(0.3)
                .ignoresSafeArea()
        }
    }
    
    // MARK: - Fullscreen Player
    
    private var fullscreenPlayer: some View {
        VStack(spacing: 0) {
            // Top bar
            topBar
                .padding(.top, 50)
            
            Spacer()
            
            // Cover art with parallax
            coverArtSection
                .padding(.vertical, 40)
            
            // Title and author
            titleSection
                .padding(.horizontal, 24)
            
            Spacer()
            
            // Playback controls
            VStack(spacing: 24) {
                // Total track (if enabled)
                if viewModel.useTotalTrack {
                    totalTrackView
                        .padding(.horizontal, 24)
                }
                
                // Quick actions
                quickActionsBar
                    .padding(.horizontal, 24)
                
                // Main track
                trackView
                    .padding(.horizontal, 24)
                
                // Playback buttons
                playbackControls
                    .padding(.horizontal, 24)
                    .padding(.bottom, 40)
            }
        }
        .gesture(
            DragGesture()
                .onEnded { value in
                    if value.translation.height > 100 {
                        withAnimation(proMotion.optimizedSpring()) {
                            showFullscreen = false
                        }
                    }
                }
        )
    }
    
    // MARK: - Top Bar
    
    private var topBar: some View {
        HStack {
            Button(action: collapsePlayer) {
                Image(systemName: "chevron.down")
                    .font(.title2)
                    .foregroundStyle(coverIsLight ? .black : .white)
            }
            
            Spacer()
            
            Button(action: { showMoreMenu = true }) {
                Image(systemName: "ellipsis")
                    .font(.title2)
                    .foregroundStyle(coverIsLight ? .black : .white)
            }
        }
        .padding(.horizontal, 24)
    }
    
    // MARK: - Cover Art with Parallax
    
    private var coverArtSection: some View {
        GeometryReader { geometry in
            AsyncImage(url: viewModel.coverURL) { phase in
                switch phase {
                case .empty:
                    placeholderCover
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .onAppear {
                            extractColor(from: image)
                        }
                case .failure:
                    placeholderCover
                @unknown default:
                    placeholderCover
                }
            }
            .frame(width: geometry.size.width * 0.7)
            .frame(maxWidth: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .shadow(
                color: coverColor.opacity(0.5),
                radius: 30,
                y: 15
            )
            // Parallax effect with gyroscope would go here
            .rotation3DEffect(
                .degrees(Double(dragOffset) * 0.1),
                axis: (x: 0, y: 1, z: 0)
            )
        }
        .frame(height: 400)
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
    
    // MARK: - Title Section
    
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
    
    // MARK: - Total Track View
    
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
            
            // Total progress bar (thin glass line)
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background track
                    Capsule()
                        .fill(.white.opacity(0.2))
                        .frame(height: 2)
                    
                    // Progress
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
    
    // MARK: - Quick Actions Bar
    
    private var quickActionsBar: some View {
        HStack(spacing: 0) {
            // Bookmarks
            GlassIconButton(
                icon: "bookmark",
                fill: viewModel.hasBookmarks,
                color: coverIsLight ? .black : .white,
                action: viewModel.showBookmarks
            )
            
            Spacer()
            
            // Playback speed
            Button(action: viewModel.showSpeedSelector) {
                Text("\(viewModel.playbackRate, specifier: "%.1f")×")
                    .font(.system(.body, design: .monospaced))
                    .fontWeight(.medium)
                    .foregroundStyle(coverIsLight ? .black : .white)
            }
            
            Spacer()
            
            // Sleep timer
            GlassIconButton(
                icon: "moon",
                fill: viewModel.sleepTimerActive,
                color: viewModel.sleepTimerActive ? .green : (coverIsLight ? .black : .white),
                action: viewModel.showSleepTimer
            )
            
            Spacer()
            
            // Chapters
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
    
    // MARK: - Track View
    
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
            
            // Main seek bar with glass cursor
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background
                    Capsule()
                        .fill(.white.opacity(0.3))
                    
                    // Buffered
                    Capsule()
                        .fill(.white.opacity(0.5))
                        .frame(width: geometry.size.width * CGFloat(viewModel.bufferedProgress))
                    
                    // Progress
                    Capsule()
                        .fill(coverColor)
                        .frame(width: geometry.size.width * CGFloat(viewModel.progress))
                    
                    // Glass cursor
                    if showFullscreen {
                        Circle()
                            .fill(.white)
                            .frame(width: 20, height: 20)
                            .shadow(color: .black.opacity(0.3), radius: 4)
                            .offset(x: geometry.size.width * CGFloat(viewModel.progress) - 10)
                    }
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
    
    // MARK: - Playback Controls
    
    private var playbackControls: some View {
        HStack(spacing: 0) {
            if showFullscreen {
                // Chapter start
                GlassIconButton(
                    icon: "backward.end.fill",
                    size: .medium,
                    color: coverIsLight ? .black : .white,
                    action: viewModel.jumpToChapterStart
                )
            }
            
            Spacer()
            
            // Jump backward
            GlassIconButton(
                icon: "gobackward.\(viewModel.jumpBackwardTime)",
                size: .medium,
                color: coverIsLight ? .black : .white,
                action: viewModel.jumpBackward
            )
            .accessibilityLabel("Jump backward \(viewModel.jumpBackwardTime) seconds")
            
            Spacer()
            
            // Play/Pause (large glass button)
            playPauseButton
            
            Spacer()
            
            // Jump forward
            GlassIconButton(
                icon: "goforward.\(viewModel.jumpForwardTime)",
                size: .medium,
                color: coverIsLight ? .black : .white,
                action: viewModel.jumpForward
            )
            .accessibilityLabel("Jump forward \(viewModel.jumpForwardTime) seconds")
            
            Spacer()
            
            if showFullscreen {
                // Next chapter
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
    }
    
    private var playPauseButton: some View {
        Button(action: viewModel.togglePlayPause) {
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
        .accessibilityLabel(viewModel.isPlaying ? "Pause" : "Play")
        .accessibilityAddTraits(.isButton)
        .scaleEffect(viewModel.isPlaying ? 1.0 : 1.05)
        .animation(proMotion.optimizedSpring(response: 0.3), value: viewModel.isPlaying)
    }
    
    // MARK: - Mini Player
    
    private var miniPlayer: some View {
        VStack {
            Spacer()
            
            GlassCard(padding: 12, cornerRadius: 16) {
                HStack(spacing: 12) {
                    // Small cover
                    AsyncImage(url: viewModel.coverURL) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Color.gray.opacity(0.3)
                    }
                    .frame(width: 50, height: 50)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    
                    // Title and author
                    VStack(alignment: .leading, spacing: 4) {
                        Text(viewModel.title)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .lineLimit(1)
                        
                        Text(viewModel.author)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    
                    Spacer()
                    
                    // Mini play button
                    Button(action: viewModel.togglePlayPause) {
                        Image(systemName: viewModel.isPlaying ? "pause.fill" : "play.fill")
                            .font(.title3)
                    }
                }
            }
            .padding()
            .onTapGesture {
                withAnimation(proMotion.optimizedSpring()) {
                    showFullscreen = true
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func collapsePlayer() {
        withAnimation(proMotion.optimizedSpring()) {
            showFullscreen = false
        }
    }
    
    private func extractColor(from image: Image) {
        // In a real implementation, use FastAverageColor or similar
        // For now, keep the default color
    }
}

// MARK: - Glass Icon Button

struct GlassIconButton: View {
    let icon: String
    var fill: Bool = false
    var size: ButtonSize = .medium
    var color: Color = .white
    let action: () -> Void
    
    enum ButtonSize {
        case small, medium, large
        
        var iconSize: CGFloat {
            switch self {
            case .small: return 20
            case .medium: return 24
            case .large: return 32
            }
        }
    }
    
    var body: some View {
        Button(action: {
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()
            action()
        }) {
            Image(systemName: icon)
                .font(.system(size: size.iconSize))
                .symbolVariant(fill ? .fill : .none)
                .foregroundStyle(color)
        }
    }
}



// MARK: - View Model (Placeholder)

@MainActor
class AudioPlayerViewModel: ObservableObject {
    // Published state
    @Published var isPlaying = false
    @Published var progress: Double = 0.0
    @Published var bufferedProgress: Double = 0.0
    @Published var currentTime: TimeInterval = 0
    @Published var playbackRate: Float = 1.0
    @Published var sleepTimerActive = false
    @Published var hasBookmarks = false
    @Published var useTotalTrack = true
    
    // Session data
    let session: PlaybackSession
    
    var title: String { session.displayTitle }
    var author: String { session.displayAuthor }
    var duration: TimeInterval { session.duration }
    var chapters: [Chapter] { session.chapters }
    var coverURL: URL? {
        guard let path = session.coverPath else { return nil }
        return URL(string: path)
    }
    
    var currentChapter: Chapter? {
        chapters.first { $0.start <= currentTime && $0.end > currentTime }
    }
    
    var currentChapterTitle: String {
        currentChapter?.title ?? ""
    }
    
    var hasNextChapter: Bool {
        chapters.contains { $0.start > currentTime }
    }
    
    var totalProgress: Double {
        duration > 0 ? currentTime / duration : 0
    }
    
    var currentTimePretty: String {
        formatTime(currentTime)
    }
    
    var totalTimeRemainingPretty: String {
        "-" + formatTime(duration - currentTime)
    }
    
    var currentChapterTimePretty: String {
        guard let chapter = currentChapter else { return currentTimePretty }
        return formatTime(currentTime - chapter.start)
    }
    
    var timeRemainingPretty: String {
        guard let chapter = currentChapter else { return totalTimeRemainingPretty }
        return "-" + formatTime(chapter.end - currentTime)
    }
    
    var jumpForwardTime: Int { 30 }
    var jumpBackwardTime: Int { 10 }
    
    init(session: PlaybackSession) {
        self.session = session
        self.currentTime = session.currentTime
        self.playbackRate = session.playbackRate
    }
    
    // Actions
    func togglePlayPause() {
        isPlaying.toggle()
    }
    
    func seek(to time: TimeInterval) {
        currentTime = time
    }
    
    func jumpForward() {
        seek(to: currentTime + TimeInterval(jumpForwardTime))
    }
    
    func jumpBackward() {
        seek(to: max(0, currentTime - TimeInterval(jumpBackwardTime)))
    }
    
    func jumpToChapterStart() {
        if let chapter = currentChapter {
            seek(to: chapter.start)
        }
    }
    
    func jumpToNextChapter() {
        if let nextChapter = chapters.first(where: { $0.start > currentTime }) {
            seek(to: nextChapter.start)
        }
    }
    
    func showBookmarks() {}
    func showSpeedSelector() {}
    func showSleepTimer() {}
    
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

// MARK: - Preview

#Preview("Audio Player") {
    AudioPlayerView(session: PlaybackSession(
        id: "preview",
        userId: "user1",
        libraryId: "lib1",
        libraryItemId: "item1",
        episodeId: nil,
        displayTitle: "The Midnight Library",
        displayAuthor: "Matt Haig",
        coverPath: nil,
        duration: 28800,
        playMethod: 0,
        mediaPlayer: "html5",
        mediaType: "book",
        audioTracks: [],
        chapters: [
            Chapter(id: 0, title: "Chapter 1: The Library", start: 0, end: 1800),
            Chapter(id: 1, title: "Chapter 2: Between Life and Death", start: 1800, end: 3600),
            Chapter(id: 2, title: "Chapter 3: The Book of Regrets", start: 3600, end: 5400)
        ],
        currentTime: 1200,
        playbackRate: 1.0,
        startedAt: Date(),
        updatedAt: Date()
    ))
}
