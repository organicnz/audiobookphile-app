import SwiftUI

public struct BookDetailSimilarBooksSection: View {
    public let viewModel: BookDetailViewModel

    public init(viewModel: BookDetailViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Similar Books")
                .font(.title3)
                .bold()
                .foregroundStyle(DesignTokens.Color.foreground)
                .frame(maxWidth: .infinity, alignment: .leading)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(viewModel.similarBooks) { similarBook in
                        NavigationLink(destination: BookDetailView(book: similarBook)) {
                            BookCard(book: similarBook) {}
                                .frame(width: 140)
                        }
                    }
                }
            }
        }
        .padding(.vertical, 8)
    }
}
