//
//  NetworkMonitor.swift
//  AudiobookphileClient
//
//  Monitor network connectivity and metering (WiFi vs Cellular)
//

import Foundation
import Network
import Combine
import SwiftUI

/// Monitors network connectivity and connection type
@MainActor
class NetworkMonitor: ObservableObject {
    static let shared = NetworkMonitor()

    /// Whether the device has any network connection
    @Published var isConnected = true

    /// Whether the current connection is metered (cellular)
    @Published var isMetered = false

    /// The current connection type
    @Published var connectionType: ConnectionType = .unknown

    /// Whether the device has WiFi connectivity
    @Published var hasWiFi = false

    /// Whether the device has cellular connectivity
    @Published var hasCellular = false

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitor", qos: .utility)

    enum ConnectionType: String {
        case wifi = "WiFi"
        case cellular = "Cellular"
        case ethernet = "Ethernet"
        case unknown = "Unknown"
        case none = "No Connection"
    }

    init() {
        startMonitoring()
    }

    private func startMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                self?.handlePathUpdate(path)
            }
        }
        monitor.start(queue: queue)
    }

    private func handlePathUpdate(_ path: NWPath) {
        isConnected = path.status == .satisfied
        isMetered = path.isExpensive
        hasWiFi = path.usesInterfaceType(.wifi)
        hasCellular = path.usesInterfaceType(.cellular)

        if path.usesInterfaceType(.wifi) {
            connectionType = .wifi
        } else if path.usesInterfaceType(.cellular) {
            connectionType = .cellular
        } else if path.usesInterfaceType(.wiredEthernet) {
            connectionType = .ethernet
        } else if path.status == .satisfied {
            connectionType = .unknown
        } else {
            connectionType = .none
        }

        print("[NetworkMonitor] Status: \(isConnected ? "Connected" : "Disconnected"), Type: \(connectionType.rawValue), Metered: \(isMetered)")
    }

    /// Check if streaming is allowed based on settings
    func canStream(streamingPolicy: StreamingPolicy) -> Bool {
        switch streamingPolicy {
        case .always:
            return isConnected
        case .wifiOnly:
            return isConnected && !isMetered
        case .never:
            return false
        }
    }

    /// Check if downloading is allowed based on settings
    func canDownload(downloadPolicy: DownloadPolicy) -> Bool {
        switch downloadPolicy {
        case .always:
            return isConnected
        case .wifiOnly:
            return isConnected && !isMetered
        case .never:
            return false
        }
    }

    deinit {
        monitor.cancel()
    }
}

// MARK: - Settings

enum StreamingPolicy: String, Codable, CaseIterable {
    case always = "ALWAYS"
    case wifiOnly = "WIFI_ONLY"
    case never = "NEVER"

    var displayName: String {
        switch self {
        case .always: return "Always"
        case .wifiOnly: return "WiFi Only"
        case .never: return "Downloaded Only"
        }
    }
}

enum DownloadPolicy: String, Codable, CaseIterable {
    case always = "ALWAYS"
    case wifiOnly = "WIFI_ONLY"
    case never = "NEVER"

    var displayName: String {
        switch self {
        case .always: return "Always"
        case .wifiOnly: return "WiFi Only"
        case .never: return "Never"
        }
    }
}

// MARK: - SwiftUI View

struct NetworkStatusView: View {
    @ObservedObject private var networkMonitor = NetworkMonitor.shared

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: statusIcon)
                .foregroundStyle(statusColor)

            Text(networkMonitor.connectionType.rawValue)
                .font(.caption)
                .foregroundStyle(.secondary)

            if networkMonitor.isMetered {
                Text("(Metered)")
                    .font(.caption2)
                    .foregroundStyle(.orange)
            }
        }
    }

    private var statusIcon: String {
        if !networkMonitor.isConnected {
            return "wifi.slash"
        } else if networkMonitor.connectionType == .wifi {
            return "wifi"
        } else if networkMonitor.connectionType == .cellular {
            return "antenna.radiowaves.left.and.right"
        } else {
            return "network"
        }
    }

    private var statusColor: Color {
        if !networkMonitor.isConnected {
            return .red
        } else if networkMonitor.isMetered {
            return .orange
        } else {
            return .green
        }
    }
}

// MARK: - Preview

#Preview("Network Status") {
    VStack(spacing: 20) {
        NetworkStatusView()
            .padding()
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 10))

        Text("Connection: \(NetworkMonitor.shared.isConnected ? "Yes" : "No")")
        Text("Metered: \(NetworkMonitor.shared.isMetered ? "Yes" : "No")")
    }
    .padding()
}
