//
//  PlaybackSpeedView.swift
//  AudiobookphileClient
//
//  Playback speed picker with Liquid Glass design
//

import SwiftUI

struct PlaybackSpeedView: View {
    @Binding var selectedSpeed: Float
    @Environment(\.dismiss) private var dismiss

    let speeds: [Float] = [0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0, 2.5, 3.0]

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()

                VStack(spacing: 24) {
                    // Current speed display
                    currentSpeedDisplay

                    // Speed slider
                    speedSlider

                    // Preset buttons
                    presetButtons

                    Spacer()
                }
                .padding(16)
            }
            .navigationTitle("Playback Speed")
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

    // MARK: - Current Speed Display

    private var currentSpeedDisplay: some View {
        VStack(spacing: 8) {
            Text(speedText)
                .font(.system(size: 64, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            Text(speedDescription)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    private var speedText: String {
        if selectedSpeed == 1.0 {
            return "1×"
        } else if selectedSpeed == floor(selectedSpeed) {
            return "\(Int(selectedSpeed))×"
        } else {
            return String(format: "%.2g×", selectedSpeed)
        }
    }

    private var speedDescription: String {
        if selectedSpeed < 1.0 {
            return "Slower than normal"
        } else if selectedSpeed == 1.0 {
            return "Normal speed"
        } else if selectedSpeed <= 1.5 {
            return "Slightly faster"
        } else if selectedSpeed <= 2.0 {
            return "Fast"
        } else {
            return "Very fast"
        }
    }

    // MARK: - Speed Slider

    private var speedSlider: some View {
        VStack(spacing: 12) {
            Slider(value: Binding(
                get: { Double(selectedSpeed) },
                set: { selectedSpeed = Float($0) }
            ), in: 0.5...3.0, step: 0.05)
            .tint(.cyan)
            .onChange(of: selectedSpeed) { _ in
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            }

            HStack {
                Text("0.5×")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.5))

                Spacer()

                Text("3.0×")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.5))
            }
        }
        .padding(16)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Preset Buttons

    private var presetButtons: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Presets")
                .font(.headline)
                .foregroundStyle(.white)

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                ForEach(speeds, id: \.self) { speed in
                    SpeedPresetButton(
                        speed: speed,
                        isSelected: selectedSpeed == speed
                    ) {
                        selectedSpeed = speed
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    }
                }
            }
        }
    }
}

// MARK: - Speed Preset Button

struct SpeedPresetButton: View {
    let speed: Float
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(speedText)
                .font(.title3.weight(.semibold))
                .foregroundStyle(isSelected ? .white : .white.opacity(0.7))
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

    private var speedText: String {
        if speed == 1.0 {
            return "1×"
        } else if speed == floor(speed) {
            return "\(Int(speed))×"
        } else {
            return String(format: "%.2g×", speed)
        }
    }
}

// MARK: - Inline Speed Button (for player)

struct InlineSpeedButton: View {
    @Binding var speed: Float
    @State private var showPicker = false

    var body: some View {
        Button {
            showPicker = true
        } label: {
            Text(speedText)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(.ultraThinMaterial)
                .clipShape(Capsule())
        }
        .sheet(isPresented: $showPicker) {
            PlaybackSpeedView(selectedSpeed: $speed)
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
    }

    private var speedText: String {
        if speed == 1.0 {
            return "1×"
        } else if speed == floor(speed) {
            return "\(Int(speed))×"
        } else {
            return String(format: "%.2g×", speed)
        }
    }
}

// MARK: - Preview

#Preview("Playback Speed") {
    PlaybackSpeedView(selectedSpeed: .constant(1.5))
}
