import SwiftUI

public extension View {
    @ViewBuilder
    func applyBookshelfScrollTransition() -> some View {
        #if os(iOS) && !SKIP
        if #available(iOS 17.0, *) {
            self.scrollTransition { content, phase in
                content
                    .opacity(phase.isIdentity ? 1 : 0.5)
                    .scaleEffect(phase.isIdentity ? 1 : 0.8)
                    .blur(radius: phase.isIdentity ? 0 : 5)
            }
        } else {
            self
        }
        #else
        self
        #endif
    }
    
    @ViewBuilder
    func applyPlayPauseSymbolEffect(isPlaying: Bool) -> some View {
        #if os(iOS) && !SKIP
        if #available(iOS 17.0, *) {
            self.contentTransition(.symbolEffect(.replace))
        } else {
            self
        }
        #else
        self
        #endif
    }
    
    @ViewBuilder
    func applyConnectPulseEffect(isAnimating: Bool) -> some View {
        #if os(iOS) && !SKIP
        if #available(iOS 17.0, *) {
            self.symbolEffect(.pulse, options: .repeating, isActive: isAnimating)
        } else {
            self
        }
        #else
        self
        #endif
    }
    
    @ViewBuilder
    func applySensoryFeedback<T: Equatable>(trigger: T) -> some View {
        #if os(iOS) && !SKIP
        if #available(iOS 17.0, *) {
            self.sensoryFeedback(.impact(weight: .medium), trigger: trigger)
        } else {
            self
        }
        #else
        self
        #endif
    }
}
