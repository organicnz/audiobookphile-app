//
//  GlassModifiers.swift
//  AudiobookphileClient
//
//  SwiftUI view modifiers for liquid glass effects
//

import SwiftUI

// MARK: - Glass Background Modifier
struct GlassBackgroundModifier: ViewModifier {
    let material: Material
    let cornerRadius: CGFloat
    let borderOpacity: Double
    
    func body(content: Content) -> some View {
        content
            .background {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(material)
                    .overlay {
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .strokeBorder(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(borderOpacity),
                                        Color.white.opacity(borderOpacity * 0.5)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    }
            }
    }
}

extension View {
    /// Apply a glass background effect
    func glassBackground(
        material: Material = .ultraThinMaterial,
        cornerRadius: CGFloat = 16,
        borderOpacity: Double = 0.2
    ) -> some View {
        self.modifier(GlassBackgroundModifier(
            material: material,
            cornerRadius: cornerRadius,
            borderOpacity: borderOpacity
        ))
    }
}

// MARK: - Liquid Gradient Modifier
struct LiquidGradientModifier: ViewModifier {
    let colors: [Color]
    let startPoint: UnitPoint
    let endPoint: UnitPoint
    
    func body(content: Content) -> some View {
        content
            .background {
                LinearGradient(
                    colors: colors,
                    startPoint: startPoint,
                    endPoint: endPoint
                )
            }
    }
}

extension View {
    /// Apply a liquid gradient background
    func liquidGradient(
        colors: [Color],
        startPoint: UnitPoint = .topLeading,
        endPoint: UnitPoint = .bottomTrailing
    ) -> some View {
        self.modifier(LiquidGradientModifier(
            colors: colors,
            startPoint: startPoint,
            endPoint: endPoint
        ))
    }
}

// MARK: - Glass Overlay Modifier
struct GlassOverlayModifier: ViewModifier {
    let opacity: Double
    
    func body(content: Content) -> some View {
        content
            .overlay {
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .opacity(opacity)
            }
    }
}

extension View {
    /// Apply a glass overlay
    func glassOverlay(opacity: Double = 0.3) -> some View {
        self.modifier(GlassOverlayModifier(opacity: opacity))
    }
}

// MARK: - Animated Glass Effect
struct AnimatedGlassModifier: ViewModifier {
    @State var animateGradient = false
    let colors: [Color]
    
    func body(content: Content) -> some View {
        content
            .background {
                LinearGradient(
                    colors: colors,
                    startPoint: animateGradient ? .topLeading : .bottomLeading,
                    endPoint: animateGradient ? .bottomTrailing : .topTrailing
                )
                .hueRotation(.degrees(animateGradient ? 30 : 0))
            }
            .overlay {
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .opacity(0.3)
            }
            .onAppear {
                withAnimation(
                    .easeInOut(duration: 10.0)
                    .repeatForever(autoreverses: true)
                ) {
                    animateGradient.toggle()
                }
            }
    }
}

extension View {
    /// Apply an animated glass effect
    func animatedGlass(colors: [Color] = [.blue, .purple, .pink]) -> some View {
        self.modifier(AnimatedGlassModifier(colors: colors))
    }
}

// MARK: - Frosted Glass Effect
struct FrostedGlassModifier: ViewModifier {
    let blur: CGFloat
    let saturation: Double
    
    func body(content: Content) -> some View {
        content
            .blur(radius: blur)
            .saturation(saturation)
            .overlay {
                Rectangle()
                    .fill(.thinMaterial)
                    .opacity(0.5)
            }
    }
}

extension View {
    /// Apply a frosted glass effect (blurred background)
    func frostedGlass(blur: CGFloat = 20, saturation: Double = 1.8) -> some View {
        self.modifier(FrostedGlassModifier(blur: blur, saturation: saturation))
    }
}

// MARK: - Glass Shadow
extension View {
    /// Apply a glass-style shadow
    func glassShadow(
        color: Color = .black,
        opacity: Double = 0.1,
        radius: CGFloat = 10,
        x: CGFloat = 0,
        y: CGFloat = 5
    ) -> some View {
        self.shadow(
            color: color.opacity(opacity),
            radius: radius,
            x: x,
            y: y
        )
    }
}

// MARK: - Shimmer Effect for Glass
struct ShimmerModifier: ViewModifier {
    @State var phase: CGFloat = 0
    
    func body(content: Content) -> some View {
        content
            .overlay {
                GeometryReader { geometry in
                    LinearGradient(
                        colors: [
                            .clear,
                            .white.opacity(0.3),
                            .clear
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .rotationEffect(.degrees(30))
                    .offset(x: phase * geometry.size.width * 2 - geometry.size.width)
                    .onAppear {
                        withAnimation(
                            .linear(duration: 4.0)
                            .repeatForever(autoreverses: false)
                        ) {
                            phase = 1
                        }
                    }
                }
            }
            .clipped()
    }
}

extension View {
    /// Apply a shimmer effect (loading state)
    func shimmer() -> some View {
        self.modifier(ShimmerModifier())
    }
}

/*
// MARK: - Preview
#Preview("Glass Modifiers Demo") {
    ScrollView {
        VStack(spacing: 30) {
            // Glass background
            Text("Glass Background")
                .font(.headline)
                .padding()
                .glassBackground()
            
            // Liquid gradient
            Text("Liquid Gradient")
                .font(.headline)
                .foregroundStyle(.white)
                .padding()
                .liquidGradient(colors: [.blue, .purple, .pink])
                .cornerRadius(12)
            
            // Glass overlay on image
            ZStack {
                Color.orange
                VStack {
                    Image(systemName: "book.fill")
                        .font(.system(size: 60))
                    Text("Glass Overlay")
                        .font(.headline)
                }
                .foregroundStyle(.white)
            }
            .frame(height: 150)
            .glassOverlay(opacity: 0.4)
            .cornerRadius(16)
            
            // Animated glass
            Text("Animated Glass")
                .font(.headline)
                .foregroundStyle(.white)
                .padding()
                .frame(maxWidth: .infinity)
                .animatedGlass()
                .cornerRadius(16)
            
            // Glass shadow
            Text("Glass Shadow")
                .font(.headline)
                .padding()
                .background(Color.white)
                .cornerRadius(12)
                .glassShadow(color: .blue, opacity: 0.3, radius: 20)
            
            // Shimmer effect
            RoundedRectangle(cornerRadius: 12)
                .fill(.gray.opacity(0.3))
                .frame(height: 80)
                .shimmer()
        }
        .padding()
    }
    .background {
        LinearGradient(
            colors: [.indigo, .purple],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
}
*/
