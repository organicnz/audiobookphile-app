//
//  LoadingView.swift
//  AudiobookshelfClient
//
//  Loading states with Liquid Glass design
//

import SwiftUI

// MARK: - Full Screen Loading

struct LoadingView: View {
    var message: String = "Loading..."
    var showMessage: Bool = true

    @State private var isAnimating = false

    var body: some View {
        ZStack {
            // Background
            Color.black.opacity(0.8)
                .ignoresSafeArea()

            VStack(spacing: 24) {
                // Glass container with spinner
                ZStack {
                    // Glass background
                    Circle()
                        .fill(.ultraThinMaterial)
                        .frame(width: 100, height: 100)

                    // Animated ring
                    Circle()
                        .trim(from: 0, to: 0.7)
                        .stroke(
                            LinearGradient(
                                colors: [.cyan, .blue, .purple],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            style: StrokeStyle(lineWidth: 4, lineCap: .round)
                        )
                        .frame(width: 60, height: 60)
                        .rotationEffect(.degrees(isAnimating ? 360 : 0))
                        .animation(.linear(duration: 1).repeatForever(autoreverses: false), value: isAnimating)
                }

                if showMessage {
                    Text(message)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.8))
                }
            }
        }
        .onAppear {
            isAnimating = true
        }
    }
}

// MARK: - Inline Loading Spinner

struct LoadingSpinner: View {
    var size: CGFloat = 40
    var lineWidth: CGFloat = 3
    var colors: [Color] = [.cyan, .blue]

    @State private var isAnimating = false

    var body: some View {
        Circle()
            .trim(from: 0, to: 0.7)
            .stroke(
                LinearGradient(
                    colors: colors,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
            )
            .frame(width: size, height: size)
            .rotationEffect(.degrees(isAnimating ? 360 : 0))
            .animation(.linear(duration: 1).repeatForever(autoreverses: false), value: isAnimating)
            .onAppear {
                isAnimating = true
            }
    }
}

// MARK: - Pulse Loading

struct PulseLoading: View {
    var size: CGFloat = 60
    var color: Color = .cyan

    @State private var isAnimating = false

    var body: some View {
        ZStack {
            Circle()
                .fill(color.opacity(0.3))
                .frame(width: size, height: size)
                .scaleEffect(isAnimating ? 2 : 1)
                .opacity(isAnimating ? 0 : 0.5)

            Circle()
                .fill(color.opacity(0.5))
                .frame(width: size * 0.6, height: size * 0.6)
                .scaleEffect(isAnimating ? 1.5 : 1)
                .opacity(isAnimating ? 0 : 0.7)

            Circle()
                .fill(color)
                .frame(width: size * 0.3, height: size * 0.3)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 1.5).repeatForever(autoreverses: false)) {
                isAnimating = true
            }
        }
    }
}

// MARK: - Skeleton Loading

struct SkeletonView: View {
    var height: CGFloat = 20
    var cornerRadius: CGFloat = 8

    @State private var isAnimating = false

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(
                LinearGradient(
                    colors: [
                        Color.white.opacity(0.1),
                        Color.white.opacity(0.2),
                        Color.white.opacity(0.1)
                    ],
                    startPoint: isAnimating ? .trailing : .leading,
                    endPoint: isAnimating ? .leading : .trailing
                )
            )
            .frame(height: height)
            .onAppear {
                withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: false)) {
                    isAnimating = true
                }
            }
    }
}

// MARK: - Book Card Skeleton

struct BookCardSkeleton: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Cover placeholder
            SkeletonView(height: 150, cornerRadius: 12)

            // Title placeholder
            SkeletonView(height: 16, cornerRadius: 4)

            // Author placeholder
            SkeletonView(height: 12, cornerRadius: 4)
                .frame(width: 80)
        }
        .frame(width: 120)
    }
}



// MARK: - Progress Loading

struct ProgressLoadingView: View {
    var progress: Double
    var message: String = "Downloading..."

    var body: some View {
        VStack(spacing: 16) {
            // Progress ring
            ZStack {
                Circle()
                    .stroke(.white.opacity(0.2), lineWidth: 4)

                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        LinearGradient(
                            colors: [.cyan, .blue],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: 4, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut, value: progress)

                Text("\(Int(progress * 100))%")
                    .font(.headline)
                    .foregroundStyle(.white)
            }
            .frame(width: 80, height: 80)

            Text(message)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.8))
        }
        .padding(24)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - Previews

#Preview("Loading View") {
    LoadingView(message: "Loading your library...")
}

#Preview("Spinners") {
    VStack(spacing: 40) {
        LoadingSpinner()
        PulseLoading()
        ProgressLoadingView(progress: 0.65)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color.black)
}

#Preview("Skeletons") {
    VStack(spacing: 20) {
        SkeletonView()
        BookCardSkeleton()
    }
    .padding()
    .background(Color.black)
}
