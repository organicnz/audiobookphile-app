import Foundation
#if os(iOS) && !SKIP
import AppIntents

@available(iOS 16.0, *)
public struct PlayAudiobookIntent: AppIntent, AudioPlaybackIntent {
    public static var title: LocalizedStringResource { "Play Audiobook" }
    public static var description: IntentDescription { IntentDescription("Resumes playback of your current audiobook in Audiobookphile.") }

    public init() {}

    public func perform() async throws -> some IntentResult {
        await MainActor.run {
            if !AudioPlayerService.shared.isPlaying {
                AudioPlayerService.shared.togglePlayPause()
            }
        }
        return .result()
    }
}

@available(iOS 16.0, *)
public struct PauseAudiobookIntent: AppIntent, AudioPlaybackIntent {
    public static var title: LocalizedStringResource { "Pause Audiobook" }
    public static var description: IntentDescription { IntentDescription("Pauses playback of your current audiobook in Audiobookphile.") }

    public init() {}

    public func perform() async throws -> some IntentResult {
        await MainActor.run {
            if AudioPlayerService.shared.isPlaying {
                AudioPlayerService.shared.togglePlayPause()
            }
        }
        return .result()
    }
}

@available(iOS 16.0, *)
public struct AudiobookphileShortcuts: AppShortcutsProvider {
    public static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: PlayAudiobookIntent(),
            phrases: [
                "Play my book in \(.applicationName)",
                "Resume my book in \(.applicationName)",
                "Continue listening in \(.applicationName)"
            ],
            shortTitle: "Play Audiobook",
            systemImageName: "play.circle.fill"
        )
        
        AppShortcut(
            intent: PauseAudiobookIntent(),
            phrases: [
                "Pause my book in \(.applicationName)",
                "Stop my book in \(.applicationName)"
            ],
            shortTitle: "Pause Audiobook",
            systemImageName: "pause.circle.fill"
        )
    }
}
#endif
