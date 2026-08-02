//
//  PlaybackControlsView.swift
//  Audiobookphile
//

import SwiftUI

public struct PlaybackControlsView: View {
    var viewModel: AudioPlayerViewModel
    var coverIsLight: Bool
    var isUiLocked: Bool

    public init(viewModel: AudioPlayerViewModel, coverIsLight: Bool, isUiLocked: Bool) {
        self.viewModel = viewModel
        self.coverIsLight = coverIsLight
        self.isUiLocked = isUiLocked
    }

    public var body: some View {
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
            ZStack {
                Image(systemName: viewModel.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(.black)
                    .applyPlayPauseSymbolEffect(isPlaying: viewModel.isPlaying)
                    .opacity(viewModel.isBuffering ? 0.3 : 1.0)
                if viewModel.isBuffering {
                    ProgressView()
                        .tint(.black)
                }
            }
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
