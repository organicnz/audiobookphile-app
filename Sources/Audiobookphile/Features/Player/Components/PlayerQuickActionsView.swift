//
//  PlayerQuickActionsView.swift
//  Audiobookphile
//

import SwiftUI

public struct PlayerQuickActionsView: View {
    var viewModel: AudioPlayerViewModel
    var coverIsLight: Bool

    @Binding var showAddBookmark: Bool
    @Binding var showBookmarksList: Bool
    @Binding var showSleepTimer: Bool
    @Binding var showAudioAccessibilitySheet: Bool
    @Binding var showChapters: Bool

    public init(
        viewModel: AudioPlayerViewModel,
        coverIsLight: Bool,
        showAddBookmark: Binding<Bool>,
        showBookmarksList: Binding<Bool>,
        showSleepTimer: Binding<Bool>,
        showAudioAccessibilitySheet: Binding<Bool>,
        showChapters: Binding<Bool>
    ) {
        self.viewModel = viewModel
        self.coverIsLight = coverIsLight
        self._showAddBookmark = showAddBookmark
        self._showBookmarksList = showBookmarksList
        self._showSleepTimer = showSleepTimer
        self._showAudioAccessibilitySheet = showAudioAccessibilitySheet
        self._showChapters = showChapters
    }

    public var body: some View {
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
                GlassIconButton(
                    icon: viewModel.hasBookmarks ? "bookmark.fill" : "bookmark",
                    fill: viewModel.hasBookmarks,
                    color: coverIsLight ? .black : .white,
                    action: {}
                )
                .allowsHitTesting(false)
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
                    .fontWeight(.bold)
                    .foregroundStyle(coverIsLight ? .black : .white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.white.opacity(0.12))
                    .clipShape(Capsule())
                    .overlay(
                        Capsule()
                            .strokeBorder(LinearGradient(colors: [.white.opacity(0.3), .white.opacity(0.05)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1)
                    )
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
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.white.opacity(0.12))
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .strokeBorder(LinearGradient(colors: [.white.opacity(0.3), .white.opacity(0.05)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1)
                )
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
}
