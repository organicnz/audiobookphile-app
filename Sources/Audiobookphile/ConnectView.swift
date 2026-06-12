//
//  ConnectView.swift
//  Audiobookphile
//
//  Server connection view with Liquid Glass design.
//  Compatible with Swift 6.3 and Skip.
//

import SwiftUI
import Observation
#if os(iOS) && !SKIP
import UIKit
#endif

public struct RecentServer: Codable, Identifiable {
    public let id: String
    public let address: String
    public let username: String?

    public init(id: String = UUID().uuidString, address: String, username: String? = nil) {
        self.id = id
        self.address = address
        self.username = username
    }
}

public struct ConnectView: View {
    @Environment(AppState.self) private var appState
    @State var viewModel = ConnectViewModel()
    @State var serverURL = EnvironmentConfig.serverURL
    @State var username = ""
    @State var password = ""
    @State var showPassword = false
    @State var isAnimating = false
    @State var appearPhase = 0

    public init() {}

    public var body: some View {
        ZStack {
            // Fluid Aura background
            FluidAuraBackground()

            // Particle effects
            GlassParticlesView(particleCount: 20, colors: [.white.opacity(0.15), .appPrimary.opacity(0.1)])

            ScrollView {
                VStack(spacing: 32) {
                    // Logo and title
                    headerSection
                        .opacity(appearPhase > 0 ? 1 : 0)
                        .offset(y: appearPhase > 0 ? 0 : 30)

                    // Connection form
                    formSection
                        .opacity(appearPhase > 1 ? 1 : 0)
                        .offset(y: appearPhase > 1 ? 0 : 30)

                    // Recent Servers
                    if !viewModel.recentServers.isEmpty {
                        recentServersSection
                            .opacity(appearPhase > 2 ? 1 : 0)
                            .offset(y: appearPhase > 2 ? 0 : 30)
                    }

                    Spacer(minLength: 100)
                }
                .padding(.horizontal, 24)
                .padding(.top, 60)
            }
        }
        .ignoresSafeArea()
        .alert("Connection Error", isPresented: $viewModel.showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                isAnimating = true
            }
            withAnimation(.spring(response: 0.8, dampingFraction: 0.7)) {
                appearPhase = 1
            }
            withAnimation(.spring(response: 0.8, dampingFraction: 0.7).delay(0.2)) {
                appearPhase = 2
            }
            withAnimation(.spring(response: 0.8, dampingFraction: 0.7).delay(0.4)) {
                appearPhase = 3
            }
            // Auto login in simulator/debug for rapid testing
            #if targetEnvironment(simulator) || DEBUG
            Task {
                try? await Task.sleep(for: .seconds(1.0))
                if !serverURL.isEmpty && !username.isEmpty && !password.isEmpty && !appState.isAuthenticated {
                    do {
                        try await appState.login(
                            serverURL: serverURL,
                            username: username,
                            password: password
                        )
                        viewModel.saveRecentServer(address: serverURL, username: username)
                    } catch {
                        viewModel.errorMessage = error.localizedDescription
                        viewModel.showError = true
                    }
                }
            }
            #endif
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(spacing: 16) {
            // App icon
            Image("Logo", bundle: .module)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 120, height: 120)
                .scaleEffect(isAnimating ? 1.05 : 1.0)
                .shadow(color: .appPrimary.opacity(0.5), radius: 25, x: 0, y: 10)

            // Title
            Text("Audiobookphile")
                .font(.system(size: 38, weight: .black, design: .rounded))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.white, .white.opacity(0.8)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .shadow(color: .black.opacity(0.3), radius: 5, x: 0, y: 5)

            Text("Sign in to your account")
                .font(.headline.weight(.medium))
                .foregroundStyle(.white.opacity(0.7))
                .padding(.top, -4)
        }
    }

    // MARK: - Form Section

    private var formSection: some View {
        VStack(spacing: 16) {
            // Server URL
            GlassTextField(
                text: $serverURL,
                placeholder: "Server URL",
                icon: "server.rack",
                autocapitalize: false
            )

            // Username / Email
            GlassTextField(
                text: $username,
                placeholder: "Email address",
                icon: "envelope.fill",
                autocapitalize: false
            )

            // Password
            GlassSecureField(
                text: $password,
                placeholder: "Password",
                icon: "lock.fill",
                showPassword: $showPassword
            )

            // Connect button
            Button {
                #if os(iOS) && !SKIP
                let generator = UIImpactFeedbackGenerator(style: .medium)
                generator.impactOccurred()
                #endif
                
                Task {
                    do {
                        let trimmedURL = serverURL.trimmingCharacters(in: .whitespacesAndNewlines)
                        let trimmedUsername = username.trimmingCharacters(in: .whitespacesAndNewlines)
                        
                        try await appState.login(
                            serverURL: trimmedURL,
                            username: trimmedUsername,
                            password: password
                        )
                        viewModel.saveRecentServer(address: trimmedURL, username: trimmedUsername)
                    } catch {
                        viewModel.errorMessage = error.localizedDescription
                        viewModel.showError = true
                    }
                }
            } label: {
                HStack {
                    if appState.isLoading {
                        ProgressView()
                            .tint(.white)
                            .padding(.trailing, 8)
                    }
                    Text(appState.isLoading ? "Signing in..." : "Sign In")
                        .bold()
                }
                .frame(maxWidth: .infinity)
                .padding()
                .foregroundStyle(.white)
                .background(
                    LinearGradient(colors: [.appPrimary, .appSecondary], startPoint: .leading, endPoint: .trailing)
                )
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .disabled(!isFormValid || appState.isLoading)
            .padding(.top, 8)
        }
        .padding(24)
        .background(.ultraThinMaterial)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(Color.appPrimary.opacity(0.05))
                .shadow(color: .black.opacity(0.2), radius: 30, x: 0, y: 15)
        )
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .overlay {
            RoundedRectangle(cornerRadius: 24)
                .strokeBorder(
                    LinearGradient(
                        colors: [.white.opacity(0.4), .white.opacity(0.05)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        }
    }

    private var isFormValid: Bool {
        !serverURL.isEmpty && !username.isEmpty && !password.isEmpty
    }

    // MARK: - Recent Servers Section

    private var recentServersSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Connections")
                .font(.headline)
                .foregroundStyle(.white.opacity(0.8))
                .padding(.horizontal, 4)

            VStack(spacing: 8) {
                ForEach(viewModel.recentServers) { server in
                    RecentServerRow(server: server) {
                        // Action on tap: pre-fill form
                        withAnimation {
                            serverURL = server.address
                            if let user = server.username {
                                username = user
                            }
                            // Clear password when selecting a new server
                            password = ""
                        }
                    }
                }
            }
        }
        .padding(.top, 16)
    }
}

