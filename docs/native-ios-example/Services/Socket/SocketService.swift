//
//  SocketService.swift
//  AudiobookshelfClient
//
//  WebSocket service for real-time updates from server
//

import Foundation
import Combine
import SwiftUI

/// WebSocket service for real-time updates from Audiobookshelf server
/// Uses Socket.IO protocol
@MainActor
class SocketService: ObservableObject {
    static let shared = SocketService()

    @Published var isConnected = false
    @Published var isAuthenticated = false
    @Published var lastError: Error?

    private var webSocketTask: URLSessionWebSocketTask?
    private var serverAddress: String?
    private var token: String?
    private var reconnectAttempts = 0
    private let maxReconnectAttempts = 5
    private var cancellables = Set<AnyCancellable>()

    // Event handlers
    var onProgressUpdated: ((MediaProgress) -> Void)?
    var onLibraryItemUpdated: ((String) -> Void)?
    var onUserUpdated: ((User) -> Void)?
    var onConnectionStatusChanged: ((Bool) -> Void)?

    private init() {}

    /// Connect to server WebSocket
    func connect(serverAddress: String, token: String) {
        self.serverAddress = serverAddress
        self.token = token

        // Parse server URL for WebSocket
        guard let serverURL = URL(string: serverAddress),
              var components = URLComponents(url: serverURL, resolvingAgainstBaseURL: false) else {
            print("[SocketService] Invalid server URL")
            return
        }

        // Convert to WebSocket URL
        components.scheme = components.scheme == "https" ? "wss" : "ws"
        components.path = "\(components.path)/socket.io/"
        components.queryItems = [
            URLQueryItem(name: "EIO", value: "4"),
            URLQueryItem(name: "transport", value: "websocket"),
            URLQueryItem(name: "token", value: token)
        ]

        guard let wsURL = components.url else {
            print("[SocketService] Failed to create WebSocket URL")
            return
        }

        print("[SocketService] Connecting to \(wsURL)")

        let session = URLSession(configuration: .default)
        webSocketTask = session.webSocketTask(with: wsURL)
        webSocketTask?.resume()

        receiveMessage()

        // Send initial ping
        Task {
            try? await Task.sleep(nanoseconds: 500_000_000)
            self.sendPing()
        }

        isConnected = true
        onConnectionStatusChanged?(true)
    }

    /// Disconnect from server
    func disconnect() {
        webSocketTask?.cancel(with: .normalClosure, reason: nil)
        webSocketTask = nil
        isConnected = false
        isAuthenticated = false
        onConnectionStatusChanged?(false)
    }

    /// Send authentication message
    func sendAuthenticate() {
        guard let token = token else { return }

        // Socket.IO message format: 42["event", data]
        let authMessage = "42[\"auth\",\"\(token)\"]"
        send(message: authMessage)
    }

    /// Receive messages
    private func receiveMessage() {
        webSocketTask?.receive { [weak self] result in
            Task { @MainActor in
                guard let self = self else { return }
                switch result {
                case .success(let message):
                    switch message {
                    case .string(let text):
                        self.handleMessage(text)
                    case .data(let data):
                        if let text = String(data: data, encoding: .utf8) {
                            self.handleMessage(text)
                        }
                    @unknown default:
                        break
                    }
                    // Continue receiving
                    self.receiveMessage()

                case .failure(let error):
                    print("[SocketService] Receive error: \(error)")
                    self.handleDisconnect(error: error)
                }
            }
        }
    }

    /// Handle incoming message
    private func handleMessage(_ message: String) {
        print("[SocketService] Received: \(message)")

        // Socket.IO protocol parsing
        if message.hasPrefix("0") {
            // Connection established
            handleConnect()
        } else if message.hasPrefix("2") {
            // Pong response
            handlePong()
        } else if message.hasPrefix("3") {
            // Ping from server
            sendPong()
        } else if message.hasPrefix("40") {
            // Namespace connected
            handleNamespaceConnect()
        } else if message.hasPrefix("42") {
            // Event message
            handleEvent(message)
        } else if message.hasPrefix("41") {
            // Namespace disconnect
            handleDisconnect(error: nil)
        }
    }

