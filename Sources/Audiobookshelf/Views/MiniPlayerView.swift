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
        return AudiobookshelfAPI.shared.getCoverURL(itemId: itemId)
    }

    public var body: some View {
        HStack {
            CachedAsyncImage(url: coverURL) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Image("BookPlaceholder", bundle: .module)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            }
            .frame(width: 48, height: 48)
            .clipShape(RoundedRectangle(cornerRadius: 8))


            VStack(alignment: .leading, spacing: 2) {
                Text(audioPlayer.session?.displayTitle ?? "Sample Book Title")
                    .font(.subheadline.bold())
                    .foregroundStyle(.white)
                Text(audioPlayer.session?.displayAuthor ?? "Sample Author")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.6))
            }

            Spacer()

            Button {
                audioPlayer.togglePlayPause()
            } label: {
                Image(systemName: audioPlayer.isPlaying ? "pause.fill" : "play.fill")
                    .font(.title2)
                    .foregroundStyle(.white)
            }
            .padding(.horizontal)

            Button {
                onClose()
            } label: {
                Image(systemName: "xmark")
                    .foregroundStyle(.white.opacity(0.6))
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
        .onTapGesture {
            onTap()
        }
    }
}
