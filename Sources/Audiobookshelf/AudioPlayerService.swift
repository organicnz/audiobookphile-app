//
//  AudioPlayerService.swift
//  Audiobookshelf
//
//  Playback state coordinator, compatible with Swift 6.3 and Skip.
//

import Foundation
import Observation
import SkipFuse
import SwiftUI

@Observable
@MainActor
public class AudioPlayerService {
    public static let shared = AudioPlayerService()

    public var session: PlaybackSession? = nil

    private init() {}

    public func closeSession() async {
        session = nil
    }
}

public final class ProMotionManager: ObservableObject, Sendable {
    public static let shared = ProMotionManager()
    public init() {}
    public func enableHighPerformanceMode() {
        #if os(iOS)
        print("[ProMotion] High performance mode enabled")
        #endif
    }
    
    public func optimizedSpring(response: Double = 0.3, dampingFraction: Double = 0.8) -> Animation {
        return .spring(response: response, dampingFraction: dampingFraction)
    }
}
