//
//  ConnectView.swift
//  AudiobookphileClient
//
//  Server connection view with Liquid Glass design
//

import SwiftUI

struct ConnectView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var viewModel = ConnectViewModel()
    @State private var serverURL = ""
    @State private var username = ""
    @State private var password = ""
    @State private var showPassword = false
    @State private var isAnimating = false

    var body: some View {
        ZStack {
            // Animated gradient background
            AnimatedGradientBackground()

            // Particle effects
            GlassParticlesView(particleCount: 60, colors: [.white.opacity(0.3), .cyan.opacity(0.2)])

            ScrollView {
                VStack(spacing: 32) {
                    // Logo and title
                    headerSection

                    // Connection form
                    formSection

                    // Recent servers (if any)
                    if !viewModel.recentServers.isEmpty {
                        recentServersSection
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
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(spacing: 16) {
            // App icon
            ZStack {
                Circle()
                    .fill(.ultraThinMaterial)
                    .frame(width: 120, height: 120)

                Image(systemName: "books.vertical.fill")
                    .font(.system(size: 50))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.cyan, .blue, .purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .scaleEffect(isAnimating ? 1.05 : 1.0)
            }
            .shadow(color: .cyan.opacity(0.3), radius: 20)

            // Title
            Text("Audiobookphile")
                .font(.system(size: 36, weight: .bold))
                .foregroundStyle(.white)

            Text("Connect to your server")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.7))
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
                keyboardType: .URL,
                autocapitalization: .never
            )

            // Username
            GlassTextField(
                text: $username,
                placeholder: "Username",
                icon: "person.fill",
                autocapitalization: .never
            )

            // Password
            GlassSecureField(
                text: $password,
                placeholder: "Password",
                icon: "lock.fill",
                showPassword: $showPassword
            )

            // Connect button
            GlassButton(
                title: appState.isLoading ? "Connecting..." : "Connect",
                icon: appState.isLoading ? "arrow.2.circlepath" : "arrow.right.circle.fill",
                size: .large,
                colors: [.blue, .purple],
                isLoading: appState.isLoading
            ) {
                Task {
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
            .disabled(!isFormValid || appState.isLoading)
            .padding(.top, 8)
        }
        .padding(24)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .overlay {
            RoundedRectangle(cornerRadius: 24)
                .strokeBorder(
                    LinearGradient(
                        colors: [.white.opacity(0.3), .white.opacity(0.1)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        }
    }

    // MARK: - Recent Servers

    private var recentServersSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Servers")
                .font(.headline)
                .foregroundStyle(.white.opacity(0.8))
                .padding(.leading, 4)

            ForEach(viewModel.recentServers, id: \.id) { server in
                RecentServerRow(server: server) {
                    serverURL = server.address
                    username = server.username ?? ""
                }
            }
        }
    }

    private var isFormValid: Bool {
        !serverURL.isEmpty && !username.isEmpty && !password.isEmpty
    }
}

// MARK: - ViewModel

@MainActor
class ConnectViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var showError = false
    @Published var errorMessage = ""
    @Published var recentServers: [RecentServer] = []

    // Inject AppState via simple dependency or just handle local state
    // Ideally we'd call back to the view, but let's expose a way to inject logic or just use AppState in the View

    init() {
        loadRecentServers()
    }

    private func loadRecentServers() {
        // Load from UserDefaults
    }

    func saveRecentServer(address: String, username: String) {
        let server = RecentServer(id: UUID().uuidString, address: address, username: username)
        var servers = recentServers.filter { $0.address != address }
        servers.insert(server, at: 0)
        recentServers = Array(servers.prefix(5))
    }
}

// MARK: - Supporting Views

struct GlassTextField: View {
    @Binding var text: String
    let placeholder: String
    let icon: String
    var keyboardType: UIKeyboardType = .default
    var autocapitalization: TextInputAutocapitalization = .sentences

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(.white.opacity(0.6))
                .frame(width: 24)

            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .foregroundStyle(.white)
                .keyboardType(keyboardType)
                .textInputAutocapitalization(autocapitalization)
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
                    .textInputAutocapitalization(.never)
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
                    .foregroundStyle(.cyan)

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

struct AnimatedGradientBackground: View {
    @State private var animateGradient = false

    var body: some View {
        LinearGradient(
            colors: [
                Color(red: 0.1, green: 0.1, blue: 0.3),
                Color(red: 0.2, green: 0.1, blue: 0.4),
                Color(red: 0.1, green: 0.2, blue: 0.3)
            ],
            startPoint: animateGradient ? .topLeading : .bottomLeading,
            endPoint: animateGradient ? .bottomTrailing : .topTrailing
        )
        .ignoresSafeArea()
        .onAppear {
            withAnimation(.easeInOut(duration: 5).repeatForever(autoreverses: true)) {
                animateGradient.toggle()
            }
        }
    }
}

// MARK: - Preview

#Preview("Connect View") {
    ConnectView()
}
