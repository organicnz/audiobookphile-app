import SwiftUI
import Observation

public struct BookshelfSearchOverlay: View {
    @Binding var searchText: String
    @Binding var showSearch: Bool
    @Bindable var viewModel: BookshelfViewModel
    @Binding var selectedBookForDetails: Book?

    public var body: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)

                TextField("Search books...", text: $searchText)
                    .textFieldStyle(.plain)
                    .foregroundStyle(.white)

                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .glassCard()
            .padding()

            if !searchText.isEmpty {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(viewModel.searchResults(for: searchText)) { book in
                            GlassBookCard(book: book) {
                                selectedBookForDetails = book
                                showSearch = false
                            }
                        }
                    }
                    .padding()
                }
            }

            Spacer()
        }
        .glassCard(cornerRadius: 16)
    }
}
