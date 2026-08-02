import SwiftUI

public struct BookDetailDescriptionSection: View {
    public let text: String
    @Bindable public var viewModel: BookDetailViewModel

    public init(text: String, viewModel: BookDetailViewModel) {
        self.text = text
        self.viewModel = viewModel
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Synopsis")
                .font(.headline)
                .foregroundStyle(.white)

            Text(cleanHTML(text))
                .font(.body)
                .foregroundStyle(.white.opacity(0.8))
                .lineLimit(viewModel.isDescriptionExpanded ? nil : 4)
                .animation(.easeInOut, value: viewModel.isDescriptionExpanded)

            Button {
                viewModel.isDescriptionExpanded.toggle()
            } label: {
                Text(viewModel.isDescriptionExpanded ? "Show Less" : "Read More")
                    .font(.subheadline.bold())
                    .foregroundStyle(Color.appPrimary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard()
    }

    private func cleanHTML(_ html: String) -> String {
        // Strip basic HTML tag patterns for cleaner text display
        html.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
    }
}
