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
        if isDragging {
            let dur = viewModel.duration > 0 ? viewModel.duration : 1
            return max(0, min(dur, dur * draggedProgress))
        }
        return viewModel.currentTime
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

            Slider(
                value: Binding(
                    get: { displayTime },
                    set: { newValue in
                        if !isDragging {
                            isDragging = true
                        }
                        let dur = viewModel.duration > 0 ? viewModel.duration : 1
                        draggedProgress = max(0, min(1, newValue / dur))
                    }
                ),
                in: 0...max(1, viewModel.duration),
                onEditingChanged: { editing in
                    if editing {
                        isDragging = true
                        let dur = viewModel.duration > 0 ? viewModel.duration : 1
                        draggedProgress = max(0, min(1, viewModel.currentTime / dur))
                    } else {
                        let dur = viewModel.duration > 0 ? viewModel.duration : 1
                        let targetTime = max(0, min(dur, draggedProgress * dur))
                        viewModel.seek(to: targetTime)
                        // Monotonic seek epoch tracking in AudioPlayerService guarantees that
                        // currentTime immediately reflects targetTime and periodic ticks are suppressed
                        // until AVPlayer finishes seeking.
                        isDragging = false
                    }
                }
            )
            .tint(.appPrimary)
            .disabled(isUiLocked)
            .opacity(isUiLocked ? 0.4 : 1.0)
            .frame(height: 44)
        }
    }
}
