//
//  SkeletonLoaders.swift
//  Audiobookphile
//

import SwiftUI

// MARK: - Book Card Skeleton Loader
public struct BookCardSkeleton: View {
    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.08))
                .aspectRatio(1.0, contentMode: .fit)

            VStack(alignment: .leading, spacing: 6) {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(Color.white.opacity(0.12))
                    .frame(height: 14)

                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(Color.white.opacity(0.08))
                    .frame(width: 80, height: 10)
            }
            .frame(height: 68, alignment: .topLeading)
        }
        .shimmer()
    }
}

// MARK: - Home Skeleton Loader
public struct HomeSkeletonView: View {
    public init() {}
    
    public var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                // Skeleton: Continue Listening
                VStack(alignment: .leading, spacing: 12) {
                    SkeletonTextBar(width: 180)
                        .padding(.horizontal)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 16) {
                            ForEach(0..<2, id: \.self) { _ in
                                VStack(alignment: .leading, spacing: 10) {
                                    HStack(spacing: 14) {
                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .fill(Color.white.opacity(0.08))
                                            .frame(width: 70, height: 70)

                                        VStack(alignment: .leading, spacing: 6) {
                                            SkeletonTextBar(width: 120)
                                            SkeletonTextBar(width: 80, height: 10)
                                            // Progress bar skeleton
                                            RoundedRectangle(cornerRadius: 3, style: .continuous)
                                                .fill(Color.white.opacity(0.06))
                                                .frame(height: 6)
                                                .frame(maxWidth: .infinity)
                                        }
                                    }
                                }
                                .padding(14)
                                .frame(width: 280)
                                .glassCard(cornerRadius: 16)
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.top, 16)

                // Skeleton: Recently Added
                VStack(alignment: .leading, spacing: 12) {
                    SkeletonTextBar(width: 150)
                        .padding(.horizontal)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 16) {
                            ForEach(0..<4, id: \.self) { _ in
                                BookCardSkeleton()
                                    .frame(width: 140)
                            }
                        }
                        .padding(.horizontal)
                    }
                }

                // Skeleton: Continue Series
                VStack(alignment: .leading, spacing: 12) {
                    SkeletonTextBar(width: 140)
                        .padding(.horizontal)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 16) {
                            ForEach(0..<3, id: \.self) { _ in
                                VStack(alignment: .leading, spacing: 8) {
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .fill(Color.white.opacity(0.06))
                                        .frame(width: 200, height: 100)
                                    SkeletonTextBar(width: 120)
                                    SkeletonTextBar(width: 80, height: 10)
                                }
                                .shimmer()
                            }
                        }
                        .padding(.horizontal)
                    }
                }

                Spacer().frame(height: 100)
            }
        }
        .transition(.opacity.animation(.easeOut(duration: 0.3)))
    }
}

/// Reusable skeleton text bar with shimmer
public struct SkeletonTextBar: View {
    public let width: CGFloat
    public let height: CGFloat
    
    public init(width: CGFloat, height: CGFloat = 14) {
        self.width = width
        self.height = height
    }
    
    public var body: some View {
        RoundedRectangle(cornerRadius: 4, style: .continuous)
            .fill(Color.white.opacity(0.10))
            .frame(width: width, height: height)
            .shimmer()
    }
}
