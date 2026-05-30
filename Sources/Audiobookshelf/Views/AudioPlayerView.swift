//
//  AudioPlayerView.swift
//  Audiobookshelf
//
//  Full-screen audio player with bleeding-edge Liquid Glass design.
//  Compatible with Swift 6.3 and Skip.
//

import SwiftUI
import Observation

public struct AudioPlayerView: View {
    @State var viewModel: AudioPlayerViewModel
    @ObservedObject var proMotion = ProMotionManager.shared
    @Environment(\.dismiss) var dismiss

    @State var showChapters = false
    @State var showMoreMenu = false
    @State var isDraggingSeeker = false
    @State var draggedTime: TimeInterval = 0

    @State var colorLoader = DynamicColorLoader()

    private var coverIsLight: Bool {
        colorLoader.textColor == .black
    }

    public init(session: PlaybackSession) {
        _viewModel = State(wrappedValue: AudioPlayerViewModel(session: session))
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
        .task {
            if let url = viewModel.coverURL {
                await colorLoader.loadColor(from: url)
            }
        }
    }

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
                    CachedAsyncImage(url: url) { image in
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
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .shadow(
                color: colorLoader.backgroundColor.opacity(0.5),
                radius: 30,
                y: 15
            )
        }
        .frame(height: 300)
    }

    private var placeholderCover: some View {
        ZStack {
            Image("BookPlaceholder", bundle: .module)
                .resizable()
                .aspectRatio(contentMode: .fill)
            
            Color.black.opacity(0.15)
        }
        .clipShape(RoundedRectangle(cornerRadius: 20))
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
                        .fill(Color.appPrimary)
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

            Menu {
                ForEach([0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0, 2.5], id: \.self) { rate in
                    Button {
                        viewModel.setPlaybackRate(Float(rate))
                    } label: {
                        HStack {
                            Text(String(format: "%.2f×", rate))
                            if abs(viewModel.playbackRate - Float(rate)) < 0.05 {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                Text("\(viewModel.playbackRate, specifier: "%.1f")×")
                    .font(.system(.body, design: .monospaced))
                    .fontWeight(.medium)
                    .foregroundStyle(coverIsLight ? .black : .white)
            }

            Spacer()

            Menu {
                if viewModel.sleepTimerActive {
                    Button(role: .destructive) {
                        AudioPlayerService.shared.stopSleepTimer()
                    } label: {
                        Label("Turn Off Timer", systemImage: "timer.circle.fill")
                    }
                    
                    Divider()
                }
                
                ForEach([5, 15, 30, 45, 60], id: \.self) { mins in
                    Button {
                        AudioPlayerService.shared.startSleepTimer(duration: TimeInterval(mins * 60))
                    } label: {
                        Text("\(mins) Minutes")
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "moon")
                        .symbolVariant(viewModel.sleepTimerActive ? .fill : .none)
                    if viewModel.sleepTimerActive {
                        Text(viewModel.sleepTimerRemainingPretty)
                            .font(.system(.caption, design: .monospaced))
                    }
                }
                .foregroundStyle(viewModel.sleepTimerActive ? Color.appPrimary : (coverIsLight ? .black : .white))
            }

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
                        .fill(Color.appPrimary)
                        .frame(width: geometry.size.width * CGFloat(viewModel.progress))

                    Circle()
                        .fill(Color.appPrimary)
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
                icon: "gobackward.\(viewModel.jumpBackwardTime)",
                size: .medium,
                color: coverIsLight ? .black : .white,
                action: viewModel.jumpBackward
            )

            Spacer()

            playPauseButton

            Spacer()

            GlassIconButton(
                icon: "goforward.\(viewModel.jumpForwardTime)",
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
                        .fill(Color.appPrimary)
                        .overlay {
                            Circle()
                                .fill(.ultraThinMaterial)
                                .opacity(0.2)
                        }
                        .shadow(color: Color.appPrimary.opacity(0.3), radius: 20)
                }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(viewModel.isPlaying ? "Pause" : "Play"))
        .accessibilityAddTraits(.isButton)
    }
}

