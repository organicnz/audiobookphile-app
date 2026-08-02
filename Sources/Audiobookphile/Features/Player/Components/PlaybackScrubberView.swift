//
//  PlaybackScrubberView.swift
//  Audiobookphile
//

import SwiftUI

public struct PlaybackScrubberView: View {
    var viewModel: AudioPlayerViewModel
    var coverIsLight: Bool
    var isUiLocked: Bool

    @State private var isDraggingSeeker = false
    @State private var draggedTime: TimeInterval = 0

    public init(viewModel: AudioPlayerViewModel, coverIsLight: Bool, isUiLocked: Bool) {
        self.viewModel = viewModel
        self.coverIsLight = coverIsLight
        self.isUiLocked = isUiLocked
    }

    public var body: some View {
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
                let rawProgress = isDraggingSeeker ? (viewModel.duration > 0 ? draggedTime / viewModel.duration : 0) : (viewModel.useTotalTrack ? viewModel.totalProgress : viewModel.progress)
                let currentVisualProgress = max(0, min(1, rawProgress)) // Clamp to 0...1
                
                // Bulletproof hit testing: Clear background takes the gesture, visuals are just an overlay
                Color.clear
                    .contentShape(Rectangle())
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
                    .overlay(alignment: .leading) {
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(.white.opacity(0.3))
                                .frame(height: 6)

                            Capsule()
                                .fill(.white.opacity(0.5))
                                .frame(width: max(0, geometry.size.width * CGFloat(viewModel.bufferedProgress)), height: 6)

                            Capsule()
                                .fill(Color.appPrimary)
                                .frame(width: max(0, geometry.size.width * CGFloat(currentVisualProgress)), height: 6)

                            Circle()
                                .fill(Color.appPrimary)
                                .frame(width: 20, height: 20)
                                .shadow(color: .black.opacity(0.3), radius: 4)
                                .offset(x: max(0, geometry.size.width * CGFloat(currentVisualProgress) - 10))
                        }
                        .allowsHitTesting(false)
                    }
            }
            .frame(height: 44)
        }
    }
}
