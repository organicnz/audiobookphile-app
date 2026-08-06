import Foundation
import Observation

@Observable
@MainActor
public class AudioPlayerSleepTimer {
    public var remaining: TimeInterval?
    private var timer: Timer?

    public init() {}

    public func setSleepTimer(minutes: Int, onComplete: @escaping @MainActor () -> Void) {
        stopSleepTimer()
        remaining = TimeInterval(minutes * 60)

        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self = self else { return }
                if let r = self.remaining {
                    if r <= 1 {
                        self.stopSleepTimer()
                        onComplete()
                    } else {
                        self.remaining = r - 1
                    }
                }
            }
        }
    }

    public func stopSleepTimer() {
        timer?.invalidate()
        timer = nil
        remaining = nil
    }

    public func format() -> String {
        guard let r = remaining else { return "" }
        let minutes = Int(r) / 60
        let seconds = Int(r) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
