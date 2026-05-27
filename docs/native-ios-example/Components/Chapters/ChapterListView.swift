//
//  ChapterListView.swift
//  AudiobookshelfClient
//
//  Chapter list with Liquid Glass design
//

import SwiftUI

struct ChapterListView: View {
    let chapters: [Chapter]
    let currentChapter: Chapter?
    let currentTime: TimeInterval
    let playbackRate: Float
    let onSelectChapter: (Chapter) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""

    var filteredChapters: [Chapter] {
        if searchText.isEmpty {
            return chapters
        }
        return chapters.filter { $0.title.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                Color.appBackground.ignoresSafeArea()

                VStack(spacing: 0) {
                    // Search bar
                    searchBar

                    // Chapter list
                    ScrollViewReader { proxy in
                        ScrollView(.vertical, showsIndicators: false) {
                            LazyVStack(spacing: 0) {
                                ForEach(Array(filteredChapters.enumerated()), id: \.element.id) { index, chapter in
                                    ChapterRowEnhanced(
                                        index: index + 1,
                                        chapter: chapter,
                                        isCurrentChapter: chapter.id == currentChapter?.id,
                                        currentTime: currentTime
                                    ) {
                                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                        onSelectChapter(chapter)
                                        dismiss()
                                    }

                                    if index < filteredChapters.count - 1 {
                                        Divider()
                                            .background(.white.opacity(0.1))
                                            .padding(.leading, 56)
                                    }
                                }
                            }
                            .padding(.horizontal, 16)
                        }
                        .onAppear {
                            // Scroll to current chapter
                            if let current = currentChapter {
                                withAnimation {
                                    proxy.scrollTo(current.id, anchor: .center)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Chapters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundStyle(.cyan)
                }
            }
        }
    }

    private var searchBar: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.white.opacity(0.6))

            TextField("Search chapters...", text: $searchText)
                .textFieldStyle(.plain)
                .foregroundStyle(.white)

            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.white.opacity(0.6))
                }
            }
        }
        .padding(12)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }
}

// MARK: - Chapter Row (Enhanced)

struct ChapterRowEnhanced: View {
    let index: Int
    let chapter: Chapter
    let isCurrentChapter: Bool
    let currentTime: TimeInterval
    let onTap: () -> Void

    var chapterProgress: Double {
        guard isCurrentChapter else { return 0 }
        let chapterDuration = chapter.end - chapter.start
        guard chapterDuration > 0 else { return 0 }
        let chapterCurrentTime = currentTime - chapter.start
        return max(0, min(1, chapterCurrentTime / chapterDuration))
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Chapter number
                ZStack {
                    if isCurrentChapter {
                        Circle()
                            .fill(Color.cyan.opacity(0.2))

                        Image(systemName: "speaker.wave.2.fill")
                            .font(.caption)
                            .foregroundStyle(.cyan)
                    } else {
                        Text("\(index)")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.5))
                    }
                }
                .frame(width: 32, height: 32)

                // Title and progress
                VStack(alignment: .leading, spacing: 4) {
                    Text(chapter.title)
                        .font(.subheadline)
                        .foregroundStyle(isCurrentChapter ? .cyan : .white)
                        .lineLimit(2)

                    HStack(spacing: 8) {
                        Text(TimeFormatter.timestamp(chapter.start))
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.5))

                        Text("•")
                            .foregroundStyle(.white.opacity(0.3))

                        Text(TimeFormatter.duration(chapter.end - chapter.start))
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.5))
                    }

                    // Progress bar for current chapter
                    if isCurrentChapter && chapterProgress > 0 {
                        ProgressView(value: chapterProgress)
                            .tint(.cyan)
                            .scaleEffect(x: 1, y: 0.5, anchor: .center)
                    }
                }

                Spacer()

                // Duration remaining
                if isCurrentChapter {
                    Text(TimeFormatter.remaining(chapter.end - currentTime))
                        .font(.caption)
                        .foregroundStyle(.cyan)
                }
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 8)
            .background(isCurrentChapter ? Color.cyan.opacity(0.1) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .id(chapter.id)
    }
}

// MARK: - Compact Chapter List (for player screen)

struct CompactChapterList: View {
    let chapters: [Chapter]
    let currentChapter: Chapter?
    let currentTime: TimeInterval
    let onSelectChapter: (Chapter) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack {
                Text("Chapters")
                    .font(.headline)
                    .foregroundStyle(.white)

                Spacer()

                Text("\(chapters.count) chapters")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.6))
            }
            .padding(.horizontal, 16)

            // Horizontal chapter list
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(Array(chapters.enumerated()), id: \.element.id) { index, chapter in
                        CompactChapterCard(
                            index: index + 1,
                            chapter: chapter,
                            isCurrent: chapter.id == currentChapter?.id
                        ) {
                            onSelectChapter(chapter)
                        }
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }
}

struct CompactChapterCard: View {
    let index: Int
    let chapter: Chapter
    let isCurrent: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Chapter \(index)")
                    .font(.caption2)
                    .foregroundStyle(isCurrent ? .cyan : .white.opacity(0.6))

                Text(chapter.title)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(isCurrent ? .white : .white.opacity(0.8))
                    .lineLimit(2)

                Text(TimeFormatter.shortDuration(chapter.end - chapter.start))
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.5))
            }
            .frame(width: 120, alignment: .leading)
            .padding(12)
            .background(
                isCurrent
                    ? Color.cyan.opacity(0.2)
                    : Color.white.opacity(0.1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay {
                if isCurrent {
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(Color.cyan.opacity(0.5), lineWidth: 1)
                }
            }
        }
    }
}

// MARK: - Preview

#Preview("Chapter List") {
    struct PreviewWrapper: View {
        var sampleChapters: [Chapter] {
            var items: [Chapter] = []
            for i in 1...20 {
                items.append(Chapter(
                    id: i,
                    title: "Chapter \(i): The Journey Continues",
                    start: TimeInterval((i - 1) * 600),
                    end: TimeInterval(i * 600)
                ))
            }
            return items
        }

        var body: some View {
            ChapterListView(
                chapters: sampleChapters,
                currentChapter: sampleChapters.count > 4 ? sampleChapters[4] : nil,
                currentTime: 2850,
                playbackRate: 1.0
            ) { chapter in
                print("Selected chapter: \(chapter.title)")
            }
        }
    }

    return PreviewWrapper()
}
