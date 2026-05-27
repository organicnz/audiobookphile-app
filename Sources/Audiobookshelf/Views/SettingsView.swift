//
//  SettingsView.swift
//  Audiobookshelf
//
//  App settings with Liquid Glass design.
//  Compatible with Swift 6.3 and Skip.
//

import SwiftUI
import Observation

public struct SettingsView: View {
    @State var viewModel = SettingsViewModel()
    @Environment(\.dismiss) var dismiss

    public init() {}

    private var trailingPlacement: ToolbarItemPlacement {
        #if os(iOS) || SKIP
        return .navigationBarTrailing
        #else
        return .primaryAction
        #endif
    }

    public var body: some View {
        NavigationStack {
            ZStack {
                // Background
                Color.appBackground.ignoresSafeArea()

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
                .onChange(of: viewModel.autoSleepTimer) { oldValue, newValue in
                    UserDefaults.standard.set(newValue, forKey: "autoSleepTimer")
                }
                .onChange(of: viewModel.autoResume) { oldValue, newValue in
                    UserDefaults.standard.set(newValue, forKey: "autoResume")
                }
                .onChange(of: viewModel.hapticsEnabled) { oldValue, newValue in
                    UserDefaults.standard.set(newValue, forKey: "hapticsEnabled")
                }
                .onChange(of: viewModel.lockOrientation) { oldValue, newValue in
                    UserDefaults.standard.set(newValue, forKey: "lockOrientation")
                }
            }
            .navigationTitle("Settings")
            #if os(iOS) || SKIP
            .navigationBarTitleDisplayMode(.large)
            #endif
            .toolbar {
                ToolbarItem(placement: trailingPlacement) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundStyle(Color.appPrimary)
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
                        colors: [.appPrimary, .appSecondary],
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
            Menu {
                ForEach([5, 10, 15, 30, 45, 60], id: \.self) { seconds in
                    Button("\(seconds) seconds") {
                        viewModel.saveJumpForwardTime(seconds)
                    }
                }
            } label: {
                SettingsRow(
                    icon: "goforward",
                    title: "Jump Forward",
                    value: "\(viewModel.jumpForwardTime)s"
                ) {}
            }

            // Jump backward time
            Menu {
                ForEach([5, 10, 15, 30, 45, 60], id: \.self) { seconds in
                    Button("\(seconds) seconds") {
                        viewModel.saveJumpBackwardTime(seconds)
                    }
                }
            } label: {
                SettingsRow(
                    icon: "gobackward",
                    title: "Jump Backward",
                    value: "\(viewModel.jumpBackwardTime)s"
                ) {}
            }

            // Playback speed
            Menu {
                ForEach([0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0, 2.5, 3.0], id: \.self) { speed in
                    Button(String(format: "%.2fx", speed)) {
                        viewModel.saveDefaultPlaybackSpeed(speed)
                    }
                }
            } label: {
                SettingsRow(
                    icon: "speedometer",
                    title: "Default Speed",
                    value: String(format: "%.1fx", viewModel.defaultPlaybackSpeed)
                ) {}
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
                // Action
            }

            // Download on cellular
            SettingsRow(
                icon: "arrow.down.circle",
                title: "Download on Cellular",
                value: viewModel.downloadPolicy.displayName
            ) {
                // Action
            }
        }
    }

    // MARK: - App Section

    private var appSection: some View {
        SettingsSection(title: "App") {
            // Theme
            Menu {
                ForEach(["System", "Dark", "Light"], id: \.self) { theme in
                    Button(theme) {
                        viewModel.saveTheme(theme)
                    }
                }
            } label: {
                SettingsRow(
                    icon: "paintpalette",
                    title: "Theme",
                    value: viewModel.selectedTheme
                ) {}
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

@Observable
@MainActor
public class SettingsViewModel {
    public var currentUser: User?
    public var jumpForwardTime = 30
    public var jumpBackwardTime = 10
    public var defaultPlaybackSpeed = 1.0
    public var autoSleepTimer = false
    public var autoResume = true
    public var streamingPolicy: StreamingPolicy = .always
    public var downloadPolicy: DownloadPolicy = .wifiOnly
    public var hapticsEnabled = true
    public var lockOrientation = false
    public var selectedTheme = "System"
    public var serverURL = ""

    public init() {
        loadSettings()
        currentUser = AudiobookshelfAPI.shared.currentUser
    }

    public func loadSettings() {
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
        selectedTheme = defaults.string(forKey: "selectedTheme") ?? "System"
        serverURL = defaults.string(forKey: "serverURL") ?? ""
    }

    public func saveJumpForwardTime(_ val: Int) {
        jumpForwardTime = val
        UserDefaults.standard.set(val, forKey: "jumpForwardTime")
    }

    public func saveJumpBackwardTime(_ val: Int) {
        jumpBackwardTime = val
        UserDefaults.standard.set(val, forKey: "jumpBackwardTime")
    }

    public func saveDefaultPlaybackSpeed(_ val: Double) {
        defaultPlaybackSpeed = val
        UserDefaults.standard.set(val, forKey: "defaultPlaybackSpeed")
    }

    public func saveTheme(_ val: String) {
        selectedTheme = val
        UserDefaults.standard.set(val, forKey: "selectedTheme")
    }

    public func logout() {
        AudiobookshelfAPI.shared.logout()
    }
}

// MARK: - Supporting Views

public struct SettingsSection<Content: View>: View {
    public var title: String?
    @ViewBuilder public let content: Content

    public init(title: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    public var body: some View {
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

public struct SettingsRow: View {
    public let icon: String
    public let title: String
    public let value: String
    public let action: () -> Void

    public init(icon: String, title: String, value: String, action: @escaping () -> Void) {
        self.icon = icon
        self.title = title
        self.value = value
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(Color.appPrimary)
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

public struct SettingsToggleRow: View {
    public let icon: String
    public let title: String
    @Binding public var isOn: Bool

    public init(icon: String, title: String, isOn: Binding<Bool>) {
        self.icon = icon
        self.title = title
        self._isOn = isOn
    }

    public var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(Color.appPrimary)
                .frame(width: 28)

            Text(title)
                .foregroundStyle(.white)

            Spacer()

            Toggle("", isOn: $isOn)
                .labelsHidden()
                .tint(.appPrimary)
        }
        .padding(12)
    }
}
