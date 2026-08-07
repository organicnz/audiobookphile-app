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

            Slider(
                value: Binding(
                    get: { displayTime },
                    set: { newValue in
                        if !isDragging {
                            isDragging = true
                        }
                        let dur = viewModel.duration > 0 ? viewModel.duration : 1
                        draggedProgress = newValue / dur
                    }
                ),
                in: 0...(viewModel.duration > 0 ? viewModel.duration : 1),
                onEditingChanged: { editing in
                    if editing && !isDragging {
                        let dur = viewModel.duration > 0 ? viewModel.duration : 1
                        draggedProgress = viewModel.currentTime / dur
                    }
                    isDragging = editing
                    if !editing {
                        viewModel.seek(to: draggedProgress * viewModel.duration)
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
