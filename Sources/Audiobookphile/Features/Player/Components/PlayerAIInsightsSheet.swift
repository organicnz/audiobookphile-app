//
//  PlayerAIInsightsSheet.swift
//  Audiobookphile
//

import SwiftUI

public struct PlayerAIInsightsSheet: View {
    public let bookId: String
    public let bookTitle: String
    public let bookAuthor: String?
    
    @State private var insights: AudiobookphileAPI.BookAIInsights?
    @State private var isLoading = true
    @State private var errorMessage: String?
    
    @Environment(\.dismiss) var dismiss

    public init(bookId: String, bookTitle: String, bookAuthor: String?) {
        self.bookId = bookId
        self.bookTitle = bookTitle
        self.bookAuthor = bookAuthor
    }

    public var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(white: 0.08), Color(white: 0.03)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 20) {
                // Header Bar
                HStack {
                    HStack(spacing: 8) {
                        Image(systemName: "sparkles")
                            .font(.title3.bold())
                            .foregroundStyle(.cyan)
                        Text("AI Insights Engine")
                            .font(.headline)
                            .foregroundStyle(.white)
                    }

                    Spacer()

                    if let insights = insights, insights.isCached {
                        HStack(spacing: 4) {
                            Image(systemName: "externaldrive.fill")
                                .font(.caption2)
                            Text("DB Cached")
                                .font(.caption2.bold())
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.cyan.opacity(0.15))
                        .foregroundStyle(.cyan)
                        .clipShape(Capsule())
                        .overlay(
                            Capsule().strokeBorder(Color.cyan.opacity(0.4), lineWidth: 1)
                        )
                    }

                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(bookTitle)
                        .font(.title3.bold())
                        .foregroundStyle(.white)
                    
                    if let author = bookAuthor, !author.isEmpty {
                        Text("by \(author)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Divider().background(Color.white.opacity(0.15))

                if isLoading {
                    VStack(spacing: 16) {
                        ProgressView()
                            .tint(.cyan)
                            .scaleEffect(1.2)
                        Text("Compiling AI Book Insights...")
                            .font(.subheadline)
                            .foregroundStyle(.white)
                        Text("Querying database & generating context summary")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let error = errorMessage {
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.largeTitle)
                            .foregroundStyle(.yellow)
                        Text("Insights Generation Failed")
                            .font(.headline)
                            .foregroundStyle(.white)
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)

                        Button("Retry AI Engine") {
                            loadInsights()
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.cyan)
                        .padding(.top, 8)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let insights = insights {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 18) {
                            // Mood & Themes Badges
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    HStack(spacing: 6) {
                                        Image(systemName: "face.smiling.fill")
                                        Text(insights.mood)
                                    }
                                    .font(.caption.bold())
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Color.purple.opacity(0.2))
                                    .foregroundStyle(.purple)
                                    .clipShape(Capsule())
                                    .overlay(Capsule().strokeBorder(Color.purple.opacity(0.4), lineWidth: 1))

                                    ForEach(insights.themes, id: \.self) { theme in
                                        Text(theme)
                                            .font(.caption.bold())
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 6)
                                            .background(Color.cyan.opacity(0.15))
                                            .foregroundStyle(.cyan)
                                            .clipShape(Capsule())
                                            .overlay(Capsule().strokeBorder(Color.cyan.opacity(0.3), lineWidth: 1))
                                    }
                                }
                            }

                            // Executive Summary Card
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Image(systemName: "text.quote")
                                        .foregroundStyle(.cyan)
                                    Text("Executive Summary")
                                        .font(.headline)
                                        .foregroundStyle(.cyan)
                                }
                                Text(insights.summary)
                                    .font(.body)
                                    .foregroundStyle(.white)
                                    .lineSpacing(4)
                            }
                            .glassCard()

                            // Key Lessons & Takeaways Card
                            if !insights.keyTakeaways.isEmpty {
                                VStack(alignment: .leading, spacing: 12) {
                                    HStack {
                                        Image(systemName: "lightbulb.fill")
                                            .foregroundStyle(.yellow)
                                        Text("Key Lessons & Takeaways")
                                            .font(.headline)
                                            .foregroundStyle(.yellow)
                                    }

                                    ForEach(insights.keyTakeaways, id: \.self) { takeaway in
                                        HStack(alignment: .top, spacing: 10) {
                                            Image(systemName: "checkmark.seal.fill")
                                                .font(.subheadline)
                                                .foregroundStyle(.cyan)
                                                .padding(.top, 2)
                                            Text(takeaway)
                                                .font(.subheadline)
                                                .foregroundStyle(.white)
                                                .lineSpacing(2)
                                        }
                                    }
                                }
                                .glassCard()
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .padding(20)
        }
        .onAppear {
            loadInsights()
        }
    }

    private func loadInsights() {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                let res = try await AudiobookphileAPI.shared.fetchBookAIInsights(
                    bookId: bookId,
                    title: bookTitle,
                    author: bookAuthor
                )
                await MainActor.run {
                    self.insights = res
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                }
            }
        }
    }
}
