//
//  BookCoverView.swift
//  AudiobookphileClient
//
//  Reusable book cover component with caching and glass effects
//

import SwiftUI

struct BookCoverView: View {
    let url: URL?
    var size: CGSize = .zero // .zero means adaptive/fill
    var cornerRadius: CGFloat = 8
    var shadowRadius: CGFloat = 0
    var showPlaceholder: Bool = true

    var body: some View {
        if let url = url {
            AsyncImage(url: url) { phase in
                switch phase {
                case .empty:
                    if showPlaceholder {
                        placeholder
                    } else {
                        Color.clear
                    }

                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)

                case .failure:
                    if showPlaceholder {
                        errorPlaceholder
                    } else {
                        Color.gray.opacity(0.3)
                    }

                @unknown default:
                    EmptyView()
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .shadow(color: .black.opacity(0.3), radius: shadowRadius, y: shadowRadius > 0 ? 4 : 0)
        } else {
            if showPlaceholder {
                placeholder
            } else {
                Color.gray.opacity(0.3)
                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            }
        }
    }

    private var placeholder: some View {
        ZStack {
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [.gray.opacity(0.3), .gray.opacity(0.2)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Image(systemName: "book.closed.fill")
                .foregroundStyle(.white.opacity(0.2))
                .font(.system(size: 24))
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
    }

    private var errorPlaceholder: some View {
        ZStack {
            Rectangle()
                .fill(Color.gray.opacity(0.3))

            Image(systemName: "exclamationmark.triangle")
                .foregroundStyle(.white.opacity(0.3))
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
    }
}

// MARK: - Glass Cover Modifier

extension BookCoverView {
    func glassStyle() -> some View {
        self
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .strokeBorder(
                        LinearGradient(
                            colors: [.white.opacity(0.3), .clear],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            }
    }

    func withReflection() -> some View {
        VStack(spacing: 0) {
            self

            // Reflection
            self
                .scaleEffect(y: -1)
                .mask(
                    LinearGradient(
                        colors: [.clear, .white.opacity(0.2)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(height: 40)
                .offset(y: -4)
        }
    }
}

#Preview {
    HStack(spacing: 20) {
        BookCoverView(url: nil, size: CGSize(width: 100, height: 160))
            .frame(width: 100, height: 160)

        BookCoverView(url: nil, size: CGSize(width: 100, height: 160))
            .glassStyle()
            .frame(width: 100, height: 160)
    }
    .padding()
    .background(Color.black)
}
