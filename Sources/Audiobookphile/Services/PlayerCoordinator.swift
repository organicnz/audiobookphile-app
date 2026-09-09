import SwiftUI
import Observation

// MARK: - PlayerCoordinatorProtocol

/// Interface for the player-presentation coordinator, enabling dependency
/// injection and test doubles in previews and unit tests.
/// Plain protocol (not ObservableObject): `@Observable` classes satisfy it
/// structurally without inheriting from `ObservableObject`.
@MainActor
public protocol PlayerCoordinatorProtocol: AnyObject {
    /// Whether the full-screen audio player is currently presented.
    var isPlayerPresented: Bool { get set }

    /// Safely presents the player, accounting for in-flight modal presentations.
    /// - Parameter delayMilliseconds: Delay to allow current modal dismissals to complete.
    func presentPlayer(delayMilliseconds: Int)

    /// Dismisses the player.
    func dismissPlayer()
}

// MARK: - PlayerCoordinator

/// Coordinates the presentation and state of the Audio Player across the app.
/// This decouples player UI state from the global AppState, avoiding transition glitches.
@Observable
@MainActor
final class PlayerCoordinator: PlayerCoordinatorProtocol {
    public static let shared = PlayerCoordinator()

    /// Controls whether the full-screen audio player is visible.
    public var isPlayerPresented: Bool = false

    private init() {}

    /// Safely presents the player with an optional delay to allow current modal dismissals to complete.
    ///
    /// The delay alone is not sufficient: presenting `.fullScreenCover` while another
    /// presentation (e.g. a dismissing sheet) is still animating collides SwiftUI's
    /// presentation transactions and produces the notorious black screen. After the
    /// delay elapses we additionally poll until UIKit reports no in-flight modal,
    /// then present — turning a timing race into a guaranteed-safe handoff.
    public func presentPlayer(delayMilliseconds: Int = 300) {
        Task { @MainActor in
            if delayMilliseconds > 0 {
                try? await Task.sleep(nanoseconds: UInt64(delayMilliseconds) * 1_000_000)
            }
            #if !SKIP && os(iOS)
            await Self.waitUntilNoInFlightModalPresentation()
            #endif
            self.isPlayerPresented = true
        }
    }

    /// Dismisses the player.
    public func dismissPlayer() {
        self.isPlayerPresented = false
    }

    #if !SKIP && os(iOS)
    /// Polls (bounded to ~5s) until the key window has no presented view
    /// controller, i.e. no sheet/fullScreenCover is mid-transition.
    private static func waitUntilNoInFlightModalPresentation() async {
        for _ in 0..<50 {
            let root = UIApplication.shared.connectedScenes
                .compactMap { ($0 as? UIWindowScene)?.keyWindow?.rootViewController }
                .first
            guard let root else { return }
            if root.presentedViewController == nil { return }
            try? await Task.sleep(nanoseconds: 100_000_000)
        }
    }
    #endif
}
