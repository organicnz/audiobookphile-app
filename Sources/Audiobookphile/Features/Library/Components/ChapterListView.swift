//
//  ChapterListView.swift
//  Audiobookphile
//

import SwiftUI

public struct ChapterListView: View {
    public let detailed: Book
    public let viewModel: BookDetailViewModel
    @Environment(\.dismiss) var dismiss

    @State private var selectedChapterForAI: Chapter?
    @State private var aiInsights: AudiobookphileAPI.ChapterAIInsights?
    @State private var isLoadingAI = false
    @State private var aiErrorMessage: String?

    public init(detailed: Book, viewModel: BookDetailViewModel) {
        self.detailed = detailed
        self.viewModel = viewModel
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Chapters (\(detailed.chapters.count))")
                .font(.headline)
                .foregroundStyle(.white)
                .padding(.horizontal, 4)

            VStack(spacing: 8) {
                ForEach(detailed.chapters) { chapter in
                    HStack(spacing: 8) {
                        Button {
                            viewModel.playBook(detailed, seekToTime: chapter.start, dismiss: dismiss)
                        } label: {
                            HStack {
                                Text(chapter.title)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundStyle(.white)
                                    .multilineTextAlignment(.leading)

                                Spacer()

                                Text(viewModel.formatDuration(chapter.duration))
                                    .font(.caption.monospaced())
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 12)
                            .padding(.horizontal, 14)
                            .background(.ultraThinMaterial)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .strokeBorder(.white.opacity(0.15), lineWidth: 1)
                            )
                        }
                        .liquidPressable()

                        // AI Insights Button
                        Button {
                            loadAIInsights(for: chapter)
                        } label: {
                            Image(systemName: "sparkles")
                                .font(.body)
                                .foregroundStyle(.cyan)
                                .padding(10)
                                .background(.ultraThinMaterial)
                                .clipShape(Circle())
                                .overlay(
                                    Circle().strokeBorder(Color.cyan.opacity(0.4), lineWidth: 1)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .sheet(item: $selectedChapterForAI) { chapter in
            ChapterAIInsightsSheet(
                chapter: chapter,
                bookTitle: detailed.title,
                insights: aiInsights,
                isLoading: isLoadingAI,
                errorMessage: aiErrorMessage
            )
            .presentationDetents([.medium, .large])
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
                    title: detailed.title,
                    author: detailed.author,
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
}
