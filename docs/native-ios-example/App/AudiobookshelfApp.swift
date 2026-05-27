//
//  AudiobookshelfApp.swift
//  AudiobookshelfClient
//
//  Main app entry point
//

import SwiftUI

@main
struct AudiobookshelfApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .preferredColorScheme(.dark)
                .onAppear {
                    // Enable ProMotion
                    ProMotionManager.shared.enableHighPerformanceMode()
                }
        }
    }
}

// MARK: - App State

@MainActor
class AppState: ObservableObject {
    @Published var isAuthenticated = false
    @Published var isLoading = true
    @Published var currentUser: User?
    @Published var showingPlayer = false
    @Published var selectedLibraryId: String?

    init() {
        checkAuthentication()
    }

    func checkAuthentication() {
        isLoading = true

        // Try to load saved credentials
        if let credentials = try? KeychainManager.shared.loadCredentials() {
            AudiobookshelfAPI.shared.configure(
                serverURL: credentials.serverURL,
                token: credentials.token,
                refreshToken: credentials.refreshToken
            )
            isAuthenticated = true

            // Connect socket
            SocketService.shared.connect(
                serverAddress: credentials.serverURL,
                token: credentials.token
            )
        }

        isLoading = false
    }

    func login(serverURL: String, username: String, password: String) async throws {
        isLoading = true

        do {
            let user = try await AudiobookshelfAPI.shared.login(
                serverURL: serverURL,
                username: username,
                password: password
            )

            currentUser = user
            isAuthenticated = true

            // Connect socket
            SocketService.shared.connect(
                serverAddress: serverURL,
                token: user.token
            )
        } catch {
            isAuthenticated = false
            throw error
        }

        isLoading = false
    }

    func logout() {
        AudiobookshelfAPI.shared.logout()
        isAuthenticated = false
        currentUser = nil
    }
}

// MARK: - Content View

struct ContentView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        ZStack {
            if appState.isLoading {
                LoadingView(message: "Starting up...")
            } else if appState.isAuthenticated {
                MainTabView()
            } else {
                ConnectView()
            }
        }
        .animation(.easeInOut, value: appState.isAuthenticated)
        .animation(.easeInOut, value: appState.isLoading)
    }
}

// MARK: - Main Tab View

struct MainTabView: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject private var audioPlayer = AudioPlayerService.shared
    @State private var selectedTab = 0
    @State private var showFullPlayer = false

    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $selectedTab) {
                // Library Tab
                NavigationStack {
                    BookshelfView()
                        .toolbarBackground(.hidden, for: .navigationBar)
                        .toolbarColorScheme(.dark, for: .navigationBar)
                }
                .tabItem {
                    Label("Library", systemImage: "books.vertical")
                }
                .tag(0)

                // Search Tab
                NavigationStack {
                    SearchView()
                        .toolbarBackground(.hidden, for: .navigationBar)
                        .toolbarColorScheme(.dark, for: .navigationBar)
                }
                .tabItem {
                    Label("Search", systemImage: "magnifyingglass")
                }
                .tag(1)

                // Downloads Tab
                NavigationStack {
                    DownloadsView()
                        .toolbarBackground(.hidden, for: .navigationBar)
                        .toolbarColorScheme(.dark, for: .navigationBar)
                }
                .tabItem {
                    Label("Downloads", systemImage: "arrow.down.circle")
                }
                .tag(2)

                // Settings Tab
                NavigationStack {
                    SettingsView()
                        .toolbarBackground(.hidden, for: .navigationBar)
                        .toolbarColorScheme(.dark, for: .navigationBar)
                }
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
                .tag(3)
            }
            .tint(.cyan)
            .toolbarBackground(Color.appBackground.opacity(0.95), for: .tabBar)
            .toolbarBackground(.visible, for: .tabBar)
            .toolbarColorScheme(.dark, for: .tabBar)

            // Mini Player (when audio is playing)
            if audioPlayer.session != nil && !showFullPlayer {
                MiniPlayerView(
                    audioPlayer: audioPlayer,
                    onTap: {
                        showFullPlayer = true
                    },
                    onClose: {
                        Task {
                            await audioPlayer.closeSession()
                        }
                    }
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .padding(.bottom, 49) // Tab bar height
            }
        }
        .fullScreenCover(isPresented: $showFullPlayer) {
            if let session = audioPlayer.session {
                AudioPlayerView(session: session)
            }
        }
    }
}

// MARK: - Preview

#Preview("App") {
    ContentView()
        .environmentObject(AppState())
}
