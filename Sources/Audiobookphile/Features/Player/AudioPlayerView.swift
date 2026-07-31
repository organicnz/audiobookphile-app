//
//  AudioPlayerView.swift
//  Audiobookphile
//
//  Full-screen audio player with bleeding-edge Liquid Glass design.
//  Compatible with Swift 6.3 and Skip.
//

import SwiftUI
import Observation
#if os(iOS) && !SKIP
import UIKit
#endif

public struct AudioPlayerView: View {
    @State var viewModel: AudioPlayerViewModel
    var proMotion = ProMotionManager.shared
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) var dismiss

    @State var showChapters = false
    @State var showSleepTimer = false
    @State var showMoreMenu = false
    @State var isDraggingSeeker = false
    @State var draggedTime: TimeInterval = 0
    @State var isUiLocked = false
    @State var showBookmarksList = false
    @State var showAddBookmark = false
    @State var showAudioAccessibilitySheet = false
    @State var newBookmarkTitle = ""
    @State var isAnimatingBackground = false

    @State var colorLoader = DynamicColorLoader()

    private var coverIsLight: Bool {
        colorLoader.textColor == .black
    }

    private var coverURL: URL? {
        appState.getCoverURL(itemId: viewModel.session.libraryItemId)
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
        .applyToolbarAdapters(isLight: colorLoader.isLight, isHidden: isUiLocked)
        .ignoresSafeArea()
        .optimizedForProMotion()
        .alert("Add Bookmark", isPresented: $showAddBookmark) {
            TextField("Bookmark Title (Optional)", text: $newBookmarkTitle)
            Button("Cancel", role: .cancel) {
                newBookmarkTitle = ""
            }
            Button("Save") {
                viewModel.addBookmark(title: newBookmarkTitle)
                newBookmarkTitle = ""
            }
        }
        .sheet(isPresented: $showBookmarksList) {
            BookmarksListView(viewModel: viewModel)
        }
        .sheet(isPresented: $showChapters) {
            ChapterSelectionView(
                chapters: viewModel.chapters,
                currentChapter: viewModel.currentChapter,
                onSelect: { chapter in
                    viewModel.seek(to: chapter.start)
                    showChapters = false
                }
            )
        }
        .sheet(isPresented: $showSleepTimer) {
            SleepTimerView(
                onSetTimer: { duration in
                    if let duration = duration {
                        AudioPlayerService.shared.startSleepTimer(duration: duration)
                    } else {
                        AudioPlayerService.shared.stopSleepTimer()
                    }
                },
                onSetEndOfChapter: {
                    if let chapter = viewModel.currentChapter {
                        let remaining = chapter.end - viewModel.currentTime
                        if remaining > 0 {
                            AudioPlayerService.shared.startSleepTimer(duration: remaining)
                        }
                    }
                }
            )
        }
        .sheet(isPresented: $showAudioAccessibilitySheet) {
            AudioAccessibilityQuickSheet()
        }
        .task {
            if let url = coverURL {
                await colorLoader.loadColor(from: url)
            }
        }
    }

    private var backgroundLayer: some View {
        ZStack {
            // Apple Music-style dynamic cover art background
            if let url = coverURL {
                GeometryReader { proxy in
                    SmartAsyncImage(url: url) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: proxy.size.width * 1.5, height: proxy.size.height * 1.5)
                            .blur(radius: 100, opaque: true)
                            .scaleEffect(isAnimatingBackground ? 1.1 : 1.0)
                            .rotationEffect(.degrees(isAnimatingBackground ? 10 : -10))
                            .offset(x: isAnimatingBackground ? -20 : 20, y: isAnimatingBackground ? -20 : 20)
                    } placeholder: {
                        colorLoader.backgroundColor
                    }
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .clipped()
                }
            } else {
                Color.appBackground
            }

            // Darken/Blend overlay to ensure text is readable
            LinearGradient(
                colors: [
                    Color.black.opacity(0.3),
                    Color.black.opacity(0.6)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .ignoresSafeArea()
        .onAppear {
            withAnimation(.easeInOut(duration: 15).repeatForever(autoreverses: true)) {
                isAnimatingBackground = true
            }
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
                .padding(.vertical, 20)

            // Hardware vDSP Audio Spectrum Visualizer
            VDSPAudioVisualizer(isPlaying: viewModel.isPlaying, color: coverIsLight ? .black : Color.appPrimary)
                .padding(.bottom, 12)

            // Title and author
            titleSection
                .padding(.horizontal, 24)

            Spacer()

            // Playback controls
            VStack(spacing: 24) {
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
                withAnimation {
                    isUiLocked.toggle()
                }
            } label: {
                Image(systemName: isUiLocked ? "lock.fill" : "lock.open")
                    .font(.title2)
                    .foregroundStyle(isUiLocked ? Color.appPrimary : (coverIsLight ? .black : .white))
            }
            .padding(.trailing, 16)

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
            let cardSide = min(geometry.size.width * 0.76, geometry.size.height * 0.9)
            ZStack {
                if let url = coverURL {
                    // AudioBooth signature background blur backdrop
                    SmartAsyncImage(url: url) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        colorLoader.backgroundColor
                    }
                    .frame(width: cardSide, height: cardSide)
                    .blur(radius: 12, opaque: true)
                    .opacity(0.4)

                    // AudioBooth unclipped foreground artwork (.fit)
                    SmartAsyncImage(url: url) { image in
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
            .frame(width: cardSide, height: cardSide)
            .clipped()
            .frame(maxWidth: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [.white.opacity(0.4), .white.opacity(0.08)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            // AudioBooth signature topLeading Progress Badge
            .overlay(alignment: .topLeading) {
                let progPercent = Int(viewModel.progress * 100)
                audiobookphileBadge(text: "\(progPercent)%")
                    .padding(8)
            }
            // AudioBooth signature topTrailing Sleep Timer Badge (if active)
            .overlay(alignment: .topTrailing) {
                if viewModel.sleepTimerActive {
                    audiobookphileBadge(icon: "timer", text: viewModel.sleepTimerRemainingPretty)
                        .padding(8)
                }
            }
            .scaleEffect(viewModel.isPlaying ? 1.02 : 0.96)
            .animation(.spring(response: 0.5, dampingFraction: 0.7), value: viewModel.isPlaying)
            .shadow(
                color: colorLoader.backgroundColor.opacity(0.55),
                radius: 35,
                y: 18
            )
        }
        .frame(height: 300)
    }

    private func audiobookphileBadge(icon: String? = nil, text: String) -> some View {
        HStack(spacing: 4) {
            if let icon = icon {
                Image(systemName: icon)
            }
            Text(text)
        }
        .font(.footnote)
        .fontWeight(.bold)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Color.black.opacity(0.75))
        .foregroundColor(.white)
        .clipShape(Capsule())
    }

    private var placeholderCover: some View {
        ZStack {
            Image("BookPlaceholder", bundle: .module)
                .resizable()
                .aspectRatio(contentMode: .fill)

            Color.black.opacity(0.15)
        }
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
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

    private var quickActionsBar: some View {
        HStack(spacing: 0) {
            Menu {
                Button {
                    showAddBookmark = true
                } label: {
                    Label("Add Bookmark", systemImage: "plus")
                }
                Button {
                    showBookmarksList = true
                } label: {
                    Label("View Bookmarks", systemImage: "list.bullet")
                }
            } label: {
                Image(systemName: viewModel.hasBookmarks ? "bookmark.fill" : "bookmark")
                    .font(.title2)
                    .foregroundStyle(coverIsLight ? .black : .white)
                    .frame(width: 44, height: 44)
                    .background(Color.white.opacity(0.1))
                    .clipShape(Circle())
            }

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

            Button {
                showSleepTimer = true
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

            AirPlayButton(color: coverIsLight ? .black : .white)

            Spacer()

            GlassIconButton(
                icon: "waveform.path.badge.plus",
                fill: false,
                color: coverIsLight ? .black : .white,
                action: { showAudioAccessibilitySheet = true }
            )
            .accessibilityLabel("Audio & Hardware Accessibility")

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
                Text(isDraggingSeeker ? viewModel.formatTime(draggedTime) : viewModel.currentTimePretty)
                    .font(.system(.caption, design: .monospaced))
                Spacer()
                Text(isDraggingSeeker ? "-" + viewModel.formatTime(viewModel.duration - draggedTime) : viewModel.totalTimeRemainingPretty)
                    .font(.system(.caption, design: .monospaced))
            }
            .foregroundStyle(coverIsLight ? .black : .white)

            GeometryReader { geometry in
                let currentVisualProgress = isDraggingSeeker ? (viewModel.duration > 0 ? draggedTime / viewModel.duration : 0) : (viewModel.useTotalTrack ? viewModel.totalProgress : viewModel.progress)
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(.white.opacity(0.3))

                    Capsule()
                        .fill(.white.opacity(0.5))
                        .frame(width: geometry.size.width * CGFloat(viewModel.bufferedProgress))

                    Capsule()
                        .fill(Color.appPrimary)
                        .frame(width: geometry.size.width * CGFloat(currentVisualProgress))

                    Circle()
                        .fill(Color.appPrimary)
                        .frame(width: 20, height: 20)
                        .shadow(color: .black.opacity(0.3), radius: 4)
                        .offset(x: geometry.size.width * CGFloat(currentVisualProgress) - 10)
                }
                .frame(height: 6)
                .gesture(
                    isUiLocked ? nil : DragGesture(minimumDistance: 0)
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
                action: {
                    triggerHaptic(isLight: true)
                    viewModel.jumpToChapterStart()
                }
            )

            Spacer()

            GlassIconButton(
                icon: "gobackward.\(viewModel.jumpBackwardTime)",
                size: .medium,
                color: coverIsLight ? .black : .white,
                action: {
                    triggerHaptic(isLight: true)
                    viewModel.jumpBackward()
                }
            )
            .disabled(isUiLocked)
            .opacity(isUiLocked ? 0.3 : 1.0)

            Spacer()

            playPauseButton

            Spacer()

            GlassIconButton(
                icon: "goforward.\(viewModel.jumpForwardTime)",
                size: .medium,
                color: coverIsLight ? .black : .white,
                action: {
                    triggerHaptic(isLight: true)
                    viewModel.jumpForward()
                }
            )
            .disabled(isUiLocked)
            .opacity(isUiLocked ? 0.3 : 1.0)

            Spacer()

            GlassIconButton(
                icon: "forward.end.fill",
                size: .medium,
                color: coverIsLight ? .black : .white,
                action: {
                    triggerHaptic(isLight: true)
                    viewModel.jumpToNextChapter()
                }
            )
            .opacity(viewModel.hasNextChapter ? 1.0 : 0.3)
            .disabled(!viewModel.hasNextChapter)
        }
    }

    private func triggerHaptic(isLight: Bool = false) {
        #if os(iOS) && !SKIP
        let feedbackStyle: UIImpactFeedbackGenerator.FeedbackStyle = isLight ? .light : .medium
        UIImpactFeedbackGenerator(style: feedbackStyle).impactOccurred()
        #endif
    }

    private var playPauseButton: some View {
        Button {
            triggerHaptic()
            viewModel.togglePlayPause()
        } label: {
            Image(systemName: viewModel.isPlaying ? "pause.fill" : "play.fill")
                .font(.system(size: 32))
                .foregroundStyle(.black)
                .applyPlayPauseSymbolEffect(isPlaying: viewModel.isPlaying)
                .frame(width: 76, height: 76)
                .background {
                    Circle()
                        .fill(Color.white)
                        .shadow(color: Color.black.opacity(0.25), radius: 10, x: 0, y: 4)
                }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(viewModel.isPlaying ? "Pause" : "Play"))
        .accessibilityAddTraits(.isButton)
    }
}

// MARK: - Audio Accessibility Quick Sheet

public struct AudioAccessibilityQuickSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var settings = AppState.shared.settings

    public init() {}

    public var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()

                VStack(spacing: 16) {
                    List {
                        Section(header: Text("Spoken Audio & Speech Clarity").foregroundStyle(.white.opacity(0.7))) {
                            Toggle("Spoken Audio Optimization", isOn: Binding(
                                get: { settings.spokenAudioModeEnabled },
                                set: { newValue in
                                    settings.spokenAudioModeEnabled = newValue
                                    AppState.shared.updateSettings(settings)
                                    #if os(iOS)
                                    AudioPlayerService.shared.reconfigureAudioSession()
                                    #endif
                                }
                            ))

                            Toggle("Vocal Clarity Boost", isOn: Binding(
                                get: { settings.vocalBoostEnabled },
                                set: { newValue in
                                    settings.vocalBoostEnabled = newValue
                                    AppState.shared.updateSettings(settings)
                                    AudioPlayerService.shared.applyAudioDSP()
                                }
                            ))

                            Toggle("Smart Volume Leveler", isOn: Binding(
                                get: { settings.volumeLevelerEnabled },
                                set: { newValue in
                                    settings.volumeLevelerEnabled = newValue
                                    AppState.shared.updateSettings(settings)
                                    AudioPlayerService.shared.applyAudioDSP()
                                }
                            ))

                            Toggle("Mono Audio Mix", isOn: Binding(
                                get: { settings.monoAudioEnabled },
                                set: { newValue in
                                    settings.monoAudioEnabled = newValue
                                    AppState.shared.updateSettings(settings)
                                }
                            ))
                        }
                        .listRowBackground(Color.white.opacity(0.08))

                        Section(header: Text("Audiophile DSP & Fidelity").foregroundStyle(.white.opacity(0.7))) {
                            Toggle("High-Res 48kHz Output", isOn: Binding(
                                get: { settings.highResAudioEnabled },
                                set: { newValue in
                                    settings.highResAudioEnabled = newValue
                                    AppState.shared.updateSettings(settings)
                                    #if os(iOS)
                                    AudioPlayerService.shared.reconfigureAudioSession()
                                    #endif
                                    AudioPlayerService.shared.applyAudioDSP()
                                }
                            ))

                            Toggle("Low-Cut Rumble Filter (80Hz)", isOn: Binding(
                                get: { settings.lowCutFilterEnabled },
                                set: { newValue in
                                    settings.lowCutFilterEnabled = newValue
                                    AppState.shared.updateSettings(settings)
                                    AudioPlayerService.shared.applyAudioDSP()
                                }
                            ))

                            Toggle("De-Esser Sibilance Reducer", isOn: Binding(
                                get: { settings.deEsserEnabled },
                                set: { newValue in
                                    settings.deEsserEnabled = newValue
                                    AppState.shared.updateSettings(settings)
                                    AudioPlayerService.shared.applyAudioDSP()
                                }
                            ))
                        }
                        .listRowBackground(Color.white.opacity(0.08))
                    }
                    .scrollContentBackground(.hidden)
                }
            }
            .navigationTitle("Audio Accessibility")
            #if os(iOS) || SKIP
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundStyle(Color.appPrimary)
                }
            }
        }
        .presentationDetents([.medium])
    }
}