// MARK: - ViewModel

@Observable
@MainActor
class ConnectViewModel {
    var isLoading = false
    var showError = false
    var errorMessage = ""
    var recentServers: [RecentServer] = []

    init() {
        loadRecentServers()
    }

    private func loadRecentServers() {
        if let data = UserDefaults.standard.data(forKey: "abs_recent_servers"),
           let list = try? JSONDecoder().decode([RecentServer].self, from: data) {
            recentServers = list
        }
    }

    func saveRecentServer(address: String, username: String) {
        let server = RecentServer(address: address, username: username)
        var servers = recentServers.filter { $0.address != address }
        servers.insert(server, at: 0)
        recentServers = Array(servers.prefix(5))

        if let data = try? JSONEncoder().encode(recentServers) {
            UserDefaults.standard.set(data, forKey: "abs_recent_servers")
        }
    }
}

// MARK: - Supporting Views

struct GlassTextField: View {
    @Binding var text: String
    let placeholder: String
    let icon: String
    var autocapitalize: Bool = true

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(.white.opacity(0.6))
                .frame(width: 24)

            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .foregroundStyle(.white)
                #if os(iOS) || SKIP
                .textInputAutocapitalization(autocapitalize ? .sentences : .none)
                #endif
                .autocorrectionDisabled()
        }
        .padding(16)
        .background(.white.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(.white.opacity(0.2), lineWidth: 1)
        }
    }
}

struct GlassSecureField: View {
    @Binding var text: String
    let placeholder: String
    let icon: String
    @Binding var showPassword: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(.white.opacity(0.6))
                .frame(width: 24)

            if showPassword {
                TextField(placeholder, text: $text)
                    .textFieldStyle(.plain)
                    .foregroundStyle(.white)
                    #if os(iOS) || SKIP
                    .textInputAutocapitalization(.none)
                    #endif
                    .autocorrectionDisabled()
            } else {
                SecureField(placeholder, text: $text)
                    .textFieldStyle(.plain)
                    .foregroundStyle(.white)
            }

            Button {
                showPassword.toggle()
            } label: {
                Image(systemName: showPassword ? "eye.slash" : "eye")
                    .foregroundStyle(.white.opacity(0.6))
            }
        }
        .padding(16)
        .background(.white.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(.white.opacity(0.2), lineWidth: 1)
        }
    }
}

struct RecentServerRow: View {
    let server: RecentServer
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack {
                Image(systemName: "server.rack")
                    .foregroundStyle(Color.appPrimary)

                VStack(alignment: .leading, spacing: 2) {
                    Text(server.address)
                        .font(.subheadline)
                        .foregroundStyle(.white)

                    if let username = server.username {
                        Text(username)
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.6))
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .foregroundStyle(.white.opacity(0.4))
            }
            .padding(12)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
}

public struct FluidAuraBackground: View {
    @State private var phase = 0.0

    public init() {}

    public var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            // Background base
            Color(red: 0.05, green: 0.05, blue: 0.08).ignoresSafeArea()
            
            GeometryReader { proxy in
                let w = proxy.size.width
                let h = proxy.size.height
                
                Circle()
                    .fill(Color.appPrimary.opacity(0.5))
                    .frame(width: w * 0.9)
                    .offset(x: sin(phase) * w * 0.25, y: cos(phase) * h * 0.2)
                    .blur(radius: 90)
                
                Circle()
                    .fill(Color.appSecondary.opacity(0.4))
                    .frame(width: w * 0.8)
                    .offset(x: cos(phase + .pi/2) * w * 0.2, y: sin(phase + .pi/2) * h * 0.25)
                    .blur(radius: 90)
                
                Circle()
                    .fill(Color.purple.opacity(0.3))
                    .frame(width: w)
                    .offset(x: sin(phase + .pi) * w * 0.15, y: cos(phase + .pi/4) * h * 0.2)
                    .blur(radius: 100)
            }
        }
        .onAppear {
            withAnimation(.linear(duration: 20).repeatForever(autoreverses: true)) {
                phase = .pi * 2
            }
        }
    }
}

public struct LoadingView: View {
    public let message: String

    public init(message: String = "Loading...") {
        self.message = message
    }

    public var body: some View {
        ZStack {
            FluidAuraBackground()
            VStack(spacing: 20) {
                ProgressView()
                    .tint(.appPrimary)
                    .scaleEffect(1.5)

                Text(message)
                    .font(.headline)
                    .foregroundStyle(.white.opacity(0.8))
            }
        }
    }
}
