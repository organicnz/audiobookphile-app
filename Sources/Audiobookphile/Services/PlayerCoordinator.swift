import SwiftUI
import Observation

/// Coordinates the presentation and state of the Audio Player across the app.
/// This decouples player UI state from the global AppState, avoiding transition glitches.
@Observable
@MainActor
public class PlayerCoordinator {
    public static let shared = PlayerCoordinator()
    
    /// Controls whether the full-screen audio player is visible.
    public var isPlayerPresented: Bool = false
    
    private init() {}
    
    /// Safely presents the player with an optional delay to allow current modal dismissals to complete.
    /// This prevents the "black screen" bug in SwiftUI when transitioning between sheets/covers.
    public func presentPlayer(delayMilliseconds: Int = 300) {
        if delayMilliseconds > 0 {
            Task {
                try? await Task.sleep(nanoseconds: UInt64(delayMilliseconds) * 1_000_000)
                self.isPlayerPresented = true
            }
        } else {
            self.isPlayerPresented = true
        }
    }
    
    /// Dismisses the player.
    public func dismissPlayer() {
        self.isPlayerPresented = false
    }
}
