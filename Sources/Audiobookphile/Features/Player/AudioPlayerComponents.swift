import SwiftUI

// MARK: - Supporting Components

public struct GlassIconButton: View {
    public let icon: String
    public var fill: Bool = false
    public var size: ButtonSize = .medium
    public var color: Color = .white
    public var label: String?
    public let action: () -> Void

    public enum ButtonSize {
        case small, medium, large

        var iconSize: CGFloat {
            switch self {
            case .small: return 18
            case .medium: return 22
            case .large: return 28
            }
        }

        var frameSize: CGFloat {
            switch self {
            case .small: return 36
            case .medium: return 48
            case .large: return 60
            }
        }
    }

    private var defaultLabel: String {
        if icon.hasPrefix("goforward.") {
            let seconds = icon.replacingOccurrences(of: "goforward.", with: "")
            return "Seek Forward \(seconds) Seconds"
        } else if icon.hasPrefix("gobackward.") {
            let seconds = icon.replacingOccurrences(of: "gobackward.", with: "")
            return "Seek Backward \(seconds) Seconds"
        }

        switch icon {
        case "bookmark": return "Bookmarks"
        case "moon": return "Sleep Timer"
        case "list.bullet": return "Chapters"
        case "backward.end.fill": return "Previous Chapter"
        case "forward.end.fill": return "Next Chapter"
        default: return "Button"
        }
    }

    public init(icon: String, fill: Bool = false, size: ButtonSize = .medium, color: Color = .white, label: String? = nil, action: @escaping () -> Void) {
        self.icon = icon
        self.fill = fill
        self.size = size
        self.color = color
        self.label = label
        self.action = action
    }

    public var body: some View {
        Button {
            #if os(iOS) && !SKIP
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()
            #endif
            action()
        } label: {
            Image(systemName: icon)
                .font(.system(size: size.iconSize, weight: .semibold))
                .symbolVariant(fill ? .fill : .none)
                .foregroundStyle(color)
                .frame(width: size.frameSize, height: size.frameSize)
                .background {
                    Circle()
                        .fill(Color.white.opacity(0.14))
                        .shadow(color: Color.black.opacity(0.12), radius: 6, x: 0, y: 3)
                }
                .overlay {
                    Circle()
                        .strokeBorder(
                            LinearGradient(
                                colors: [.white.opacity(0.4), .white.opacity(0.08)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                }
        }
        .buttonStyle(ScaleButtonStyle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(label ?? defaultLabel))
        .accessibilityAddTraits(.isButton)
    }
}

public struct ScaleButtonStyle: ButtonStyle {
    public init() {}
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.90 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

public struct BookmarksListView: View {
    var viewModel: AudioPlayerViewModel
    @Environment(\.dismiss) var dismiss

    public var body: some View {
        NavigationStack {
            List {
                if viewModel.bookmarks.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "bookmark.slash")
                            .font(.largeTitle)
                            .foregroundStyle(.secondary)
                        Text("No bookmarks yet")
                            .font(.headline)
                        Text("Tap the bookmark icon in the player to save your favorite moments.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity, minHeight: 180)
                    .listRowBackground(Color.clear)
                } else {
                    ForEach(viewModel.bookmarks) { bookmark in
                        Button {
                            viewModel.seek(to: bookmark.timePos)
                            dismiss()
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "bookmark.fill")
                                    .foregroundStyle(Color.appPrimary)
                                    .font(.body)

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(bookmark.title ?? "Bookmark")
                                        .font(.headline)
                                        .foregroundStyle(.primary)
                                    Text(viewModel.formatTime(bookmark.timePos))
                                        .font(.caption.monospaced())
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()

                                Image(systemName: "play.circle.fill")
                                    .font(.title3)
                                    .foregroundStyle(Color.appPrimary)
                            }
                        }
                    }
                    .onDelete { indexSet in
                        for index in indexSet {
                            viewModel.deleteBookmark(viewModel.bookmarks[index])
                        }
                    }
                }
            }
            .navigationTitle("Bookmarks")
            #if os(iOS) || SKIP
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}
