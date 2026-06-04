//
//  StatusBadge.swift
//  AudiobookphileClient
//
//  Status badges and indicators with Liquid Glass design
//

import SwiftUI

// MARK: - Progress Badge

struct ProgressBadge: View {
    let progress: Double
    var size: BadgeSize = .medium
    var showPercentage: Bool = true

    enum BadgeSize {
        case small, medium, large

        var dimension: CGFloat {
            switch self {
            case .small: return 32
            case .medium: return 44
            case .large: return 56
            }
        }

        var lineWidth: CGFloat {
            switch self {
            case .small: return 3
            case .medium: return 4
            case .large: return 5
            }
        }

        var fontSize: Font {
            switch self {
            case .small: return .caption2
            case .medium: return .caption
            case .large: return .subheadline
            }
        }
    }

    var body: some View {
        ZStack {
            // Background ring
            Circle()
                .stroke(.white.opacity(0.2), lineWidth: size.lineWidth)

            // Progress ring
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    progressGradient,
                    style: StrokeStyle(lineWidth: size.lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))

            // Percentage text
            if showPercentage {
                Text("\(Int(progress * 100))%")
                    .font(size.fontSize)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
            }
        }
        .frame(width: size.dimension, height: size.dimension)
    }

    private var progressGradient: LinearGradient {
        if progress >= 1.0 {
            return LinearGradient(colors: [.green, .mint], startPoint: .topLeading, endPoint: .bottomTrailing)
        } else if progress >= 0.5 {
            return LinearGradient(colors: [.cyan, .blue], startPoint: .topLeading, endPoint: .bottomTrailing)
        } else {
            return LinearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }
}

// MARK: - Download Badge

struct DownloadBadge: View {
    enum State {
        case notDownloaded
        case downloading(Double)
        case downloaded
        case error
    }

    let state: State
    var size: CGFloat = 24

    var body: some View {
        ZStack {
            switch state {
            case .notDownloaded:
                Image(systemName: "arrow.down.circle")
                    .font(.system(size: size))
                    .foregroundStyle(.white.opacity(0.6))

            case .downloading(let progress):
                ZStack {
                    Circle()
                        .stroke(.white.opacity(0.2), lineWidth: 2)

                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(Color.cyan, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                        .rotationEffect(.degrees(-90))

                    Image(systemName: "pause.fill")
                        .font(.system(size: size * 0.4))
                        .foregroundStyle(.cyan)
                }
                .frame(width: size, height: size)

            case .downloaded:
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: size))
                    .foregroundStyle(.green)

            case .error:
                Image(systemName: "exclamationmark.circle.fill")
                    .font(.system(size: size))
                    .foregroundStyle(.red)
            }
        }
    }
}

// MARK: - Status Pill

struct StatusPill: View {
    let text: String
    var icon: String? = nil
    var color: Color = .cyan
    var style: PillStyle = .filled

    enum PillStyle {
        case filled, outlined, glass
    }

    var body: some View {
        HStack(spacing: 4) {
            if let icon = icon {
                Image(systemName: icon)
                    .font(.caption2)
            }

            Text(text)
                .font(.caption2)
                .fontWeight(.medium)
        }
        .foregroundStyle(foregroundColor)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(background)
        .clipShape(Capsule())
        .overlay {
            if style == .outlined {
                Capsule()
                    .strokeBorder(color, lineWidth: 1)
            }
        }
    }

    private var foregroundColor: Color {
        switch style {
        case .filled: return .white
        case .outlined: return color
        case .glass: return .white
        }
    }

    @ViewBuilder
    private var background: some View {
        switch style {
        case .filled:
            color
        case .outlined:
            Color.clear
        case .glass:
            Color.white.opacity(0.15)
        }
    }
}

// MARK: - Sync Status Badge

struct SyncStatusBadge: View {
    let status: SyncStatus

    var body: some View {
        HStack(spacing: 6) {
            statusIcon

            Text(statusText)
                .font(.caption)
                .foregroundStyle(statusColor)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(statusColor.opacity(0.15))
        .clipShape(Capsule())
    }

    @ViewBuilder
    private var statusIcon: some View {
        switch status {
        case .idle:
            EmptyView()
        case .syncing:
            ProgressView()
                .scaleEffect(0.7)
                .tint(.cyan)
        case .success:
            Image(systemName: "checkmark.circle.fill")
                .font(.caption)
                .foregroundStyle(.green)
        case .failed:
            Image(systemName: "exclamationmark.circle.fill")
                .font(.caption)
                .foregroundStyle(.red)
        }
    }

    private var statusText: String {
        switch status {
        case .idle: return "Synced"
        case .syncing: return "Syncing..."
        case .success: return "Synced"
        case .failed: return "Sync Failed"
        }
    }

    private var statusColor: Color {
        switch status {
        case .idle: return .gray
        case .syncing: return .cyan
        case .success: return .green
        case .failed: return .red
        }
    }
}

// MARK: - Playing Indicator

struct PlayingIndicator: View {
    @State private var isAnimating = false
    var color: Color = .cyan
    var barCount: Int = 3

    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<barCount, id: \.self) { index in
                RoundedRectangle(cornerRadius: 1)
                    .fill(color)
                    .frame(width: 3)
                    .frame(height: isAnimating ? CGFloat.random(in: 8...16) : 4)
                    .animation(
                        .easeInOut(duration: 0.5)
                        .repeatForever()
                        .delay(Double(index) * 0.1),
                        value: isAnimating
                    )
            }
        }
        .frame(height: 16)
        .onAppear {
            isAnimating = true
        }
    }
}

// MARK: - New Badge

struct NewBadge: View {
    var body: some View {
        Text("NEW")
            .font(.system(size: 8, weight: .bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(
                LinearGradient(colors: [.orange, .red], startPoint: .leading, endPoint: .trailing)
            )
            .clipShape(Capsule())
    }
}

// MARK: - Previews

#Preview("Progress Badge") {
    HStack(spacing: 20) {
        ProgressBadge(progress: 0.25, size: .small)
        ProgressBadge(progress: 0.5, size: .medium)
        ProgressBadge(progress: 0.75, size: .large)
        ProgressBadge(progress: 1.0, size: .large)
    }
    .padding()
    .background(Color.black)
}

#Preview("Status Pills") {
    VStack(spacing: 12) {
        StatusPill(text: "Playing", icon: "play.fill", style: .filled)
        StatusPill(text: "Downloaded", icon: "checkmark", color: .green, style: .outlined)
        StatusPill(text: "1h 30m left", style: .glass)
    }
    .padding()
    .background(Color.black)
}

#Preview("Download Badge") {
    HStack(spacing: 20) {
        DownloadBadge(state: .notDownloaded)
        DownloadBadge(state: .downloading(0.6))
        DownloadBadge(state: .downloaded)
        DownloadBadge(state: .error)
    }
    .padding()
    .background(Color.black)
}

#Preview("Playing Indicator") {
    PlayingIndicator()
        .padding()
        .background(Color.black)
}
