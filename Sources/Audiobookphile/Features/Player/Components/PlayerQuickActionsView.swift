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
    @Binding var showAIInsights: Bool

    public init(
        viewModel: AudioPlayerViewModel,
        coverIsLight: Bool,
        showAddBookmark: Binding<Bool>,
        showBookmarksList: Binding<Bool>,
        showSleepTimer: Binding<Bool>,
        showAudioAccessibilitySheet: Binding<Bool>,
        showChapters: Binding<Bool>,
        showAIInsights: Binding<Bool>
    ) {
        self.viewModel = viewModel
        self.coverIsLight = coverIsLight
        self._showAddBookmark = showAddBookmark
        self._showBookmarksList = showBookmarksList
        self._showSleepTimer = showSleepTimer
        self._showAudioAccessibilitySheet = showAudioAccessibilitySheet
        self._showChapters = showChapters
        self._showAIInsights = showAIInsights
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
                    size: .medium,
                    color: coverIsLight ? .black : .white,
                    action: {}
                )
                .allowsHitTesting(false)
            }

            Spacer(minLength: 2)

            // AI Insights Engine Button
            Button {
                showAIInsights = true
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.cyan)
                    Text("AI Insights")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(.cyan)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                .padding(.horizontal, 10)
                .frame(height: 40)
                .background(Color.cyan.opacity(0.18))
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .strokeBorder(
                            LinearGradient(
                                colors: [.cyan.opacity(0.6), .cyan.opacity(0.2)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
                .shadow(color: Color.cyan.opacity(0.18), radius: 6, x: 0, y: 3)
            }
            .fixedSize(horizontal: true, vertical: false)
            .liquidPressable()

            Spacer(minLength: 2)

            // Playback Speed Menu
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
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .foregroundStyle(coverIsLight ? .black : .white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .padding(.horizontal, 10)
                    .frame(height: 40)
                    .background(Color.white.opacity(0.14))
                    .clipShape(Capsule())
                    .overlay(
                        Capsule()
                            .strokeBorder(
                                LinearGradient(colors: [.white.opacity(0.4), .white.opacity(0.08)], startPoint: .topLeading, endPoint: .bottomTrailing),
                                lineWidth: 1
                            )
                    )
                    .shadow(color: Color.black.opacity(0.12), radius: 6, x: 0, y: 3)
            }
            .fixedSize(horizontal: true, vertical: false)

            Spacer(minLength: 2)

            // Sleep Timer Button
            Button {
                showSleepTimer = true
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "moon")
                        .font(.system(size: 15, weight: .semibold))
                        .symbolVariant(viewModel.sleepTimerActive ? .fill : .none)
                    if viewModel.sleepTimerActive {
                        Text(viewModel.sleepTimerRemainingPretty)
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                }
                .foregroundStyle(viewModel.sleepTimerActive ? Color.appPrimary : (coverIsLight ? .black : .white))
                .padding(.horizontal, viewModel.sleepTimerActive ? 10 : 0)
                .frame(width: viewModel.sleepTimerActive ? nil : 40, height: 40)
                .background(
                    viewModel.sleepTimerActive
                    ? Color.appPrimary.opacity(0.2)
                    : Color.white.opacity(0.14)
                )
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .strokeBorder(
                            LinearGradient(
                                colors: viewModel.sleepTimerActive
                                    ? [Color.appPrimary.opacity(0.6), Color.appPrimary.opacity(0.2)]
                                    : [.white.opacity(0.4), .white.opacity(0.08)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
                .shadow(color: Color.black.opacity(0.12), radius: 6, x: 0, y: 3)
            }
            .fixedSize(horizontal: true, vertical: false)
            .liquidPressable()

            Spacer(minLength: 2)

            // AirPlay Route Picker Button
            AirPlayButton(color: coverIsLight ? .black : .white, size: 40)

            Spacer(minLength: 2)

            // Audio FX / Accessibility Button
            GlassIconButton(
                icon: "waveform.path.badge.plus",
                fill: false,
                size: .medium,
                color: coverIsLight ? .black : .white,
                action: { showAudioAccessibilitySheet = true }
            )
            .accessibilityLabel("Audio & Hardware Accessibility")

            Spacer(minLength: 2)

            // Chapters List Button
            GlassIconButton(
                icon: "list.bullet",
                fill: false,
                size: .medium,
                color: coverIsLight ? .black : .white,
                action: { showChapters = true }
            )
            .opacity(viewModel.chapters.isEmpty ? 0.3 : 1.0)
            .disabled(viewModel.chapters.isEmpty)
        }
    }
}
