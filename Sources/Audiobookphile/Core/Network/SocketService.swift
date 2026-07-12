//
//  SocketService.swift
//  Audiobookphile
//
//  WebSocket service (disabled by user request).
//

import Foundation
import Observation

/// WebSocket service for real-time updates from Audiobookphile server (disabled)
@Observable
@MainActor
public class SocketService {
    public static let shared = SocketService()

    public var isConnected = false
    public var isAuthenticated = false
    public var lastError: String?

    // Event handlers (maintained for API compatibility)
    public var onProgressUpdated: ((MediaProgress) -> Void)?
    public var onLibraryItemUpdated: ((String) -> Void)?
    public var onUserUpdated: ((User) -> Void)?
    public var onConnectionStatusChanged: ((Bool) -> Void)?

    private init() {}

    /// Connect to server WebSocket - disabled
    public func connect(serverAddress: String, token: String) {
        print("[SocketService] WebSockets are disabled by configuration.")
    }

    /// Disconnect from server - disabled
    public func disconnect() {
        // No-op
    }

    /// Send authentication message - disabled
    public func sendAuthenticate() {
        // No-op
    }
}
