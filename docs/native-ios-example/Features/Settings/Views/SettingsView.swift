//
//  SettingsView.swift
//  AudiobookphileClient
//
//  App settings with Liquid Glass design
//

import SwiftUI

struct SettingsView: View {
    @StateObject private var viewModel = SettingsViewModel()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                Color.black.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        // User section
                        if let user = viewModel.currentUser {
                            userSection(user)
                        }

                        // Playback settings
                        playbackSection

                        // Network settings
                        networkSection

                        // App settings
                        appSection

                        // About
                        aboutSection

                        // Logout
                        logoutButton

                        Spacer(minLength: 100)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundStyle(.cyan)
                }
            }
        }
    }

    // MARK: - User Section

    private func userSection(_ user: User) -> some View {
        SettingsSection {
            HStack(spacing: 16) {
                // Avatar
                Circle()
                    .fill(LinearGradient(
                        colors: [.blue, .purple],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .frame(width: 50, height: 50)
                    .overlay {
                        Text(String(user.username.prefix(1)).uppercased())
                            .font(.title2.weight(.bold))
                            .foregroundStyle(.white)
                    }

                VStack(alignment: .leading, spacing: 2) {
                    Text(user.username)
                        .font(.headline)
                        .foregroundStyle(.white)

                    Text(user.type.capitalized)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.6))
                }

                Spacer()
            }
        }
    }

    // MARK: - Playback Section

    private var playbackSection: some View {
        SettingsSection(title: "Playback") {
            // Jump forward time
            SettingsRow(
                icon: "goforward",
                title: "Jump Forward",
                value: "\(viewModel.jumpForwardTime)s"
            ) {
                // Show picker
            }

            // Jump backward time
            SettingsRow(
                icon: "gobackward",
                title: "Jump Backward",
                value: "\(viewModel.jumpBackwardTime)s"
            ) {
                // Show picker
            }

            // Playback speed
            SettingsRow(
                icon: "speedometer",
                title: "Default Speed",
                value: "\(viewModel.defaultPlaybackSpeed)x"
            ) {
                // Show picker
            }

            Divider().background(.white.opacity(0.2))

            // Auto sleep timer
            SettingsToggleRow(
                icon: "moon.fill",
                title: "Auto Sleep Timer",
                isOn: $viewModel.autoSleepTimer
            )

            // Continue playback
            SettingsToggleRow(
                icon: "play.fill",
                title: "Auto Resume",
                isOn: $viewModel.autoResume
            )
        }
    }

    // MARK: - Network Section

    private var networkSection: some View {
        SettingsSection(title: "Network") {
            // Streaming on cellular
            SettingsRow(
                icon: "antenna.radiowaves.left.and.right",
                title: "Stream on Cellular",
                value: viewModel.streamingPolicy.displayName
            ) {
                // Show picker
            }

            // Download on cellular
            SettingsRow(
                icon: "arrow.down.circle",
                title: "Download on Cellular",
                value: viewModel.downloadPolicy.displayName
            ) {
                // Show picker
            }
        }
    }

    // MARK: - App Section

    private var appSection: some View {
        SettingsSection(title: "App") {
            // Theme
            SettingsRow(
                icon: "paintpalette",
                title: "Theme",
                value: "System"
            ) {
                // Show picker
            }

            // Haptics
            SettingsToggleRow(
                icon: "waveform",
                title: "Haptic Feedback",
                isOn: $viewModel.hapticsEnabled
            )

            // Lock orientation
            SettingsToggleRow(
                icon: "lock.rotation",
                title: "Lock Orientation",
                isOn: $viewModel.lockOrientation
            )
        }
    }

    // MARK: - About Section

    private var aboutSection: some View {
        SettingsSection(title: "About") {
            SettingsRow(
                icon: "info.circle",
                title: "Version",
                value: "1.0.0"
            ) {}

            SettingsRow(
                icon: "server.rack",
                title: "Server",
                value: viewModel.serverURL
            ) {}
        }
    }

    // MARK: - Logout Button

    private var logoutButton: some View {
        Button {
            viewModel.logout()
        } label: {
            HStack {
                Spacer()

                Label("Disconnect", systemImage: "rectangle.portrait.and.arrow.right")
                    .font(.headline)
                    .foregroundStyle(.red)

                Spacer()
            }
            .padding(16)
            .background(.red.opacity(0.15))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .padding(.top, 16)
    }
}

// MARK: - ViewModel

@MainActor
class SettingsViewModel: ObservableObject {
    @Published var currentUser: User?
    @Published var jumpForwardTime = 30
    @Published var jumpBackwardTime = 10
    @Published var defaultPlaybackSpeed = 1.0
    @Published var autoSleepTimer = false
    @Published var autoResume = true
    @Published var streamingPolicy: StreamingPolicy = .always
    @Published var downloadPolicy: DownloadPolicy = .wifiOnly
    @Published var hapticsEnabled = true
    @Published var lockOrientation = false
    @Published var serverURL = ""

    init() {
        loadSettings()
        currentUser = AudiobookphileAPI.shared.currentUser
    }

    func loadSettings() {
        let defaults = UserDefaults.standard
        jumpForwardTime = defaults.integer(forKey: "jumpForwardTime")
        if jumpForwardTime == 0 { jumpForwardTime = 30 }

        jumpBackwardTime = defaults.integer(forKey: "jumpBackwardTime")
        if jumpBackwardTime == 0 { jumpBackwardTime = 10 }

        defaultPlaybackSpeed = defaults.double(forKey: "defaultPlaybackSpeed")
        if defaultPlaybackSpeed == 0 { defaultPlaybackSpeed = 1.0 }

        autoSleepTimer = defaults.bool(forKey: "autoSleepTimer")
        autoResume = defaults.bool(forKey: "autoResume")
        hapticsEnabled = defaults.bool(forKey: "hapticsEnabled")
        lockOrientation = defaults.bool(forKey: "lockOrientation")
        serverURL = defaults.string(forKey: "serverURL") ?? ""
    }

    func logout() {
        AudiobookphileAPI.shared.logout()
    }
}

// MARK: - Supporting Views

struct SettingsSection<Content: View>: View {
    var title: String?
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let title = title {
                Text(title.uppercased())
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.6))
                    .padding(.leading, 4)
            }

            VStack(spacing: 0) {
                content
            }
            .padding(4)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
}

struct SettingsRow: View {
    let icon: String
    let title: String
    let value: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(.cyan)
                    .frame(width: 28)

                Text(title)
                    .foregroundStyle(.white)

                Spacer()

                Text(value)
                    .foregroundStyle(.white.opacity(0.6))

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.4))
            }
            .padding(12)
        }
    }
}

struct SettingsToggleRow: View {
    let icon: String
    let title: String
    @Binding var isOn: Bool

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(.cyan)
                .frame(width: 28)

            Text(title)
                .foregroundStyle(.white)

            Spacer()

            Toggle("", isOn: $isOn)
                .labelsHidden()
                .tint(.cyan)
        }
        .padding(12)
    }
}

// MARK: - Preview

#Preview("Settings") {
    SettingsView()
}
