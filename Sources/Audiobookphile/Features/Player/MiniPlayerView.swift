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
            SmartAsyncImage(url: coverURL) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Image("BookPlaceholder", bundle: .module)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            }
            .frame(width: 44, height: 44)
            .clipShape(RoundedRectangle(cornerRadius: 6))


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
                    .applyPlayPauseSymbolEffect(isPlaying: audioPlayer.isPlaying)
            }
            .applySensoryFeedback(trigger: audioPlayer.isPlaying)
            .padding(.trailing, 8)

            Button {
                onClose()
            } label: {
                Image(systemName: "xmark")
                    .foregroundStyle(.white.opacity(0.6))
                    .padding(8)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        
        // Progress Bar
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(Color.white.opacity(0.1))
                
                Rectangle()
                    .fill(Color.appPrimary)
                    .frame(width: max(0, min(geometry.size.width, geometry.size.width * CGFloat(audioPlayer.duration > 0 ? audioPlayer.currentTime / audioPlayer.duration : 0))))
            }
        }
        .frame(height: 3)
        }
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
        .padding(.horizontal)
        .onTapGesture {
            onTap()
        }
    }
}
