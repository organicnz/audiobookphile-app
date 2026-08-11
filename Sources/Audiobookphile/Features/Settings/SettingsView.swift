//
//  SettingsView.swift
//  Audiobookphile
//
//  App settings with Liquid Glass design.
//  Compatible with Swift 6.3 and Skip.
//

import SwiftUI
import Observation

public struct SettingsView: View {
    @State var viewModel = SettingsViewModel()
    @Environment(\.dismiss) var dismiss
    @Environment(AppState.self) private var appState

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
                FluidAuraBackground()

                ScrollView {
                    VStack(spacing: 24) {
                        // Quick Navigation Banner (Return to Library & Admin Dashboard)
                        quickNavigationBanner

                        // User section
                        if let user = viewModel.currentUser {
                            userSection(user)
                            securitySection
                        }

                        // Admin (visible to admins & root)
                        if let user = viewModel.currentUser, ["admin", "root"].contains(user.type) {
                            adminSection
                        }

                        // Statistics & Insights
                        statsSection

                        // Playback settings
                        playbackSection

                        // Audio & Hardware Accessibility
                        audioAccessibilitySection

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
            #if os(iOS) || SKIP
            .navigationBarTitleDisplayMode(.large)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        appState.navigation.selectedTab = 0
                        dismiss()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                            Text("Library")
                        }
                        .font(.subheadline.weight(.semibold))
                    }
                    .foregroundStyle(Color.appPrimary)
                }

                ToolbarItem(placement: trailingPlacement) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundStyle(Color.appPrimary)
                }
            }
            .task {
                await viewModel.loadStats(libraryId: appState.currentLibraryId)
            }
        }
    }

    // MARK: - Quick Navigation Banner

    private var quickNavigationBanner: some View {
        VStack(spacing: 10) {
            Button {
                appState.navigation.selectedTab = 0
                dismiss()
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "arrow.left.circle.fill")
                        .font(.title2)
                        .foregroundStyle(Color.appPrimary)

                    Text("Return to Library")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)

                    Spacer()

                    Image(systemName: "books.vertical")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.4))
                }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color.white.opacity(0.06))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(Color.appPrimary.opacity(0.3), lineWidth: 1)
                        )
                )
            }

            if let user = viewModel.currentUser, ["admin", "root"].contains(user.type) {
                NavigationLink {
                    AdminDashboardView()
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "shield.righthalf.filled")
                            .font(.title3)
                            .foregroundStyle(Color.appPrimary)

                        Text("Admin Dashboard")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(Color.appPrimary)

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.4))
                    }
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(Color.appPrimary.opacity(0.15))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(Color.appPrimary.opacity(0.35), lineWidth: 1)
                            )
                    )
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

    // MARK: - Security Section

    private var securitySection: some View {
        SettingsSection(title: "Security & Authentication") {
            NavigationLink {
                TwoFactorSettingsView()
            } label: {
                HStack {
                    Image(systemName: "shield.checkered")
                        .foregroundStyle(Color.appPrimary)
                        .frame(width: 24)

                    Text("Two-Factor Authentication (2FA)")
                        .foregroundStyle(.white)
                        .font(.subheadline.weight(.semibold))

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.4))
                }
                .padding(.vertical, 8)
            }
        }
    }

    // MARK: - Stats Section

    private var statsSection: some View {
        SettingsSection(title: "Statistics & Insights") {
            VStack(spacing: 12) {
                if let lStats = viewModel.libraryStats {
                    HStack(spacing: 0) {
                        statCell(label: "Books", value: "\(lStats.totalBooks)", icon: "book.fill")
                        Divider().frame(height: 32).background(.white.opacity(0.15))
                        statCell(label: "Authors", value: "\(lStats.totalAuthors)", icon: "person.fill")
                        Divider().frame(height: 32).background(.white.opacity(0.15))
                        statCell(label: "Series", value: "\(lStats.totalSeries)", icon: "books.vertical.fill")
                        Divider().frame(height: 32).background(.white.opacity(0.15))
                        statCell(label: "Hours", value: "\(Int(lStats.totalDuration / 3600))h", icon: "clock.fill")
                    }
                    .padding(.vertical, 8)

                    Divider().background(.white.opacity(0.1))
                } else if viewModel.isLoadingStats {
                    HStack(spacing: 8) {
                        ProgressView().tint(.appPrimary)
                        Text("Loading stats…")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.6))
                    }
                    .padding(8)

                    Divider().background(.white.opacity(0.1))
                }

                NavigationLink {
                    StatsView()
                } label: {
                    HStack {
                        Image(systemName: "chart.bar.xaxis")
                            .foregroundStyle(Color.appPrimary)
                            .frame(width: 24)

                        Text("Full Stats & Listening Analytics")
                            .foregroundStyle(.white)
                            .font(.subheadline.weight(.semibold))

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.4))
                    }
                    .padding(.vertical, 4)
                }
            }
            .padding(12)
        }
    }

    private func statCell(label: String, value: String, icon: String) -> some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption2)
                    .foregroundStyle(Color.appPrimary)
                Text(value)
                    .font(.callout.bold())
                    .foregroundStyle(.white)
            }
            Text(label)
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.6))
        }
        .frame(maxWidth: .infinity)
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

    // MARK: - Audio & Hardware Accessibility Section

    private var audioAccessibilitySection: some View {
        SettingsSection(title: "Audio & Hardware Accessibility") {
            SettingsToggleRow(
                icon: "waveform.path.badge.plus",
                title: "Spoken Audio Optimization",
                isOn: $viewModel.spokenAudioModeEnabled
            )

            SettingsToggleRow(
                icon: "waveform.and.mic",
                title: "Vocal Clarity Boost",
                isOn: $viewModel.vocalBoostEnabled
            )

            SettingsToggleRow(
                icon: "slider.horizontal.3",
                title: "Smart Volume Leveler",
                isOn: $viewModel.volumeLevelerEnabled
            )

            SettingsToggleRow(
                icon: "speaker.wave.1.fill",
                title: "Mono Audio Mix",
                isOn: $viewModel.monoAudioEnabled
            )

            Divider().background(.white.opacity(0.2))

            SettingsToggleRow(
                icon: "hifispeaker.fill",
                title: "High-Res 48kHz Output",
                isOn: $viewModel.highResAudioEnabled
            )

            SettingsToggleRow(
                icon: "line.3.horizontal.decrease.circle",
                title: "Low-Cut Rumble Filter (80Hz)",
                isOn: $viewModel.lowCutFilterEnabled
            )

            SettingsToggleRow(
                icon: "sparkles",
                title: "De-Esser Sibilance Reducer",
                isOn: $viewModel.deEsserEnabled
            )

            SettingsToggleRow(
                icon: "waveform.path.badge.plus",
                title: "3D Binaural Studio Acoustics",
                isOn: $viewModel.binauralReverbEnabled
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

    // MARK: - Admin Section

    private var adminSection: some View {
        SettingsSection(title: "Administration") {
            VStack(spacing: 0) {
                NavigationLink {
                    AdminDashboardView()
                } label: {
                    HStack {
                        Image(systemName: "shield.righthalf.filled")
                            .foregroundStyle(Color.orange)
                            .frame(width: 28)

                        Text("Open Admin Dashboard")
                            .foregroundStyle(.white)
                            .font(.subheadline.weight(.semibold))

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.4))
                    }
                    .padding(12)
                }

                Divider()
                    .background(Color.white.opacity(0.1))

                NavigationLink {
                    AdminInviteView()
                } label: {
                    HStack {
                        Image(systemName: "person.badge.plus")
                            .foregroundStyle(Color.appPrimary)
                            .frame(width: 28)

                        Text("Invite User by Email")
                            .foregroundStyle(.white)
                            .font(.subheadline.weight(.semibold))

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.4))
                    }
                    .padding(12)
                }
            }
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
    
    public var serverURL = ""

    // Bindings to AppState
    public var jumpForwardTime: Int {
        get { AppState.shared.settings.jumpForwardTime }
        set { 
            var s = AppState.shared.settings
            s.jumpForwardTime = newValue
            AppState.shared.updateSettings(s)
        }
    }

    public var jumpBackwardTime: Int {
        get { AppState.shared.settings.jumpBackwardsTime }
        set { 
            var s = AppState.shared.settings
            s.jumpBackwardsTime = newValue
            AppState.shared.updateSettings(s)
        }
    }

    public var defaultPlaybackSpeed: Double {
        get { AppState.shared.settings.defaultPlaybackSpeed }
        set { 
            var s = AppState.shared.settings
            s.defaultPlaybackSpeed = newValue
            AppState.shared.updateSettings(s)
        }
    }

    public var autoSleepTimer: Bool {
        get { AppState.shared.settings.sleepTimerAutoStart }
        set { 
            var s = AppState.shared.settings
            s.sleepTimerAutoStart = newValue
            AppState.shared.updateSettings(s)
        }
    }

    public var autoResume: Bool {
        get { AppState.shared.settings.autoResume }
        set { 
            var s = AppState.shared.settings
            s.autoResume = newValue
            AppState.shared.updateSettings(s)
        }
    }

    public var hapticsEnabled: Bool {
        get { AppState.shared.settings.hapticsEnabled }
        set { 
            var s = AppState.shared.settings
            s.hapticsEnabled = newValue
            AppState.shared.updateSettings(s)
        }
    }

    public var lockOrientation: Bool {
        get { AppState.shared.settings.lockOrientation }
        set { 
            var s = AppState.shared.settings
            s.lockOrientation = newValue
            AppState.shared.updateSettings(s)
        }
    }

    public var spokenAudioModeEnabled: Bool {
        get { AppState.shared.settings.spokenAudioModeEnabled }
        set { 
            var s = AppState.shared.settings
            s.spokenAudioModeEnabled = newValue
            AppState.shared.updateSettings(s)
            #if os(iOS)
            AudioPlayerService.shared.reconfigureAudioSession()
            #endif
        }
    }

    public var vocalBoostEnabled: Bool {
        get { AppState.shared.settings.vocalBoostEnabled }
        set { 
            var s = AppState.shared.settings
            s.vocalBoostEnabled = newValue
            AppState.shared.updateSettings(s)
            AudioPlayerService.shared.applyAudioDSP()
        }
    }

    public var volumeLevelerEnabled: Bool {
        get { AppState.shared.settings.volumeLevelerEnabled }
        set { 
            var s = AppState.shared.settings
            s.volumeLevelerEnabled = newValue
            AppState.shared.updateSettings(s)
            AudioPlayerService.shared.applyAudioDSP()
        }
    }

    public var monoAudioEnabled: Bool {
        get { AppState.shared.settings.monoAudioEnabled }
        set { 
            var s = AppState.shared.settings
            s.monoAudioEnabled = newValue
            AppState.shared.updateSettings(s)
        }
    }

    public var highResAudioEnabled: Bool {
        get { AppState.shared.settings.highResAudioEnabled }
        set { 
            var s = AppState.shared.settings
            s.highResAudioEnabled = newValue
            AppState.shared.updateSettings(s)
            #if os(iOS)
            AudioPlayerService.shared.reconfigureAudioSession()
            #endif
            AudioPlayerService.shared.applyAudioDSP()
        }
    }

    public var lowCutFilterEnabled: Bool {
        get { AppState.shared.settings.lowCutFilterEnabled }
        set { 
            var s = AppState.shared.settings
            s.lowCutFilterEnabled = newValue
            AppState.shared.updateSettings(s)
            AudioPlayerService.shared.applyAudioDSP()
        }
    }

    public var deEsserEnabled: Bool {
        get { AppState.shared.settings.deEsserEnabled }
        set { 
            var s = AppState.shared.settings
            s.deEsserEnabled = newValue
            AppState.shared.updateSettings(s)
            AudioPlayerService.shared.applyAudioDSP()
        }
    }

    public var binauralReverbEnabled: Bool {
        get { AppState.shared.settings.binauralReverbEnabled }
        set {
            var s = AppState.shared.settings
            s.binauralReverbEnabled = newValue
            AppState.shared.updateSettings(s)
            AudioPlayerService.shared.applyAudioDSP()
        }
    }

    public var selectedTheme: String {
        get { 
            switch AppState.shared.settings.theme {
            case .dark: return "Dark"
            case .light: return "Light"
            case .system: return "System"
            }
        }
        set { 
            var s = AppState.shared.settings
            switch newValue {
            case "Dark": s.theme = .dark
            case "Light": s.theme = .light
            default: s.theme = .system
            }
            AppState.shared.updateSettings(s)
        }
    }

    public var streamingPolicy: StreamingPolicy = .always
    public var downloadPolicy: DownloadPolicy = .wifiOnly

    public var libraryStats: LibraryStats?
    public var userStats: UserStatsData?
    public var isLoadingStats: Bool = false

    public func loadStats(libraryId: String?) async {
        guard let libraryId = libraryId else { return }
        isLoadingStats = true
        do {
            async let fetchLibraryStats = AudiobookphileAPI.shared.getLibraryStats(libraryId: libraryId)
            async let fetchUserStats = AudiobookphileAPI.shared.getUserStats()
            let (lStats, uStats) = try await (fetchLibraryStats, fetchUserStats)
            self.libraryStats = lStats
            self.userStats = uStats
        } catch {
            print("[SettingsViewModel] Error loading backend stats: \(error)")
        }
        isLoadingStats = false
    }

    public func saveJumpForwardTime(_ val: Int) {
        self.jumpForwardTime = val
    }

    public func saveJumpBackwardTime(_ val: Int) {
        self.jumpBackwardTime = val
    }

    public func saveDefaultPlaybackSpeed(_ val: Double) {
        self.defaultPlaybackSpeed = val
    }

    public func saveTheme(_ val: String) {
        self.selectedTheme = val
    }

    public func logout() {
        AppState.shared.logout()
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
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [.white.opacity(0.25), .white.opacity(0.05)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .shadow(color: Color.black.opacity(0.2), radius: 10, x: 0, y: 4)
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
