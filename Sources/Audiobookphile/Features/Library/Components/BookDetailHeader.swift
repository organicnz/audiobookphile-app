//
//  BookDetailHeader.swift
//  Audiobookphile
//

import SwiftUI

public struct BookDetailHeader: View {
    public let detailed: Book
    public let appState: AppState
    // Read-only access — no property mutation, so @Bindable is not needed
    public let viewModel: BookDetailViewModel

    public init(detailed: Book, appState: AppState, viewModel: BookDetailViewModel) {
        self.detailed = detailed
        self.appState = appState
        self.viewModel = viewModel
    }

    public var body: some View {
        VStack(spacing: 24) {
            // Large Cover Art
            coverArtSection

            // Title & Authors
            VStack(spacing: 6) {
                Text(detailed.title)
                    .font(.title2)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white)

                if let author = detailed.author, !author.isEmpty, author != "Unknown Author" {
                    Text("by \(author)")
                        .font(.headline)
                        .foregroundStyle(Color.appPrimary)
                        .multilineTextAlignment(.center)
                }

                if let narrator = detailed.media.metadata.narratorName {
                    Text("Narrated by \(narrator)")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.65))
                        .multilineTextAlignment(.center)
                }
            }
        }
    }

    private var coverArtSection: some View {
        let coverURL = appState.getCoverURL(itemId: detailed.id, width: 600, updatedAt: detailed.updatedAt)
        return SmartAsyncImage(url: coverURL) { image in
            image
                .resizable()
                .aspectRatio(contentMode: .fit)
        } placeholder: {
            placeholderCover
        }
        .frame(width: 260, height: 260)
        .background {
            SmartAsyncImage(url: coverURL) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .blur(radius: 10)
                    .opacity(0.4)
            } placeholder: {
                Color.appSecondaryBackground
            }
        }
        .clipped()
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.4),
                            Color.white.opacity(0.1)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.5
                )
        )
        .shadow(color: viewModel.colorLoader.backgroundColor.opacity(0.55), radius: 24, x: 0, y: 12)
    }

    private var placeholderCover: some View {
        ZStack {
            Image("BookPlaceholder", bundle: .module)
                .resizable()
                .aspectRatio(contentMode: .fill)

            Color.black.opacity(0.15)
        }
        .frame(width: 260, height: 260)
    }
}
