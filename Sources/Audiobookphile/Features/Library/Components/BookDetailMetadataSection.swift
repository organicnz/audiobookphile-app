import SwiftUI

public struct BookDetailMetadataSection: View {
    public let detailed: Book
    public let viewModel: BookDetailViewModel

    public init(detailed: Book, viewModel: BookDetailViewModel) {
        self.detailed = detailed
        self.viewModel = viewModel
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Metadata")
                .font(.headline)
                .foregroundStyle(DesignTokens.Color.foreground)

            VStack(alignment: .leading, spacing: 10) {
                if let publisher = detailed.media.metadata.publisher, !publisher.isEmpty {
                    metadataRow(icon: "building.2", label: "Publisher", value: publisher)
                }
                if let publishedYear = detailed.media.metadata.publishedYear, !publishedYear.isEmpty {
                    metadataRow(icon: "calendar", label: "Published", value: publishedYear)
                }
                if let language = detailed.media.metadata.language, !language.isEmpty {
                    metadataRow(icon: "globe", label: "Language", value: language)
                }
                if let narrator = detailed.media.metadata.narratorName, !narrator.isEmpty {
                    metadataRow(icon: "person.wave.2", label: "Narrator", value: narrator)
                }
                if let series = detailed.media.metadata.seriesName, !series.isEmpty {
                    metadataRow(icon: "books.vertical", label: "Series", value: series)
                }
                metadataRow(icon: "clock", label: "Duration", value: viewModel.formatDuration(detailed.duration))
                if !detailed.media.metadata.genres.isEmpty {
                    metadataRow(icon: "tag", label: "Genres", value: detailed.media.metadata.genres.joined(separator: ", "))
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard()
    }

    private func metadataRow(icon: String, label: String, value: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundStyle(Color.appPrimary)
                .frame(width: 20)
            HStack(spacing: 4) {
                Text(label + ":")
                    .font(.subheadline.bold())
                    .foregroundStyle(DesignTokens.Color.foreground)
                Text(value)
                    .font(.subheadline)
                    .foregroundStyle(DesignTokens.Color.foreground.opacity(0.85))
            }
        }
    }
}
