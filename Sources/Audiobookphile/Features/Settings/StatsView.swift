//
//  StatsView.swift
//  Audiobookphile
//
//  Library statistics backed by the Supabase Edge API.
//  Compatible with Swift 6.3 and Skip.
//

import SwiftUI

public struct StatsView: View {
    @Environment(AppState.self) private var appState

    @State private var stats: LibraryStats?
    @State private var isLoading = true
    @State private var errorMessage: String?

    public init() {}

    public var body: some View {
        ZStack {
            FluidAuraBackground()

            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 8) {
                        Image(systemName: "chart.bar.xaxis.ascending")
                            .font(.system(size: 48))
                            .foregroundStyle(Color.appPrimary)
                            .padding(.bottom, 8)

                        Text("Listening Stats")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundStyle(.primary)
                    }
                    .padding(.top, 32)
                    .padding(.bottom, 16)

                    if isLoading {
                        statsLoadingSkeleton
                    } else if let error = errorMessage {
                        errorView(error)
                    } else if let stats = stats {
                        statsContent(stats)
                    }

                    Spacer(minLength: 50)
                }
                .padding(.horizontal, 16)
            }
        }
        .navigationTitle("Stats")
        #if os(iOS) || SKIP
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .task {
            await loadStats()
        }
    }

    // MARK: - Live Stats Content

    @ViewBuilder
    private func statsContent(_ stats: LibraryStats) -> some View {
        // Main Stat — Total Duration
        VStack(spacing: 8) {
            Text("Total Listening Time")
                .font(.headline)
                .foregroundStyle(.secondary)

            Text(formatDuration(stats.totalDuration))
                .font(.system(size: 36, weight: .bold, design: .monospaced))
                .foregroundStyle(.primary)
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: DesignTokens.Color.surface.opacity(0.2), radius: 10, y: 5)

        // Stats Grid — Row 1
        HStack(spacing: 16) {
            statCard(
                title: "Total Books",
                value: "\(stats.totalBooks)",
                icon: "book.closed.fill",
                color: .appPrimary
            )
            statCard(
                title: "Audio Tracks",
                value: "\(stats.numAudioTracks)",
                icon: "waveform",
                color: DesignTokens.Color.accentSecondary
            )
        }

        // Stats Grid — Row 2
        HStack(spacing: 16) {
            statCard(
                title: "Authors",
                value: "\(stats.totalAuthors)",
                icon: "person.2.fill",
                color: DesignTokens.Color.accentHighlight
            )
            statCard(
                title: "Series",
                value: "\(stats.totalSeries)",
                icon: "books.vertical.fill",
                color: DesignTokens.Color.accent
            )
        }

        // Stats Grid — Row 3
        HStack(spacing: 16) {
            statCard(
                title: "Added Last 30 Days",
                value: "\(stats.addedLast30Days)",
                icon: "plus.circle.fill",
                color: DesignTokens.Color.success
            )
            statCard(
                title: "Library Size",
                value: formatBytes(stats.totalSize),
                icon: "externaldrive.fill",
                color: DesignTokens.Color.warning
            )
        }

        // Top Genres
        if !stats.genresWithCount.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text("Top Genres")
                    .font(.headline)
                    .foregroundStyle(.primary)

                let sorted = stats.genresWithCount.sorted { $0.count > $1.count }.prefix(8)
                ForEach(Array(sorted)) { genre in
                    HStack {
                        Text(genre.genre)
                            .foregroundStyle(.primary.opacity(0.8))
                        Spacer()
                        Text("\(genre.count)")
                            .foregroundStyle(.secondary)
                            .font(.subheadline.monospacedDigit())
                    }
                    .padding(.vertical, 2)
                }
            }
            .padding(16)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }

        // Top Authors
        if !stats.authorsWithCount.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text("Top Authors")
                    .font(.headline)
                    .foregroundStyle(.primary)

                let sorted = stats.authorsWithCount.sorted { $0.count > $1.count }.prefix(8)
                ForEach(Array(sorted)) { author in
                    HStack {
                        Text(author.name)
                            .foregroundStyle(.primary.opacity(0.8))
                        Spacer()
                        Text("\(author.count) books")
                            .foregroundStyle(.secondary)
                            .font(.subheadline)
                    }
                    .padding(.vertical, 2)
                }
            }
            .padding(16)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }

        // Longest Items
        if !stats.longestItems.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text("Longest Books")
                    .font(.headline)
                    .foregroundStyle(.primary)

                ForEach(stats.longestItems.prefix(5)) { item in
                    HStack {
                        Text(item.title)
                            .foregroundStyle(.primary.opacity(0.8))
                            .lineLimit(1)
                        Spacer()
                        Text(formatDuration(item.duration ?? 0))
                            .foregroundStyle(.secondary)
                            .font(.subheadline.monospacedDigit())
                    }
                    .padding(.vertical, 2)
                }
            }
            .padding(16)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }

    // MARK: - Error View

    @ViewBuilder
    private func errorView(_ message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 40))
                .foregroundStyle(DesignTokens.Color.error)

            Text(message)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button("Retry") {
                Task { await loadStats() }
            }
            .buttonStyle(.borderedProminent)
            .tint(.appPrimary)
        }
        .padding(32)
    }

    // MARK: - Loading Skeleton

    @ViewBuilder
    private var statsLoadingSkeleton: some View {
        VStack(spacing: 16) {
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.primary.opacity(0.05))
                .frame(height: 100)
                .overlay {
                    ProgressView()
                        .tint(.appPrimary)
                }

            HStack(spacing: 16) {
                skeletonCard
                skeletonCard
            }

            HStack(spacing: 16) {
                skeletonCard
                skeletonCard
            }
        }
    }

    private var skeletonCard: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(Color.primary.opacity(0.05))
            .frame(height: 100)
    }

    // MARK: - Helpers

    private func statCard(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)
                .frame(width: 44, height: 44)
                .background(color.opacity(0.2))
                .clipShape(Circle())

            Text(value)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundStyle(.primary)

            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(16)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func loadStats() async {
        guard let libraryId = appState.currentLibraryId else {
            errorMessage = "No library selected"
            isLoading = false
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            stats = try await AudiobookphileAPI.shared.getLibraryStats(libraryId: libraryId)
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let hours = Int(seconds) / 3600
        let minutes = Int(seconds) / 60 % 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }

    private func formatBytes(_ bytes: Int64) -> String {
        let gb = Double(bytes) / (1024 * 1024 * 1024)
        if gb >= 1 {
            return String(format: "%.1f GB", gb)
        }
        let mb = Double(bytes) / (1024 * 1024)
        return String(format: "%.0f MB", mb)
    }
}
