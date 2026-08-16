import SwiftUI

/// Glass Book Card Variant for search and list views
public struct GlassBookCard: View {
    @Environment(AppState.self) private var appState
    let book: Book
    public let onTap: () -> Void

    public init(book: Book, onTap: @escaping () -> Void) {
        self.book = book
        self.onTap = onTap
    }

    public var body: some View {
        HStack(spacing: 16) {
            // Small cover
            Color.clear
                .frame(width: 60, height: 60)
                .overlay {
                    SmartAsyncImage(url: coverURL) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        DesignTokens.Color.surface.opacity(0.1)
                    }
                }
                .clipped()
                .cornerRadius(8)

            // Info
            VStack(alignment: .leading, spacing: 6) {
                Text(book.title)
                    .font(.headline)
                    .lineLimit(2)
                    .foregroundStyle(DesignTokens.Color.foreground)

                if let author = book.author {
                    Text(author)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                if let progress = book.userMediaProgress {
                    HStack {
                        Image(systemName: "clock.fill")
                            .font(.caption2)
                        Text("\(progress.progressPercentage)% complete")
                            .font(.caption)
                    }
                    .foregroundStyle(DesignTokens.Color.accent)
                } else if book.isMissing == true {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.caption2)
                        Text("Missing Files")
                            .font(.caption)
                    }
                    .foregroundStyle(.red)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
        .glassCard()
    }

    private var coverURL: URL? {
        if let path = book.coverPath, path.hasPrefix("http") {
            return URL(string: path)
        }
        return appState.getCoverURL(itemId: book.id, updatedAt: book.updatedAt)
    }
}
