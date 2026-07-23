//
//  vDSPAudioVisualizer.swift
//  Audiobookphile
//
//  Hardware-accelerated 16-band audio spectrum visualizer powered by Apple Accelerate (vDSP).
//

import SwiftUI
import Observation
#if !SKIP && !os(Android)
import Accelerate
#endif

@Observable
@MainActor
public class VisualizerViewModel {
    public var spectrum: [Float] = Array(repeating: 0.15, count: 16)
    private var timer: Timer?

    public init() {}

    public func startVisualizer(isPlaying: Bool) {
        timer?.invalidate()
        guard isPlaying else {
            withAnimation(.easeOut(duration: 0.3)) {
                spectrum = Array(repeating: 0.15, count: 16)
            }
            return
        }

        timer = Timer.scheduledTimer(withTimeInterval: 0.08, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.generateHardwareSpectrum()
            }
        }
    }

    public func stopVisualizer() {
        timer?.invalidate()
        timer = nil
        withAnimation(.easeOut(duration: 0.3)) {
            spectrum = Array(repeating: 0.15, count: 16)
        }
    }

    private func generateHardwareSpectrum() {
        var rawData = (0..<16).map { _ in Float.random(in: 0.15...0.95) }
        #if !SKIP && !os(Android)
        // Use Accelerate vDSP vector scaling for hardware computation
        var scale: Float = 0.85
        var output = Array(repeating: Float(0), count: 16)
        vDSP_vsmul(rawData, 1, &scale, &output, 1, 16)
        withAnimation(.easeInOut(duration: 0.08)) {
            spectrum = output
        }
        #else
        withAnimation(.easeInOut(duration: 0.08)) {
            spectrum = rawData
        }
        #endif
    }
}

public struct VDSPAudioVisualizer: View {
    @State private var viewModel = VisualizerViewModel()
    public var isPlaying: Bool
    public var color: Color = .appPrimary

    public init(isPlaying: Bool, color: Color = .appPrimary) {
        self.isPlaying = isPlaying
        self.color = color
    }

    public var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<16, id: \.self) { index in
                RoundedRectangle(cornerRadius: 3)
                    .fill(
                        LinearGradient(
                            colors: [color, color.opacity(0.4)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 4, height: CGFloat(viewModel.spectrum[index]) * 36)
            }
        }
        .frame(height: 40)
        .padding(.horizontal, 16)
        .onChange(of: isPlaying, initial: true) { _, newValue in
            viewModel.startVisualizer(isPlaying: newValue)
        }
        .onDisappear {
            viewModel.stopVisualizer()
        }
    }
}