    private func handleConnect() {
        print("[SocketService] Socket connected")
        isConnected = true
        reconnectAttempts = 0
    }

    private func handleNamespaceConnect() {
        print("[SocketService] Namespace connected, sending auth")
        sendAuthenticate()
    }

    private func handlePong() {
        // Server responded to ping
    }

    private func sendPing() {
        send(message: "2")

        // Schedule next ping in 25 seconds
        Task {
            try? await Task.sleep(nanoseconds: 25_000_000_000)
            if self.isConnected {
                self.sendPing()
            }
        }
    }

    private func sendPong() {
        send(message: "3")
    }

    /// Handle Socket.IO event messages
    private func handleEvent(_ message: String) {
        // Parse: 42["eventName", {data}]
        guard let startIndex = message.firstIndex(of: "["),
              let jsonData = message[startIndex...].data(using: .utf8) else {
            return
        }

        do {
            if let array = try JSONSerialization.jsonObject(with: jsonData) as? [Any],
               let eventName = array.first as? String {

                switch eventName {
                case "init":
                    print("[SocketService] Auth successful")
                    isAuthenticated = true

                case "user_item_progress_updated":
                    if let data = array[safe: 1] as? [String: Any],
                       let progressData = data["data"] as? [String: Any] {
                        handleProgressUpdate(progressData)
                    }

                case "user_updated":
                    if let data = array[safe: 1] as? [String: Any] {
                        handleUserUpdate(data)
                    }

                case "item_updated":
                    if let data = array[safe: 1] as? [String: Any],
                       let id = data["id"] as? String {
                        onLibraryItemUpdated?(id)
                    }

                case "auth_failed":
                    print("[SocketService] Auth failed")
                    isAuthenticated = false

                default:
                    print("[SocketService] Unhandled event: \(eventName)")
                }
            }
        } catch {
            print("[SocketService] Failed to parse event: \(error)")
        }
    }

    private var customDecoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let timestamp = try container.decode(Double.self)
            return Date(timeIntervalSince1970: timestamp / 1000.0)
        }
        return decoder
    }

    /// Handle progress update from another device
    private func handleProgressUpdate(_ data: [String: Any]) {
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: data)
            let progress = try customDecoder.decode(MediaProgress.self, from: jsonData)
            print("[SocketService] Progress update: \(progress.libraryItemId) - \(progress.progress)")
            onProgressUpdated?(progress)
        } catch {
            print("[SocketService] Failed to decode progress: \(error)")
        }
    }

    /// Handle user update
    private func handleUserUpdate(_ data: [String: Any]) {
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: data)
            let user = try customDecoder.decode(User.self, from: jsonData)
            onUserUpdated?(user)
        } catch {
            print("[SocketService] Failed to decode user: \(error)")
        }
    }

    /// Handle disconnect
    private func handleDisconnect(error: Error?) {
        isConnected = false
        isAuthenticated = false
        onConnectionStatusChanged?(false)

        if let error = error {
            lastError = error
            print("[SocketService] Disconnected with error: \(error)")
        }

        // Attempt reconnect
        if reconnectAttempts < maxReconnectAttempts {
            reconnectAttempts += 1
            let delay = min(pow(2.0, Double(reconnectAttempts)), 30.0)
            print("[SocketService] Reconnecting in \(delay)s (attempt \(reconnectAttempts))")

            Task {
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                guard let serverAddress = self.serverAddress,
                      let token = self.token else { return }
                self.connect(serverAddress: serverAddress, token: token)
            }
        }
    }

    /// Send message
    private func send(message: String) {
        webSocketTask?.send(.string(message)) { error in
            if let error = error {
                print("[SocketService] Send error: \(error)")
            }
        }
    }
}

// MARK: - Safe Array Access

extension Array {
    subscript(safe index: Int) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}

// MARK: - Preview

#Preview("Socket Service") {
    VStack {
        Text("Socket Status")
            .font(.headline)

        HStack {
            Circle()
                .fill(SocketService.shared.isConnected ? .green : .red)
                .frame(width: 12, height: 12)

            Text(SocketService.shared.isConnected ? "Connected" : "Disconnected")
        }
    }
    .padding()
}
