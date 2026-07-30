import SwiftUI

public struct ChapterSelectionView: View {
    public let chapters: [Chapter]
    public let currentChapter: Chapter?
    public let bookTitle: String
    public let bookAuthor: String?
    public let onSelect: (Chapter) -> Void

    @Environment(\.dismiss) var dismiss
    @State private var selectedChapterForAI: Chapter?
    @State private var aiInsights: AudiobookphileAPI.ChapterAIInsights?
    @State private var isLoadingAI = false
    @State private var aiErrorMessage: String?

    private var trailingPlacement: ToolbarItemPlacement {
        #if os(iOS) || SKIP
        return .navigationBarTrailing
        #else
        return .primaryAction
        #endif
    }

    public init(
        chapters: [Chapter],
        currentChapter: Chapter?,
        bookTitle: String = "Audiobook",
        bookAuthor: String? = nil,
        onSelect: @escaping (Chapter) -> Void
    ) {
        self.chapters = chapters
        self.currentChapter = currentChapter
        self.bookTitle = bookTitle
        self.bookAuthor = bookAuthor
        self.onSelect = onSelect
    }

    public var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                List {
                    ForEach(chapters) { chapter in
                        HStack {
                            Button {
                                onSelect(chapter)
                            } label: {
                                HStack(spacing: 12) {
                                    if chapter.id == currentChapter?.id {
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(Color.appPrimary)
                                            .frame(width: 4, height: 28)
                                    }

                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(chapter.title)
                                            .font(.headline)
                                            .fontWeight(chapter.id == currentChapter?.id ? .bold : .regular)
                                            .foregroundStyle(chapter.id == currentChapter?.id ? Color.appPrimary : .primary)

                                        Text(formatDuration(chapter.end - chapter.start))
                                            .font(.caption)
                                            .fontWeight(chapter.id == currentChapter?.id ? .bold : .regular)
                                            .foregroundStyle(.secondary)
                                    }

                                    Spacer()

                                    if chapter.id == currentChapter?.id {
                                        Image(systemName: "speaker.wave.2.fill")
                                            .foregroundStyle(Color.appPrimary)
                                    }
                                }
                            }

                            // AI Insights Button
                            Button {
                                loadAIInsights(for: chapter)
                            } label: {
                                Image(systemName: "sparkles")
                                    .font(.body)
                                    .foregroundStyle(.cyan)
                                    .padding(8)
                                    .background(Color.cyan.opacity(0.15), in: Circle())
                            }
                            .buttonStyle(.plain)
                        }
                        .applyBookshelfScrollTransition()
                        .id(chapter.id)
                    }
                }
                .onAppear {
                    if let current = currentChapter {
                        withAnimation {
                            proxy.scrollTo(current.id, anchor: .center)
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
            .applyToolbarAdapters(isLight: false, isHidden: false)
            .sheet(item: $selectedChapterForAI) { chapter in
                ChapterAIInsightsSheet(
                    chapter: chapter,
                    bookTitle: bookTitle,
                    insights: aiInsights,
                    isLoading: isLoadingAI,
                    errorMessage: aiErrorMessage
                )
                .presentationDetents([.medium, .large])
            }
        }
    }

    private func loadAIInsights(for chapter: Chapter) {
        selectedChapterForAI = chapter
        aiInsights = nil
        aiErrorMessage = nil
        isLoadingAI = true

        Task {
            do {
                let res = try await AudiobookphileAPI.shared.fetchChapterAIInsights(
                    title: bookTitle,
                    author: bookAuthor,
                    chapterTitle: chapter.title,
                    chapterIndex: chapter.id
                )
                await MainActor.run {
                    self.aiInsights = res
                    self.isLoadingAI = false
                }
            } catch {
                await MainActor.run {
                    self.aiErrorMessage = error.localizedDescription
                    self.isLoadingAI = false
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

// MARK: - AI Insights Sheet
public struct ChapterAIInsightsSheet: View {
    public let chapter: Chapter
    public let bookTitle: String
    public let insights: AudiobookphileAPI.ChapterAIInsights?
    public let isLoading: Bool
    public let errorMessage: String?

    public var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(white: 0.1), Color(white: 0.05)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 20) {
                // Header
                HStack {
                    Image(systemName: "sparkles")
                        .font(.title2)
                        .foregroundStyle(.cyan)
                    Text("AI Insights")
                        .font(.title3.bold())
                        .foregroundStyle(.white)

                    Spacer()

                    if let mood = insights?.mood {
                        Text(mood)
                            .font(.caption.bold())
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Color.purple.opacity(0.3))
                            .foregroundStyle(.purple)
                            .clipShape(Capsule())
                    }
                }

                Text("Chapter \(chapter.id): \(chapter.title)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Divider().background(Color.white.opacity(0.2))

                if isLoading {
                    VStack(spacing: 12) {
                        ProgressView()
                            .tint(.cyan)
                        Text("Generating AI Insights...")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let error = errorMessage {
                    VStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.largeTitle)
                            .foregroundStyle(.yellow)
                        Text("Failed to load insights")
                            .font(.headline)
                            .foregroundStyle(.white)
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let insights = insights {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Summary")
                                    .font(.headline)
                                    .foregroundStyle(.cyan)
                                Text(insights.summary)
                                    .font(.body)
                                    .foregroundStyle(.white)
                            }
                            .glassCard()

                            if !insights.keyTakeaways.isEmpty {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Key Takeaways")
                                        .font(.headline)
                                        .foregroundStyle(.purple)

                                    ForEach(insights.keyTakeaways, id: \.self) { takeaway in
                                        HStack(alignment: .top, spacing: 8) {
                                            Image(systemName: "checkmark.circle.fill")
                                                .font(.caption)
                                                .foregroundStyle(.cyan)
                                                .padding(.top, 2)
                                            Text(takeaway)
                                                .font(.subheadline)
                                                .foregroundStyle(.white)
                                        }
                                    }
                                }
                                .glassCard()
                            }
                        }
                    }
                }
            }
            .padding(24)
        }
    }
}
