//
//  SocketService.swift
//  Audiobookphile
//
//  WebSocket service (disabled by user request).
//

import Foundation

/// WebSocket service for real-time updates from Audiobookphile server (disabled)
@MainActor
public class SocketService: ObservableObject {
    public static let shared = SocketService()

    @Published public var isConnected = false
    @Published public var isAuthenticated = false
    @Published public var lastError: String?

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

