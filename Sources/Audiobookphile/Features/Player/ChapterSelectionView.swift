import SwiftUI

public struct ChapterSelectionView: View {
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

                                Text(formatDuration(chapter.end - chapter.start))
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
                    .applyBookshelfScrollTransition()
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
            .applyToolbarAdapters(isLight: false, isHidden: false)
        }
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
