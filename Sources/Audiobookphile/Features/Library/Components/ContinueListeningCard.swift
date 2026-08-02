//
//  ContinueListeningCard.swift
//  Audiobookphile
//

import SwiftUI

public struct ContinueListeningCard: View {
    public let book: Book
    public let onTap: () -> Void

    public init(book: Book, onTap: @escaping () -> Void) {
        self.book = book
        self.onTap = onTap
    }

    public var body: some View {
        Button(action: {
            onTap()
        }) {
            VStack(alignment: .leading, spacing: 8) {
                // Cover image
                Color.clear
                    .frame(width: 120, height: 120)
                    .overlay {
                        if let url = coverURL {
                            ZStack {
                                // Blurred background
                                SmartAsyncImage(url: url) { image in
                                    image
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                } placeholder: {
                                    fallbackCover
                                }
                                .blur(radius: 15)
                                .overlay(Color.black.opacity(0.4))

                                // Fit image
                                SmartAsyncImage(url: url) { image in
                                    image
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                } placeholder: {
                                    Color.clear
                                }
                            }
                        } else {
                            fallbackCover
                        }
                    }
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(
                                LinearGradient(
                                    colors: [.white.opacity(0.35), .white.opacity(0.05)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
                    .shadow(color: Color.cyan.opacity(0.3), radius: 10, x: 0, y: 6)

                // Title & Progress with strict height
                VStack(alignment: .leading, spacing: 4) {
                    Text(book.title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .lineLimit(2)
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.leading)

                    if let progress = book.userMediaProgress {
                        HStack {
                            Text("\(Int(progress.progress * 100))%")
                                .font(.caption.bold())
                                .foregroundStyle(.cyan)

                            Spacer()

                            Image(systemName: "play.circle.fill")
                                .font(.body)
                                .foregroundStyle(.cyan)
                                .shadow(color: .cyan.opacity(0.6), radius: 4)
                        }
                    } else {
                        Spacer(minLength: 0)
                            .frame(height: 16)
                    }
                }
                .frame(height: 56, alignment: .topLeading)
            }
            .frame(width: 120)
            .contentShape(Rectangle())
        }
        .buttonStyle(.liquid)
    }

    private var fallbackCover: some View {
        ZStack {
            Color(white: 0.2)

            VStack(spacing: 6) {
                Image(systemName: "book.closed.fill")
                    .font(.headline)
                    .foregroundStyle(.white.opacity(0.3))

                Text(book.title)
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundStyle(.white.opacity(0.4))
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 6)
            }
        }
        .frame(width: 120, height: 120)
    }

    private var coverURL: URL? {
        if let path = book.coverPath, path.hasPrefix("http") {
            return URL(string: path)
        }
        return AppState.shared.getCoverURL(itemId: book.id, updatedAt: book.updatedAt)
    }
}
