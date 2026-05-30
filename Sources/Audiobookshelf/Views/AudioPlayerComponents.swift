import SwiftUI

// MARK: - Supporting Components

public struct GlassIconButton: View {
    public let icon: String
    public var fill: Bool = false
    public var size: ButtonSize = .medium
    public var color: Color = .white
    public var label: String? = nil
    public let action: () -> Void

    public enum ButtonSize {
        case small, medium, large

        var iconSize: CGFloat {
            switch self {
            case .small: return 20
            case .medium: return 24
            case .large: return 32
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
                .font(.system(size: size.iconSize))
                .symbolVariant(fill ? .fill : .none)
                .foregroundStyle(color)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(label ?? defaultLabel))
        .accessibilityAddTraits(.isButton)
    }
}

public struct ChapterListView: View {
    public let chapters: [Chapter]
    public let currentChapter: Chapter?
    public let onSelect: (Chapter) -> Void

    @Environment(\.dismiss) var dismiss

    private var trailingPlacement: ToolbarItemPlacement {
        #if os(iOS) || SKIP
        return .navigationBarTrailing
        #else
        return .primaryAction
        #endif
    }

    public init(chapters: [Chapter], currentChapter: Chapter?, onSelect: @escaping (Chapter) -> Void) {
        self.chapters = chapters
        self.currentChapter = currentChapter
        self.onSelect = onSelect
    }

    public var body: some View {
        NavigationStack {
            List {
                ForEach(chapters) { chapter in
                    Button {
                        onSelect(chapter)
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(chapter.title)
                                    .font(.headline)

                                Text(formatDuration(chapter.duration))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            if chapter.id == currentChapter?.id {
                                Image(systemName: "speaker.wave.2.fill")
                                    .foregroundStyle(Color.appPrimary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Chapters")
            #if os(iOS) || SKIP
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: trailingPlacement) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
