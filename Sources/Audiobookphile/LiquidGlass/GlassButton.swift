//
//  GlassButton.swift
//  AudiobookphileClient
//
//  Liquid Glass button with gradient, haptics, and animations
//

import SwiftUI

/// Liquid Glass button with gradient overlay and haptic feedback
struct GlassButton: View {
    let title: String
    let icon: String?
    let action: () -> Void

    var size: ButtonSize = .medium
    var colors: [Color] = [.appPrimary, .appAccent]
    var isLoading: Bool = false
    var isDisabled: Bool = false

    @State var isPressed = false

    var body: some View {
        Button(action: handleTap) {
            HStack(spacing: 8) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                } else if let icon = icon {
                    Image(systemName: icon)
                        .font(size.iconFont)
                }

                Text(title)
                    .font(size.textFont)
                    .fontWeight(.semibold)
            }
            .foregroundStyle(DesignTokens.Color.foreground)
            .padding(.horizontal, size.horizontalPadding)
            .padding(.vertical, size.verticalPadding)
            .frame(maxWidth: size.isFullWidth ? .infinity : nil)
            .background {
                RoundedRectangle(cornerRadius: size.cornerRadius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: isDisabled ? [.gray, .gray.opacity(0.8)] : colors,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: size.cornerRadius, style: .continuous)
                            .fill(.ultraThinMaterial)
                            .opacity(0.3)
                    }
                    .shadow(
                        color: isDisabled ? .clear : colors.first?.opacity(0.4) ?? .clear,
                        radius: isPressed ? 5 : 15,
                        y: isPressed ? 2 : 5
                    )
            }
        }
        .scaleEffect(isPressed ? 0.95 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.65), value: isPressed)
        .disabled(isDisabled || isLoading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(title))
        .accessibilityAddTraits(.isButton)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    isPressed = true
                }
                .onEnded { _ in
                    isPressed = false
                }
        )
    }

    private func handleTap() {
        // Trigger haptic feedback
        #if os(iOS) && !SKIP
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        #endif

        action()
    }
}

// MARK: - Button Size Configuration
extension GlassButton {
    enum ButtonSize {
        case small
        case medium
        case large

        var textFont: Font {
            switch self {
            case .small: return .subheadline
            case .medium: return .body
            case .large: return .title3
            }
        }

        var iconFont: Font {
            switch self {
            case .small: return .subheadline
            case .medium: return .body
            case .large: return .title3
            }
        }

        var horizontalPadding: CGFloat {
            switch self {
            case .small: return 16
            case .medium: return 20
            case .large: return 24
            }
        }

        var verticalPadding: CGFloat {
            switch self {
            case .small: return 8
            case .medium: return 12
            case .large: return 16
            }
        }

        var cornerRadius: CGFloat {
            switch self {
            case .small: return 12
            case .medium: return 16
            case .large: return 20
            }
        }

        var isFullWidth: Bool {
            self == .large
        }
    }
}

// MARK: - Convenience initializers
extension GlassButton {
    init(
        _ title: String,
        icon: String? = nil,
        size: ButtonSize = .medium,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.icon = icon
        self.size = size
        self.colors = [.appPrimary, .appAccent]
        self.action = action
    }
}

/*
 // MARK: - Preview
 #Preview("Glass Button Examples") {
     ZStack {
         LinearGradient(
             self.colors = [.appPrimary, .appAccent]
             startPoint: .topLeading,
             endPoint: .bottomTrailing
         )
         .ignoresSafeArea()
         
         VStack(spacing: 20) {
             // Small button
             GlassButton(
                 "Play",
                 icon: "play.fill",
                 size: .small,
                 action: { print("Play tapped") }
             )
             
             // Medium button (default)
             GlassButton(
                 "Add to Library",
                 icon: "plus",
                 action: { print("Add tapped") }
             )
             
             // Large button
             GlassButton(
                 "Start Listening",
                 icon: "headphones",
                 size: .large,
                 action: { print("Start tapped") }
             )
             
             // Loading state
             GlassButton(
                 "Downloading",
                 size: .medium
             ) {
                 print("Download tapped")
             }
             .disabled(true)
             
             // Disabled state
             GlassButton(
                 "Not Available",
                 icon: "xmark",
                 size: .medium
             ) {
                 print("Not available")
             }
             .disabled(true)
         }
         .padding()
     }
 }
 */
