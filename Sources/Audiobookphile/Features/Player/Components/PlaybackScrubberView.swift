//
//  PlaybackScrubberView.swift
//  Audiobookphile
//

import SwiftUI

public struct PlaybackScrubberView: View {
    var viewModel: AudioPlayerViewModel
    var coverIsLight: Bool
    var isUiLocked: Bool

    @State private var isDragging = false
    @State private var draggedProgress: Double = 0

    public init(viewModel: AudioPlayerViewModel, coverIsLight: Bool, isUiLocked: Bool) {
        self.viewModel = viewModel
        self.coverIsLight = coverIsLight
        self.isUiLocked = isUiLocked
    }

    // The progress value to show on the track — frozen to drag position while scrubbing
    private var displayProgress: Double {
        isDragging ? draggedProgress : viewModel.totalProgress
    }

    // The time value shown in the left timestamp label
    private var displayTime: TimeInterval {
        isDragging ? viewModel.duration * draggedProgress : viewModel.currentTime
    }

    public var body: some View {
        VStack(spacing: 8) {
            // Time labels
            HStack {
                Text(viewModel.formatTime(displayTime))
                    .font(.system(.caption, design: .monospaced))
                Spacer()
                Text("-" + viewModel.formatTime(max(0, viewModel.duration - displayTime)))
                    .font(.system(.caption, design: .monospaced))
            }
            .foregroundStyle(coverIsLight ? .black : .white)
            .animation(.none, value: isDragging)

            // Track — GeometryReader gives us the pixel width for progress calculation
            GeometryReader { proxy in
                let width = proxy.size.width
                let filled = max(0, min(1, displayProgress))
                let buffered = max(0, min(1, viewModel.bufferedProgress))

                ZStack(alignment: .leading) {
                    // Invisible full-area tap/drag target — must be first so it's below visuals
                    // but since allowsHitTesting is false on visuals, this receives all touches
                    Color.clear
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .contentShape(Rectangle())
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    guard !isUiLocked else { return }
                                    if !isDragging { isDragging = true }
                                    draggedProgress = min(max(0, value.location.x / width), 1)
                                }
                                .onEnded { value in
                                    guard !isUiLocked else { return }
                                    let finalProgress = min(max(0, value.location.x / width), 1)
                                    viewModel.seek(to: viewModel.duration * finalProgress)
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                        isDragging = false
                                    }
                                }
                        )

                    // Visuals — non-interactive
                    VStack(spacing: 0) {
                        Spacer()
                        ZStack(alignment: .leading) {
                            // Background rail
                            Capsule()
                                .fill(Color.white.opacity(0.25))
                                .frame(height: 4)

                            // Buffered rail
                            Capsule()
                                .fill(Color.white.opacity(0.45))
                                .frame(width: width * CGFloat(buffered), height: 4)

                            // Played rail
                            Capsule()
                                .fill(Color.appPrimary)
                                .frame(width: width * CGFloat(filled), height: 4)

                            // Thumb
                            Circle()
                                .fill(Color.white)
                                .frame(width: isDragging ? 24 : 18, height: isDragging ? 24 : 18)
                                .shadow(color: Color.black.opacity(0.35), radius: isDragging ? 8 : 4, y: 2)
                                .offset(x: (width * CGFloat(filled)) - (isDragging ? 12 : 9))
                                .animation(.spring(response: 0.2, dampingFraction: 0.7), value: isDragging)
                        }
                        Spacer()
                    }
                    .allowsHitTesting(false)
                }
                .opacity(isUiLocked ? 0.4 : 1.0)
            }
            .frame(height: 44)
        }
    }
}
