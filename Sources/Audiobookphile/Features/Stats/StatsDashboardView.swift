//
//  StatsDashboardView.swift
//  Audiobookphile
//
//  Rich stats dashboard backed by the Supabase Edge API.
//  Compatible with Swift 6.3 and Skip.
//

import SwiftUI

public struct StatsDashboardView: View {
    let title: String

    @Environment(AppState.self) private var appState

    @State private var stats: LibraryStats?
    @State private var userStats: UserStatsData?
    @State private var isLoading = true
    @State private var errorMessage: String?

    public init(title: String = "Listening Stats") {
        self.title = title
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    Text(title)
                        .font(.largeTitle)
                        .bold()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)

                    if isLoading {
                        loadingView
                    } else if let error = errorMessage {
                        errorView(error)
                    } else {
                        if let userStats = userStats {
                            userStatsContent(userStats)
                        }
                        if let stats = stats {
                            dashboardContent(stats)
                        }
                    }

                    Spacer(minLength: 40)
                }
            }
            .applyBookshelfScrollTransition()
            .navigationTitle("Stats")
            #if os(iOS) || SKIP
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .applyToolbarAdapters(isLight: false, isHidden: false)
        }
        .task {
            await loadStats()
        }
    }

    // MARK: - Dashboard Content

    @ViewBuilder
    private func dashboardContent(_ stats: LibraryStats) -> some View {
        VStack(spacing: 24) {
            Text("Library Overview")
                .font(.title2)
                .bold()
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)

            // Quick Overview Bar
            HStack(spacing: 0) {
            overviewStat(label: "Books", value: "\(stats.totalBooks)", icon: "book.fill")
            Divider().frame(height: 40).background(.white.opacity(0.2))
            overviewStat(label: "Authors", value: "\(stats.totalAuthors)", icon: "person.fill")
            Divider().frame(height: 40).background(.white.opacity(0.2))
            overviewStat(label: "Series", value: "\(stats.totalSeries)", icon: "books.vertical.fill")
            Divider().frame(height: 40).background(.white.opacity(0.2))
            overviewStat(label: "Hours", value: "\(Int(stats.totalDuration / 3600))", icon: "clock.fill")
        }
        .padding(.vertical, 16)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)

        // Genres Breakdown
        if !stats.genresWithCount.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text("Genres")
                    .font(.headline)
                    .foregroundStyle(.white)

                let sorted = stats.genresWithCount.sorted { $0.count > $1.count }
                let maxCount = sorted.first?.count ?? 1
                ForEach(sorted.prefix(10)) { genre in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(genre.genre)
                                .font(.subheadline)
                                .foregroundStyle(.white.opacity(0.9))
                            Spacer()
                            Text("\(genre.count)")
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.white.opacity(0.5))
                        }

                        GeometryReader { geometry in
                            RoundedRectangle(cornerRadius: 4)
                                .fill(
                                    LinearGradient(
                                        colors: [.appPrimary, .appAccent],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(
                                    width: geometry.size.width * CGFloat(genre.count) / CGFloat(maxCount)
                                )
                        }
                        .frame(height: 8)
                    }
                }
            }
            .padding()
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .padding(.horizontal)
        }

        // Top Authors Chart
        if !stats.authorsWithCount.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text("Top Authors")
                    .font(.headline)
                    .foregroundStyle(.white)

                let sorted = stats.authorsWithCount.sorted { $0.count > $1.count }
                HStack(alignment: .bottom, spacing: 8) {
                    ForEach(sorted.prefix(7)) { author in
                        VStack(spacing: 4) {
                            Text("\(author.count)")
                                .font(.caption2.monospacedDigit())
                                .foregroundStyle(.white.opacity(0.6))
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.appPrimary)
                                .frame(height: CGFloat(author.count * 16).clamped(to: 16...120))
                            Text(abbreviateName(author.name))
                                .font(.caption2)
                                .foregroundStyle(.white.opacity(0.6))
                                .lineLimit(1)
                                .frame(maxWidth: .infinity)
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 8)
            }
            .padding()
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .padding(.horizontal)
        }

        // Longest Books
        if !stats.longestItems.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text("Longest Books")
                    .font(.headline)
                    .foregroundStyle(.white)

                let topItems = Array(stats.longestItems.prefix(5))
                ForEach(0..<topItems.count, id: \.self) { idx in
                    let item = topItems[idx]
                    let rank = String(idx + 1)
                    HStack(spacing: 12) {
                        Text(rank)
                            .font(.caption.bold())
                            .foregroundStyle(Color.appPrimary)
                            .frame(width: 24)

                        Text(item.title)
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.9))
                            .lineLimit(1)

                        Spacer()

                        Text(formatDuration(item.duration ?? 0))
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.white.opacity(0.5))
                    }
                    .padding(.vertical, 4)
                }
            }
            .padding()
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .padding(.horizontal)
        }

        // Recently Added Badge
        if stats.addedLast30Days > 0 {
            HStack {
                Image(systemName: "plus.circle.fill")
                    .foregroundStyle(.green)
                Text("\(stats.addedLast30Days) books added in the last 30 days")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.8))
                Spacer()
            }
            .padding()
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal)
        }
        }
    }

    // MARK: - Personal Stats Content

    @ViewBuilder
    private func userStatsContent(_ userStats: UserStatsData) -> some View {
        VStack(spacing: 24) {
            Text("My Listening")
                .font(.title2)
                .bold()
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)

            // Listening History
            if !userStats.recentSessions.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Recent Sessions")
                        .font(.headline)
                        .foregroundStyle(.white)

                    ForEach(userStats.recentSessions.prefix(5)) { session in
                        HStack(spacing: 12) {
                            Image(systemName: "headphones")
                                .foregroundStyle(Color.appPrimary)
                                .frame(width: 24)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(session.displayTitle ?? "Unknown Title")
                                    .font(.subheadline)
                                    .foregroundStyle(.white)
                                    .lineLimit(1)
                                Text(session.displayAuthor ?? "Unknown Author")
                                    .font(.caption)
                                    .foregroundStyle(.white.opacity(0.6))
                            }

                            Spacer()

                            VStack(alignment: .trailing, spacing: 2) {
                                Text(formatDuration(session.timeListening ?? 0))
                                    .font(.subheadline.monospacedDigit())
                                    .foregroundStyle(.white.opacity(0.9))
                                Text(session.sessionDate ?? "")
                                    .font(.caption2)
                                    .foregroundStyle(.white.opacity(0.5))
                            }
                        }
                        .padding(.vertical, 8)
                        
                        if session.id != userStats.recentSessions.prefix(5).last?.id {
                            Divider().background(.white.opacity(0.1))
                        }
                    }
                }
                .padding()
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal)
            }
            
            // Progress
            if !userStats.mediaProgress.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("In Progress")
                        .font(.headline)
                        .foregroundStyle(.white)

                    ForEach(userStats.mediaProgress.filter { !($0.isFinished ?? false) }.prefix(3)) { progress in
                        HStack(spacing: 12) {
                            Image(systemName: "book.closed")
                                .foregroundStyle(Color.appPrimary)
                                .frame(width: 24)

                            VStack(alignment: .leading, spacing: 4) {
                                Text(progress.title ?? "Unknown Title")
                                    .font(.subheadline)
                                    .foregroundStyle(.white)
                                    .lineLimit(1)
                                
                                let current = progress.progress ?? 0
                                let total = progress.duration ?? 1
                                let percent = (current / total) * 100
                                
                                ProgressView(value: current, total: total)
                                    .tint(.appPrimary)
                                
                                Text("\(Int(percent))% completed")
                                    .font(.caption2)
                                    .foregroundStyle(.white.opacity(0.5))
                            }
                        }
                        .padding(.vertical, 8)
                        
                        if progress.id != userStats.mediaProgress.filter({ !($0.isFinished ?? false) }).prefix(3).last?.id {
                            Divider().background(.white.opacity(0.1))
                        }
                    }
                }
                .padding()
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal)
            }
        }
    }

    // MARK: - Overview Stat

    private func overviewStat(label: String, value: String, icon: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(Color.appPrimary)
            Text(value)
                .font(.title3.bold())
                .foregroundStyle(.white)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.5))
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Error View

    @ViewBuilder
    private func errorView(_ message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 40))
                .foregroundStyle(.orange)
            Text(message)
                .font(.body)
                .foregroundStyle(.white.opacity(0.7))
                .multilineTextAlignment(.center)
            Button("Retry") {
                Task { await loadStats() }
            }
            .buttonStyle(.borderedProminent)
            .tint(.appPrimary)
        }
        .padding(32)
        .padding(.horizontal)
    }

    // MARK: - Loading

    @ViewBuilder
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .tint(.appPrimary)
                .scaleEffect(1.2)
            Text("Loading stats…")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.5))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }

    // MARK: - Data Loading

    private func loadStats() async {
        guard let libraryId = appState.currentLibraryId else {
            errorMessage = "No library selected"
            isLoading = false
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            async let fetchLibraryStats = AudiobookphileAPI.shared.getLibraryStats(libraryId: libraryId)
            async let fetchUserStats = AudiobookphileAPI.shared.getUserStats()
            
            let (libraryStats, userStats) = try await (fetchLibraryStats, fetchUserStats)
            self.stats = libraryStats
            self.userStats = userStats
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    // MARK: - Formatters

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let hours = Int(seconds) / 3600
        let minutes = Int(seconds) / 60 % 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }

    private func abbreviateName(_ name: String) -> String {
        let parts = name.split(separator: " ")
        guard parts.count > 1, let last = parts.last else { return name }
        return String(last)
    }
}

// MARK: - CGFloat Clamping

extension CGFloat {
    func clamped(to range: ClosedRange<CGFloat>) -> CGFloat {
        return Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}
