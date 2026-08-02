import SwiftUI

public struct CollectionsView: View {
    public enum CollectionType: String, CaseIterable {
        case series = "Series"
        case collections = "Collections"
        case playlists = "Playlists"
    }

    @State private var selectedType: CollectionType = .collections

    public init() {}

    public var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()

            VStack(spacing: 16) {
                Image(systemName: iconForType(selectedType))
                    .font(.system(size: 48))
                    .foregroundStyle(Color.appPrimary.opacity(0.8))
                
                Text(selectedType.rawValue)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(Color.textPrimary)

                Text("Your customized \(selectedType.rawValue.lowercased()) will appear here.")
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
        #if os(iOS) || SKIP
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .principal) {
                Picker("Collection Type", selection: $selectedType) {
                    Text("Series").tag(CollectionType.series)
                    Text("Collections").tag(CollectionType.collections)
                    Text("Playlists").tag(CollectionType.playlists)
                }
                .pickerStyle(.segmented)
                .controlSize(.large)
                .tint(.appPrimary)
            }
        }
    }

    private func iconForType(_ type: CollectionType) -> String {
        switch type {
        case .series:
            return "books.vertical.fill"
        case .collections:
            return "square.stack.3d.up.fill"
        case .playlists:
            return "music.note.list"
        }
    }
}
