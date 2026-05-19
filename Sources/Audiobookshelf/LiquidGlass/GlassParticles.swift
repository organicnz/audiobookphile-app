//
//  GlassParticles.swift
//  AudiobookshelfClient
//
//  GPU-accelerated particle system for ambient glass effects
//

import SwiftUI

/// Particle system for ambient floating particles behind glass
struct GlassParticlesView: View {
    @State var particles: [Particle] = []
    @StateObject var proMotion = ProMotionManager.shared
    
    let particleCount: Int
    let colors: [Color]
    
    init(particleCount: Int = 50, colors: [Color] = [.white, .blue, .purple]) {
        self.particleCount = particleCount
        self.colors = colors
    }
    
    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                let date = timeline.date.timeIntervalSinceReferenceDate
                
                for particle in particles {
                    let phase = date * particle.speed + particle.offset
                    
                    let x = particle.startX + sin(phase) * particle.amplitude
                    let y = particle.startY + (date * particle.verticalSpeed).truncatingRemainder(dividingBy: size.height)
                    
                    let point = CGPoint(x: x, y: y)
                    let rect = CGRect(
                        x: point.x - particle.size / 2,
                        y: point.y - particle.size / 2,
                        width: particle.size,
                        height: particle.size
                    )
                    
                    // Draw particle with blur
                    context.opacity = particle.opacity
                    context.fill(
                        Circle().path(in: rect),
                        with: .color(particle.color)
                    )
                    
                    // Glow effect
                    context.opacity = particle.opacity * 0.3
                    context.fill(
                        Circle().path(in: rect.insetBy(dx: -particle.size * 0.5, dy: -particle.size * 0.5)),
                        with: .color(particle.color)
                    )
                }
            }
            .blur(radius: 2)
        }
        .onAppear {
            generateParticles()
        }
        .drawingGroup() // Metal acceleration
    }
    
    private func generateParticles() {
        #if os(iOS) && !SKIP
        let screenWidth = UIScreen.main.bounds.width
        let screenHeight = UIScreen.main.bounds.height
        #else
        let screenWidth: CGFloat = 390
        let screenHeight: CGFloat = 844
        #endif

        particles = (0..<particleCount).map { index in
            Particle(
                startX: CGFloat.random(in: 0...screenWidth),
                startY: CGFloat.random(in: 0...screenHeight),
                size: CGFloat.random(in: 2...8),
                color: colors.randomElement() ?? .white,
                opacity: Double.random(in: 0.2...0.6),
                speed: Double.random(in: 0.5...2.0),
                amplitude: CGFloat.random(in: 20...100),
                verticalSpeed: CGFloat.random(in: 10...50),
                offset: Double.random(in: 0...Double.pi * 2)
            )
        }
    }
}

// MARK: - Particle Model

struct Particle {
    let startX: CGFloat
    let startY: CGFloat
    let size: CGFloat
    let color: Color
    let opacity: Double
    let speed: Double
    let amplitude: CGFloat
    let verticalSpeed: CGFloat
    let offset: Double
}

/*
// MARK: - Preview

#Preview("Glass Particles") {
    ZStack {
        // Background gradient
        LinearGradient(
            colors: [.indigo, .purple, .pink],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
        
        // Particles
        GlassParticlesView(
            particleCount: 100,
            colors: [.white, .cyan, .blue]
        )
        
        // Foreground glass card
        VStack {
            Spacer()
            GlassCard {
                VStack(spacing: 16) {
                    Text("Glass Particles Demo")
                        .font(.title)
                        .fontWeight(.bold)
                    
                    Text("100 particles rendered at 120fps using Metal")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
            }
            .padding()
        }
    }
}
*/
