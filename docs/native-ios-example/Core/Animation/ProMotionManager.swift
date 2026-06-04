//
//  ProMotionManager.swift
//  AudiobookphileClient
//
//  ProMotion 120Hz display management and optimization
//

import SwiftUI
import UIKit

/// Manages ProMotion (120Hz) display features and adaptive frame rates
@MainActor
class ProMotionManager: ObservableObject {
    
    // MARK: - Published Properties
    @Published private(set) var isProMotionAvailable: Bool = false
    @Published private(set) var currentFrameRate: Int = 60
    @Published private(set) var isHighPerformanceMode: Bool = false
    
    // MARK: - Private Properties
    private var displayLink: CADisplayLink?
    private var frameRateRange: CAFrameRateRange = .default
    private var lastUpdateTime: CFTimeInterval = 0
    
    // MARK: - Singleton
    static let shared = ProMotionManager()
    
    private init() {
        detectProMotionCapability()
    }
    
    // MARK: - ProMotion Detection
    private func detectProMotionCapability() {
        // Check if device supports ProMotion (120Hz)
        if #available(iOS 15.0, *) {
            let maxFrameRate = UIScreen.main.maximumFramesPerSecond
            isProMotionAvailable = maxFrameRate >= 120
            currentFrameRate = maxFrameRate
            
            print("📱 Display: \(maxFrameRate)Hz \(isProMotionAvailable ? "(ProMotion)" : "")")
        }
    }
    
    // MARK: - Frame Rate Management
    
    /// Enable high performance mode (120Hz)
    func enableHighPerformanceMode() {
        guard isProMotionAvailable else { return }
        
        isHighPerformanceMode = true
        frameRateRange = CAFrameRateRange(
            minimum: 80,
            maximum: 120,
            preferred: 120
        )
        
        updateDisplayLink()
        print("⚡ ProMotion: High performance mode enabled (120Hz)")
    }
    
    /// Enable balanced mode (adaptive 60-120Hz)
    func enableBalancedMode() {
        guard isProMotionAvailable else { return }
        
        isHighPerformanceMode = false
        frameRateRange = CAFrameRateRange(
            minimum: 60,
            maximum: 120,
            preferred: 80
        )
        
        updateDisplayLink()
        print("⚖️ ProMotion: Balanced mode enabled (adaptive)")
    }
    
    /// Enable power-saving mode (60Hz)
    func enablePowerSavingMode() {
        isHighPerformanceMode = false
        frameRateRange = .default // 60Hz
        
        updateDisplayLink()
        print("🔋 ProMotion: Power saving mode enabled (60Hz)")
    }
    
    // MARK: - Display Link
    
    /// Start high-frequency display updates
    func startDisplayLink(callback: @escaping () -> Void) {
        stopDisplayLink()
        
        displayLink = CADisplayLink(
            target: DisplayLinkTarget(callback: callback),
            selector: #selector(DisplayLinkTarget.update)
        )
        
        if #available(iOS 15.0, *), isProMotionAvailable {
            displayLink?.preferredFrameRateRange = frameRateRange
        }
        
        displayLink?.add(to: .main, forMode: .common)
        print("▶️ Display link started")
    }
    
    /// Stop display updates
    func stopDisplayLink() {
        displayLink?.invalidate()
        displayLink = nil
        print("⏸️ Display link stopped")
    }
    
    private func updateDisplayLink() {
        if #available(iOS 15.0, *), let link = displayLink {
            link.preferredFrameRateRange = frameRateRange
        }
    }
    
    // MARK: - Utilities
    
    /// Get optimal spring animation for current frame rate
    func optimizedSpring(
        response: Double = 0.3,
        dampingFraction: Double = 0.8
    ) -> Animation {
        // Adjust response based on frame rate for consistent feel
        let adjustedResponse = isProMotionAvailable ? response * 0.8 : response
        return .spring(response: adjustedResponse, dampingFraction: dampingFraction)
    }
    
    /// Get optimal animation duration for current frame rate
    func optimizedDuration(_ baseDuration: Double) -> Double {
        // Slightly reduce duration on 120Hz for snappier feel
        return isProMotionAvailable ? baseDuration * 0.9 : baseDuration
    }
    
    /// Calculate current FPS
    func calculateFPS(timestamp: CFTimeInterval) -> Int {
        defer { lastUpdateTime = timestamp }
        
        guard lastUpdateTime > 0 else { return currentFrameRate }
        
        let deltaTime = timestamp - lastUpdateTime
        guard deltaTime > 0 else { return currentFrameRate }
        
        return Int(1.0 / deltaTime)
    }
}

