import SwiftUI

public struct BookDetailStatsRow: View {
    public let detailed: Book
    public let viewModel: BookDetailViewModel

    public init(detailed: Book, viewModel: BookDetailViewModel) {
        self.detailed = detailed
        self.viewModel = viewModel
    }

    public var body: some View {
        HStack(spacing: 12) {
            statBadge(icon: "clock", value: viewModel.formatDuration(detailed.duration), label: "Duration")
            if let year = detailed.media.metadata.publishedYear {
                statBadge(icon: "calendar", value: year, label: "Published")
            }
            statBadge(icon: "list.bullet", value: "\(detailed.chapters.count)", label: "Chapters")
        }
    }

    private func statBadge(icon: String, value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundStyle(Color.appPrimary)
            Text(value)
                .font(.subheadline)
                .fontWeight(.bold)
                .foregroundStyle(.white)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .glassCard()
    }
}
