//
//  ContentView.swift
//  Audiobookphile
//
//  Main application content router, compatible with Swift 6.3 and Skip.
//

import SwiftUI

public struct ContentView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.scenePhase) private var scenePhase

    public init() {}

    public var body: some View {
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
        .preferredColorScheme(.dark)
        .onChange(of: scenePhase) { oldPhase, newPhase in
            if newPhase == .active {
                Task {
                    await appState.refreshSessionIfNeeded()
                }
            }
        }
    }
}

public struct MainTabView: View {
    @Environment(AppState.self) private var appState
    @Environment(AudioPlayerService.self) private var audioPlayer
    @Environment(PlayerCoordinator.self) private var playerCoordinator

    // Value-based navigation paths for deep linking
    @State private var homePath = NavigationPath()
    @State private var libraryPath = NavigationPath()
    @State private var collectionsPath = NavigationPath()
    @State private var downloadsPath = NavigationPath()
    @State private var searchPath = NavigationPath()

    public init() {}

    public var body: some View {
        @Bindable var bindableAppState = appState
        return ZStack(alignment: .bottom) {
            TabView(selection: $bindableAppState.selectedTab) {
                // Home Tab
                NavigationStack(path: $homePath) {
                    HomeView()
                }
                .tabItem {
                    Label("Home", systemImage: "house")
                }
                .tag(0)

                // Library Tab
                NavigationStack(path: $libraryPath) {
                    BookshelfView()
                }
                .tabItem {
                    Label("Library", systemImage: "books.vertical.fill")
                }
                .tag(1)

                // Collections Tab
                NavigationStack(path: $collectionsPath) {
                    CollectionsView()
                }
                .tabItem {
                    Label("Collections", systemImage: "square.stack.3d.up.fill")
                }
                .tag(2)

                // Downloads Tab
                NavigationStack(path: $downloadsPath) {
                    DownloadsView()
                }
                .tabItem {
                    Label("Downloads", systemImage: "arrow.down.circle.fill")
                }
                .tag(3)

                // Search Tab
                NavigationStack(path: $searchPath) {
                    SearchView()
                }
                .tabItem {
                    Label("Search", systemImage: "magnifyingglass")
                }
                .tag(4)
            }
            .tint(.appPrimary)

            // Mini Player (when audio is playing)
            if audioPlayer.session != nil && !playerCoordinator.isPlayerPresented {
                MiniPlayerView(
                    audioPlayer: audioPlayer,
                    onTap: {
                        playerCoordinator.presentPlayer(delayMilliseconds: 0)
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
        #if os(iOS) || SKIP
        .fullScreenCover(isPresented: Bindable(playerCoordinator).isPlayerPresented) {
            if let session = audioPlayer.session {
                AudioPlayerView(session: session)
            }
        }
        #else
        .sheet(isPresented: Bindable(playerCoordinator).isPlayerPresented) {
            if let session = audioPlayer.session {
                AudioPlayerView(session: session)
            }
        }
        #endif
    }
}
