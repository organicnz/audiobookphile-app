import Foundation
import Observation

#if !SKIP && !os(Android)
import MediaPlayer
#endif

@Observable
@MainActor
public class AudioPlayerNowPlayingManager {
    public init() {}
    
    #if !SKIP && !os(Android)
    private var remoteCommandTargetsSetup = false

    public func setupNowPlayingInfo(
        title: String,
        author: String,
        duration: TimeInterval,
        currentTime: TimeInterval,
        playbackRate: Float
    ) {
        var nowPlayingInfo = [String: Any]()
        nowPlayingInfo[MPMediaItemPropertyTitle] = title
        nowPlayingInfo[MPMediaItemPropertyArtist] = author
        nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = duration
        nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = currentTime
        nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = playbackRate

        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
    }

    public func updateNowPlaying(rate: Float? = nil, elapsedTime: TimeInterval? = nil) {
        var info = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? [String: Any]()
        if let rate = rate {
            info[MPNowPlayingInfoPropertyPlaybackRate] = rate
        }
        if let elapsed = elapsedTime {
            info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = elapsed
        }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }

    public func setupRemoteCommandCenter(
        onPlay: @escaping @MainActor () -> Void,
        onPause: @escaping @MainActor () -> Void,
        onSkipForward: @escaping @MainActor (TimeInterval) -> Void,
        onSkipBackward: @escaping @MainActor (TimeInterval) -> Void,
        onSeek: @escaping @MainActor (TimeInterval) -> Void
    ) {
        if remoteCommandTargetsSetup { return }
        remoteCommandTargetsSetup = true

        let commandCenter = MPRemoteCommandCenter.shared()

        commandCenter.playCommand.isEnabled = true
        commandCenter.playCommand.addTarget { _ in
            Task { @MainActor in onPlay() }
            return .success
        }

        commandCenter.pauseCommand.isEnabled = true
        commandCenter.pauseCommand.addTarget { _ in
            Task { @MainActor in onPause() }
            return .success
        }

        commandCenter.skipForwardCommand.isEnabled = true
        commandCenter.skipForwardCommand.preferredIntervals = [30]
        commandCenter.skipForwardCommand.addTarget { _ in
            Task { @MainActor in onSkipForward(30) }
            return .success
        }

        commandCenter.skipBackwardCommand.isEnabled = true
        commandCenter.skipBackwardCommand.preferredIntervals = [10]
        commandCenter.skipBackwardCommand.addTarget { _ in
            Task { @MainActor in onSkipBackward(10) }
            return .success
        }

        commandCenter.changePlaybackPositionCommand.isEnabled = true
        commandCenter.changePlaybackPositionCommand.addTarget { event in
            guard let positionEvent = event as? MPChangePlaybackPositionCommandEvent else {
                return .commandFailed
            }
            Task { @MainActor in onSeek(positionEvent.positionTime) }
            return .success
        }
    }
    #endif
}
