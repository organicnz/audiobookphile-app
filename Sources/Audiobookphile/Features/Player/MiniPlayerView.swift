import SwiftUI
import Observation

// MARK: - Mini Player View

public struct MiniPlayerView: View {
    let audioPlayer: AudioPlayerService
    let onTap: () -> Void
    let onClose: () -> Void

    public init(audioPlayer: AudioPlayerService, onTap: @escaping () -> Void, onClose: @escaping () -> Void) {
        self.audioPlayer = audioPlayer
        self.onTap = onTap
        self.onClose = onClose
    }

    private var coverURL: URL? {
        guard let itemId = audioPlayer.session?.libraryItemId else { return nil }
        return AppState.shared.getCoverURL(itemId: itemId)
    }

    public var body: some View {
        VStack(spacing: 0) {
        HStack {
            Color.clear
                .frame(width: 44, height: 44)
                .overlay {
                    SmartAsyncImage(url: coverURL) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Image("BookPlaceholder", bundle: .module)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    }
                }
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)

            VStack(alignment: .leading, spacing: 2) {
                Text(audioPlayer.session?.displayTitle ?? "Sample Book Title")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Text(audioPlayer.session?.displayAuthor ?? "Sample Author")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Button {
                audioPlayer.togglePlayPause()
            } label: {
                Image(systemName: audioPlayer.isPlaying ? "pause.fill" : "play.fill")
                    .font(.title3)
                    .foregroundStyle(.primary)
                    .applyPlayPauseSymbolEffect(isPlaying: audioPlayer.isPlaying)
            }
            .applySensoryFeedback(trigger: audioPlayer.isPlaying)
            .padding(.trailing, 4)

            Button {
                audioPlayer.skipForward()
            } label: {
                Image(systemName: "goforward.15")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(8)
            }

            Button {
                onClose()
            } label: {
                Image(systemName: "xmark")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                    .padding(6)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .contextMenu {
            Button(role: .destructive) {
                onClose()
            } label: {
                Label("Stop Playback", systemImage: "xmark.circle")
            }
        }

        // Glowing Progress Bar
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(Color.white.opacity(0.12))

                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [Color.appPrimary, Color.cyan],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: max(0, min(geometry.size.width, geometry.size.width * CGFloat(audioPlayer.duration > 0 ? audioPlayer.currentTime / audioPlayer.duration : 0))))
                    .shadow(color: Color.appPrimary.opacity(0.6), radius: 4)
            }
        }
        .frame(height: 3)
        }
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: .black.opacity(0.35), radius: 16, x: 0, y: 8)
        .overlay(content: {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [.white.opacity(0.35), .white.opacity(0.05)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        })
        .padding(.horizontal, 12)
        .liquidPressable()
        .onTapGesture {
            onTap()
        }
    }
}
