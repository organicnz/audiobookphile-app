import Foundation
import Observation

/// Native WebSocket service for dynamic real-time updates from Audiobookphile server
@Observable
@MainActor
public class SocketService {
    public static let shared = SocketService()

    public var isConnected = false
    public var isAuthenticated = false
    public var lastError: String?

    // Event handlers for dynamic real-time UI updates
    public var onProgressUpdated: ((MediaProgress) -> Void)?
    public var onLibraryItemUpdated: ((String) -> Void)?
    public var onUserUpdated: ((User) -> Void)?
    public var onConnectionStatusChanged: ((Bool) -> Void)?

    private var webSocketTask: URLSessionWebSocketTask?
    private var isReconnecting = false

    private init() {}

    /// Connect to server WebSocket
    public func connect(serverAddress: String, token: String) {
        guard !serverAddress.isEmpty else { return }

        let wsScheme = serverAddress.hasPrefix("https") ? "wss" : "ws"
        let cleanAddress = serverAddress
            .replacingOccurrences(of: "https://", with: "")
            .replacingOccurrences(of: "http://", with: "")
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))

        guard let url = URL(string: "\(wsScheme)://\(cleanAddress)/socket.io/?token=\(token)&EIO=4&transport=websocket") else {
            print("[SocketService] Invalid WebSocket URL")
            return
        }

        disconnect()

        let session = URLSession(configuration: .default)
        let task = session.webSocketTask(with: url)
        self.webSocketTask = task
        task.resume()

        self.isConnected = true
        self.onConnectionStatusChanged?(true)
        print("[SocketService] Connected to real-time WebSocket stream at \(url.host ?? "")")

        listenForMessages()
    }

    /// Disconnect from server
    public func disconnect() {
        webSocketTask?.cancel(with: .normalClosure, reason: nil)
        webSocketTask = nil
        if isConnected {
            isConnected = false
            onConnectionStatusChanged?(false)
            print("[SocketService] Disconnected from WebSocket")
        }
    }

    /// Send authentication message
    public func sendAuthenticate() async {
        let token = await AudiobookphileAPI.shared.accessToken
        let authMessage = "40{\"token\":\"\(token)\"}"
        webSocketTask?.send(.string(authMessage)) { error in
            if let error = error {
                print("[SocketService] Failed to send auth packet: \(error)")
            }
        }
    }

    private func listenForMessages() {
        webSocketTask?.receive { [weak self] result in
            Task { @MainActor in
                guard let self = self else { return }
                switch result {
                case .success(let message):
                    switch message {
                    case .string(let text):
                        self.handleIncomingText(text)
                    case .data(let data):
                        if let text = String(data: data, encoding: .utf8) {
                            self.handleIncomingText(text)
                        }
                    @unknown default:
                        break
                    }
                    self.listenForMessages()
                case .failure(let error):
                    print("[SocketService] WebSocket receive error: \(error.localizedDescription)")
                    self.isConnected = false
                    self.onConnectionStatusChanged?(false)
                }
            }
        }
    }

    private func handleIncomingText(_ text: String) {
        // Socket.IO heartbeats & event packets
        if text == "2" {
            // Ping from server -> Send pong "3"
            webSocketTask?.send(.string("3")) { _ in }
            return
        }

        if text.hasPrefix("42") {
            // Socket.IO event array payload
            let jsonString = String(text.dropFirst(2))
            guard let data = jsonString.data(using: .utf8),
                  let array = try? JSONSerialization.jsonObject(with: data) as? [Any],
                  let eventName = array.first as? String else {
                return
            }

            print("[SocketService] Real-time event received: \(eventName)")
            if eventName == "progress_updated", array.count > 1,
               let payload = try? JSONSerialization.data(withJSONObject: array[1]),
               let progress = try? JSONDecoder().decode(MediaProgress.self, from: payload) {
                onProgressUpdated?(progress)
            } else if eventName == "library_item_updated", array.count > 1,
                      let itemId = array[1] as? String {
                onLibraryItemUpdated?(itemId)
            }
        }
    }
}
