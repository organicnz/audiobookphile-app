//
//  GlassCard.swift
//  AudiobookshelfClient
//
//  Liquid Glass card component with blur effects and translucency
//

import SwiftUI

/// Liquid Glass card container with customizable blur and styling
struct GlassCard<Content: View>: View {
    let content: Content
    var padding: CGFloat = 16
    var cornerRadius: CGFloat = 20
    var material: Material = .ultraThinMaterial
    var borderOpacity: Double = 0.2
    var shadowRadius: CGFloat = 10
    var shadowY: CGFloat = 5
    
    init(
        padding: CGFloat = 16,
        cornerRadius: CGFloat = 20,
        material: Material = .ultraThinMaterial,
        borderOpacity: Double = 0.2,
        shadowRadius: CGFloat = 10,
        shadowY: CGFloat = 5,
        @ViewBuilder content: () -> Content
    ) {
        self.content = content()
        self.padding = padding
        self.cornerRadius = cornerRadius
        self.material = material
        self.borderOpacity = borderOpacity
        self.shadowRadius = shadowRadius
        self.shadowY = shadowY
    }
    
    var body: some View {
        content
            .padding(padding)
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
                    .shadow(
                        color: Color.black.opacity(0.1),
                        radius: shadowRadius,
                        y: shadowY
                    )
            }
    }
}

/// Convenience modifier to apply glass card styling
extension View {
    func glassCard(
        padding: CGFloat = 16,
        cornerRadius: CGFloat = 20,
        material: Material = .ultraThinMaterial
    ) -> some View {
        self.modifier(GlassCardModifier(
            padding: padding,
            cornerRadius: cornerRadius,
            material: material
        ))
    }
}

struct GlassCardModifier: ViewModifier {
    let padding: CGFloat
    let cornerRadius: CGFloat
    let material: Material
    
    func body(content: Content) -> some View {
        GlassCard(
            padding: padding,
            cornerRadius: cornerRadius,
            material: material
        ) {
            content
        }
    }
}

/*
// MARK: - Preview
#Preview("Glass Card Examples") {
    ZStack {
        // Background gradient
        LinearGradient(
            colors: [.blue, .purple],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
        
        VStack(spacing: 20) {
            // Basic glass card
            GlassCard {
                VStack(alignment: .leading, spacing: 8) {
                    Text("The Midnight Library")
                        .font(.headline)
                    Text("Matt Haig")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            
            // Custom glass card
            GlassCard(
                padding: 24,
                cornerRadius: 24,
                material: .thinMaterial
            ) {
                HStack {
                    Image(systemName: "book.fill")
                        .font(.largeTitle)
                    VStack(alignment: .leading) {
                        Text("Audiobook")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("8h 32m")
                            .font(.headline)
                    }
                }
            }
            
            // Using modifier
            Text("View with glass modifier")
                .glassCard()
        }
        .padding()
    }
}
*/
