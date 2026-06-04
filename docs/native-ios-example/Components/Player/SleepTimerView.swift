//
//  SleepTimerView.swift
//  AudiobookphileClient
//
//  Sleep timer modal with Liquid Glass design
//

import SwiftUI

struct SleepTimerView: View {
    @ObservedObject var audioPlayer: AudioPlayerService
    @Environment(\.dismiss) private var dismiss

    @State private var selectedMinutes: Int? = nil
    @State private var customMinutes = 30
    @State private var showCustomPicker = false

    let timerOptions = [5, 10, 15, 30, 45, 60, 90, 120]

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()

                VStack(spacing: 24) {
                    // Active timer display
                    if let remaining = audioPlayer.sleepTimerRemaining {
                        activeTimerSection(remaining: remaining)
                    }

                    // Timer options grid
                    timerOptionsGrid

                    // End of chapter option
                    endOfChapterOption

                    // Custom time option
                    customTimeOption

                    Spacer()
                }
                .padding(16)
            }
            .navigationTitle("Sleep Timer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundStyle(.cyan)
                }
            }
        }
    }

    // MARK: - Active Timer Section

    private func activeTimerSection(remaining: TimeInterval) -> some View {
        VStack(spacing: 16) {
            ZStack {
                // Background circle
                Circle()
                    .stroke(.white.opacity(0.1), lineWidth: 8)

                // Progress circle
                Circle()
                    .trim(from: 0, to: audioPlayer.sleepTimerProgress)
                    .stroke(
                        LinearGradient(
                            colors: [.cyan, .blue],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: 8, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 1), value: audioPlayer.sleepTimerProgress)

                // Time display
                VStack(spacing: 4) {
                    Text(TimeFormatter.sleepTimerRemaining(Int(remaining)))
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)

                    Text("remaining")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.6))
                }
            }
            .frame(width: 160, height: 160)

            // Cancel button
            Button {
                audioPlayer.cancelSleepTimer()
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            } label: {
                Label("Cancel Timer", systemImage: "xmark.circle")
                    .font(.subheadline)
                    .foregroundStyle(.red)
            }
        }
        .padding(.vertical, 16)
    }

    // MARK: - Timer Options Grid

    private var timerOptionsGrid: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Set Timer")
                .font(.headline)
                .foregroundStyle(.white)

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                ForEach(timerOptions, id: \.self) { minutes in
                    TimerOptionButton(
                        minutes: minutes,
                        isSelected: selectedMinutes == minutes
                    ) {
                        selectTimer(minutes: minutes)
                    }
                }
            }
        }
    }

    // MARK: - End of Chapter Option

    private var endOfChapterOption: some View {
        Button {
            selectEndOfChapter()
        } label: {
            HStack {
                Image(systemName: "text.book.closed")
                    .foregroundStyle(.cyan)

                Text("End of Chapter")
                    .foregroundStyle(.white)

                Spacer()

                if audioPlayer.sleepTimerMode == .endOfChapter {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.cyan)
                }
            }
            .padding(16)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    // MARK: - Custom Time Option

    private var customTimeOption: some View {
        VStack(spacing: 12) {
            Button {
                withAnimation {
                    showCustomPicker.toggle()
                }
            } label: {
                HStack {
                    Image(systemName: "slider.horizontal.3")
                        .foregroundStyle(.cyan)

                    Text("Custom Time")
                        .foregroundStyle(.white)

                    Spacer()

                    Image(systemName: showCustomPicker ? "chevron.up" : "chevron.down")
                        .foregroundStyle(.white.opacity(0.6))
                }
                .padding(16)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            if showCustomPicker {
                HStack(spacing: 16) {
                    Picker("Minutes", selection: $customMinutes) {
                        ForEach(Array(stride(from: 5, through: 180, by: 5)), id: \.self) { minutes in
                            Text("\(minutes) min")
                                .tag(minutes)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(height: 120)

                    GlassButton(
                        "Set",
                        icon: "timer",
                        size: .medium,
                        colors: [.cyan, .blue]
                    ) {
                        selectTimer(minutes: customMinutes)
                    }
                }
                .padding(16)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    // MARK: - Actions

    private func selectTimer(minutes: Int) {
        selectedMinutes = minutes
        audioPlayer.setSleepTimer(minutes: minutes)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            dismiss()
        }
    }

    private func selectEndOfChapter() {
        audioPlayer.setSleepTimerEndOfChapter()
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            dismiss()
        }
    }
}

// MARK: - Timer Option Button

struct TimerOptionButton: View {
    let minutes: Int
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Text("\(minutes)")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(isSelected ? .white : .white.opacity(0.8))

                Text("min")
                    .font(.caption)
                    .foregroundStyle(isSelected ? .white.opacity(0.8) : .white.opacity(0.5))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                isSelected
                    ? LinearGradient(colors: [.cyan, .blue], startPoint: .topLeading, endPoint: .bottomTrailing)
                    : LinearGradient(colors: [.white.opacity(0.1), .white.opacity(0.05)], startPoint: .top, endPoint: .bottom)
            )
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
}

// MARK: - Audio Player Extension

extension AudioPlayerService {
    enum SleepTimerMode {
        case none, timed, endOfChapter
    }

    var sleepTimerRemaining: TimeInterval? {
        // Would be implemented in actual player
        nil
    }

    var sleepTimerProgress: Double {
        // Would return progress 0-1
        0.7
    }

    var sleepTimerMode: SleepTimerMode {
        .none
    }

    func setSleepTimer(minutes: Int) {
        // Implementation
        print("[AudioPlayerService] Sleep timer set for \(minutes) minutes")
    }

    func setSleepTimerEndOfChapter() {
        // Implementation
        print("[AudioPlayerService] Sleep timer set for end of chapter")
    }

    func cancelSleepTimer() {
        // Implementation
        print("[AudioPlayerService] Sleep timer cancelled")
    }
}

// MARK: - Preview

#Preview("Sleep Timer") {
    SleepTimerView(audioPlayer: AudioPlayerService.shared)
}
