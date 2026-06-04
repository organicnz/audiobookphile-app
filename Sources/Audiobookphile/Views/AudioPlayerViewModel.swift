import SwiftUI
import Observation

// MARK: - ViewModel

@Observable
@MainActor
public class AudioPlayerViewModel {
    public var hasBookmarks = false
    public var useTotalTrack = true

    public var jumpForwardTime: Int {
        let val = UserDefaults.standard.integer(forKey: "jumpForwardTime")
        return val == 0 ? 30 : val
    }

    public var jumpBackwardTime: Int {
        let val = UserDefaults.standard.integer(forKey: "jumpBackwardTime")
        return val == 0 ? 10 : val
    }

    public let session: PlaybackSession

    public var title: String { session.displayTitle }
    public var author: String { session.displayAuthor }
    public var duration: TimeInterval {
        let actual = AudioPlayerService.shared.duration
        return actual > 0 ? actual : session.duration
    }
    public var chapters: [Chapter] { session.chapters }

    public var coverURL: URL? {
        AudiobookphileAPI.shared.getCoverURL(itemId: session.libraryItemId)
    }

    public var isPlaying: Bool {
        AudioPlayerService.shared.isPlaying
    }

    public var currentTime: TimeInterval {
        AudioPlayerService.shared.currentTime
    }

    public var playbackRate: Float {
        AudioPlayerService.shared.playbackRate
    }

    public var progress: Double {
        duration > 0 ? currentTime / duration : 0.0
    }

    public var bufferedProgress: Double {
        min(1.0, progress + 0.05)
    }

    public var sleepTimerActive: Bool {
        AudioPlayerService.shared.sleepTimerRemaining != nil
    }

    public var sleepTimerRemainingPretty: String {
        guard let remaining = AudioPlayerService.shared.sleepTimerRemaining else { return "" }
        let minutes = Int(remaining) / 60
        let seconds = Int(remaining) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    public var currentChapter: Chapter? {
        chapters.first { $0.start <= currentTime && $0.end > currentTime }
    }

    public var currentChapterTitle: String {
        currentChapter?.title ?? ""
    }

    public var hasNextChapter: Bool {
        chapters.contains { $0.start > currentTime }
    }

    public var totalProgress: Double {
        duration > 0 ? currentTime / duration : 0
    }

    public var currentTimePretty: String {
        formatTime(currentTime)
    }

    public var totalTimeRemainingPretty: String {
        "-" + formatTime(duration - currentTime)
    }

    public var currentChapterTimePretty: String {
        guard let chapter = currentChapter else { return currentTimePretty }
        return formatTime(currentTime - chapter.start)
    }

    public var timeRemainingPretty: String {
        guard let chapter = currentChapter else { return totalTimeRemainingPretty }
        return "-" + formatTime(chapter.end - currentTime)
    }

    public init(session: PlaybackSession) {
        self.session = session
        
        // Start playback if it's a new or different session
        if AudioPlayerService.shared.session?.id != session.id {
            AudioPlayerService.shared.startPlayback(session: session)
        }
    }

    public func togglePlayPause() {
        AudioPlayerService.shared.togglePlayPause()
    }

    public func seek(to time: TimeInterval) {
        AudioPlayerService.shared.seek(to: time)
    }

    public func jumpForward() {
        AudioPlayerService.shared.skipForward()
    }

    public func jumpBackward() {
        AudioPlayerService.shared.skipBackward()
    }

    public func jumpToChapterStart() {
        if let chapter = currentChapter {
            seek(to: chapter.start)
        }
    }

    public func jumpToNextChapter() {
        if let nextChapter = chapters.first(where: { $0.start > currentTime }) {
            seek(to: nextChapter.start)
        }
    }

    public func setPlaybackRate(_ rate: Float) {
        AudioPlayerService.shared.setPlaybackRate(rate)
    }

    public func showBookmarks() {}

    public func formatTime(_ time: TimeInterval) -> String {
        let hours = Int(time) / 3600
        let minutes = (Int(time) % 3600) / 60
        let seconds = Int(time) % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }
}
