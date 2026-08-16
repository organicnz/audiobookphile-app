//
//  FluidAuraBackground.swift
//  Audiobookphile
//
//  Liquid Glass background component.
//  Compatible with Swift 6.3 and Skip.
//

import SwiftUI

public struct FluidAuraBackground: View {
    public let baseColor: Color?
    @Environment(\.colorScheme) var colorScheme
    @State private var animate = false

    public init(baseColor: Color? = nil) {
        self.baseColor = baseColor
    }

    public var body: some View {
        ZStack {
            // Base background based on system theme or custom mood aura color
            (baseColor ?? (colorScheme == .dark ? DesignTokens.Color.background : DesignTokens.Color.surface))
                .ignoresSafeArea()
            
            // Glowing orbs
            GeometryReader { proxy in
                let width = proxy.size.width
                let height = proxy.size.height
                
                ZStack {
                    Circle()
                        .fill(colorScheme == .dark ? DesignTokens.Color.accent.opacity(0.6) : DesignTokens.Color.accentSecondary.opacity(0.4))
                        .frame(width: width * 0.8)
                        .blur(radius: 80)
                        .offset(x: animate ? width * 0.2 : -width * 0.2,
                                y: animate ? -height * 0.2 : height * 0.2)
                    
                    Circle()
                        .fill(colorScheme == .dark ? DesignTokens.Color.warning.opacity(0.5) : DesignTokens.Color.error.opacity(0.7))
                        .frame(width: width * 0.6)
                        .blur(radius: 60)
                        .offset(x: animate ? -width * 0.3 : width * 0.1,
                                y: animate ? height * 0.3 : -height * 0.1)
                }
                .saturation(1.3)
                .drawingGroup()
            }
            .ignoresSafeArea()
            
            // Liquid glass noise or overlay layer
            Rectangle()
                .fill(.ultraThinMaterial)
                .opacity(0.1)
                .ignoresSafeArea()
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 8.0).repeatForever(autoreverses: true)) {
                animate = true
            }
        }
    }
}
