//
//  ParallaxScrollView.swift
//  AudiobookphileClient
//
//  Multi-layer parallax scrolling with depth effects (120fps optimized)
//

import SwiftUI

/// Parallax scroll view with multiple depth layers
struct ParallaxScrollView<Background: View, Content: View, Foreground: View>: View {
    
    let background: Background
    let content: Content
    let foreground: Foreground
    
    // Scroll offset tracking
    @State private var scrollOffset: CGFloat = 0
    @ObservedObject private var proMotion = ProMotionManager.shared
    
    // Parallax factors (how fast each layer moves)
    var backgroundSpeed: CGFloat = 0.3
    var contentSpeed: CGFloat = 1.0
    var foregroundSpeed: CGFloat = 1.5
    
    init(
        backgroundSpeed: CGFloat = 0.3,
        foregroundSpeed: CGFloat = 1.5,
        @ViewBuilder background: () -> Background,
        @ViewBuilder content: () -> Content,
        @ViewBuilder foreground: () -> Foreground
    ) {
        self.backgroundSpeed = backgroundSpeed
        self.foregroundSpeed = foregroundSpeed
        self.background = background()
        self.content = content()
        self.foreground = foreground()
    }
    
    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                ZStack(alignment: .top) {
                    // Background layer (slow)
                    background
                        .offset(y: scrollOffset * backgroundSpeed)
                        .blur(radius: 2) // Depth-based blur
                    
                    // Content layer (normal speed)
                    content
                        .background(
                            GeometryReader { contentGeometry in
                                Color.clear
                                    .preference(
                                        key: ScrollOffsetPreferenceKey.self,
                                        value: contentGeometry.frame(in: .named("scroll")).minY
                                    )
                            }
                        )
                    
                    // Foreground layer (fast)
                    foreground
                        .offset(y: scrollOffset * foregroundSpeed)
                }
            }
            .coordinateSpace(name: "scroll")
            .onPreferenceChange(ScrollOffsetPreferenceKey.self) { value in
                scrollOffset = value
            }
        }
        .optimizedForProMotion()
    }
}

// MARK: - Simplified Parallax (Single Layer)

struct SimpleParallaxView<Content: View>: View {
    let content: Content
    let parallaxFactor: CGFloat
    
    @State private var scrollOffset: CGFloat = 0
    
    init(parallaxFactor: CGFloat = 0.5, @ViewBuilder content: () -> Content) {
        self.parallaxFactor = parallaxFactor
        self.content = content()
    }
    
    var body: some View {
        GeometryReader { geometry in
            content
                .offset(y: scrollOffset * parallaxFactor)
                .background(
                    GeometryReader { contentGeometry in
                        Color.clear
                            .preference(
                                key: ScrollOffsetPreferenceKey.self,
                                value: contentGeometry.frame(in: .global).minY
                            )
                    }
                )
                .onPreferenceChange(ScrollOffsetPreferenceKey.self) { value in
                    // Smooth interpolation for 120fps
                    withAnimation(proMotion.optimizedSpring(response: 0.2)) {
                        scrollOffset = value
                    }
                }
        }
    }
    
    @ObservedObject private var proMotion = ProMotionManager.shared
}



// MARK: - Parallax Modifier

struct ParallaxModifier: ViewModifier {
    let speed: CGFloat
    @State private var offset: CGFloat = 0
    
    func body(content: Content) -> some View {
        content
            .offset(y: offset)
            .background(
                GeometryReader { geometry in
                    Color.clear
                        .preference(
                            key: ScrollOffsetPreferenceKey.self,
                            value: geometry.frame(in: .global).minY
                        )
                }
            )
            .onPreferenceChange(ScrollOffsetPreferenceKey.self) { value in
                offset = value * speed
            }
    }
}

extension View {
    /// Apply parallax effect to this view
    func parallax(speed: CGFloat = 0.5) -> some View {
        self.modifier(ParallaxModifier(speed: speed))
    }
}

// MARK: - Preview

#Preview("Parallax Scroll Demo") {
    ParallaxScrollView(
        backgroundSpeed: 0.2,
        foregroundSpeed: 1.8
    ) {
        // Background layer
        LinearGradient(
            colors: [.purple, .blue],
            startPoint: .top,
            endPoint: .bottom
        )
        .frame(height: 500)
    } content: {
        // Content layer
        VStack(spacing: 20) {
            ForEach(0..<20) { index in
                GlassCard {
                    HStack {
                        Image(systemName: "book.fill")
                            .font(.title)
                        VStack(alignment: .leading) {
                            Text("Book Title \(index + 1)")
                                .font(.headline)
                            Text("Author Name")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                }
                .padding(.horizontal)
            }
        }
        .padding(.top, 300)
    } foreground: {
        // Foreground layer
        VStack {
            Text("Parallax Effect")
                .font(.system(size: 60, weight: .bold))
                .foregroundStyle(.white)
                .shadow(radius: 20)
            
            Spacer()
        }
        .padding(.top, 100)
    }
}