// MARK: - Display Link Target
private class DisplayLinkTarget {
    private let callback: () -> Void
    
    init(callback: @escaping () -> Void) {
        self.callback = callback
    }
    
    @objc func update() {
        callback()
    }
}

// MARK: - SwiftUI Integration

/// Environment key for ProMotion manager
struct ProMotionManagerKey: EnvironmentKey {
    static let defaultValue: ProMotionManager = MainActor.assumeIsolated { .shared }
}

extension EnvironmentValues {
    var proMotion: ProMotionManager {
        get { self[ProMotionManagerKey.self] }
        set { self[ProMotionManagerKey.self] = newValue }
    }
}

// MARK: - View Modifiers

extension View {
    /// Optimize view for ProMotion display
    func optimizedForProMotion() -> some View {
        self.modifier(ProMotionOptimizedModifier())
    }
}

struct ProMotionOptimizedModifier: ViewModifier {
    @ObservedObject private var proMotion = ProMotionManager.shared
    
    func body(content: Content) -> some View {
        content
            .drawingGroup() // Use Metal for rendering
            .environment(\.proMotion, proMotion)
            .onAppear {
                if proMotion.isProMotionAvailable {
                    proMotion.enableBalancedMode()
                }
            }
    }
}

// MARK: - Performance Monitoring View

struct FPSMonitorView: View {
    @ObservedObject private var proMotion = ProMotionManager.shared
    @State private var currentFPS: Int = 60
    
    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(fpsColor)
                .frame(width: 8, height: 8)
            
            Text("\(currentFPS) fps")
                .font(.system(.caption, design: .monospaced))
                .fontWeight(.medium)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background {
            Capsule()
                .fill(.ultraThinMaterial)
        }
        .onAppear {
            proMotion.startDisplayLink { [weak proMotion] in
                guard let proMotion = proMotion else { return }
                let timestamp = CACurrentMediaTime()
                currentFPS = proMotion.calculateFPS(timestamp: timestamp)
            }
        }
        .onDisappear {
            proMotion.stopDisplayLink()
        }
    }
    
    private var fpsColor: Color {
        switch currentFPS {
        case 100...: return .green
        case 80..<100: return .yellow
        case 60..<80: return .orange
        default: return .red
        }
    }
}

// MARK: - Preview
#Preview("ProMotion Manager Demo") {
    VStack(spacing: 30) {
        FPSMonitorView()
        
        VStack(alignment: .leading, spacing: 12) {
            Text("ProMotion Info")
                .font(.headline)
            
            ProMotionInfoRow(
                title: "Available",
                value: ProMotionManager.shared.isProMotionAvailable ? "Yes" : "No"
            )
            
            ProMotionInfoRow(
                title: "Max Frame Rate",
                value: "\(ProMotionManager.shared.currentFrameRate)Hz"
            )
            
            ProMotionInfoRow(
                title: "High Performance",
                value: ProMotionManager.shared.isHighPerformanceMode ? "Enabled" : "Disabled"
            )
        }
        .glassCard()
        
        VStack(spacing: 16) {
            Button("Enable 120Hz") {
                ProMotionManager.shared.enableHighPerformanceMode()
            }
            
            Button("Balanced Mode") {
                ProMotionManager.shared.enableBalancedMode()
            }
            
            Button("Power Saving") {
                ProMotionManager.shared.enablePowerSavingMode()
            }
        }
    }
    .padding()
    .background {
        LinearGradient(
            colors: [.blue, .purple],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
}

struct ProMotionInfoRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
        }
        .font(.subheadline)
    }
}
