import SwiftUI

public struct CollectionsView: View {
    public init() {}
    public var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()

            VStack(spacing: 16) {
                Image(systemName: "square.grid.2x2.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(Color.appPrimary.opacity(0.8))
                
                Text("Collections")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(Color.textPrimary)

                Text("Your customized book collections will appear here.")
                    .font(.subheadline)
                    .foregroundStyle(Color.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            .padding(24)
            .glassBackground(cornerRadius: 20)
            .padding(.horizontal, 24)
        }
        .audiobookphileNavigationToolbar(title: "Collections")
    }
}
