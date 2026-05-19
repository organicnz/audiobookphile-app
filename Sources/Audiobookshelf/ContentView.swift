//
//  ContentView.swift
//  Audiobookshelf
//
//  Main application content router, compatible with Swift 6.3 and Skip.
//

import SwiftUI

public struct ContentView: View {
    @State var appState = AppState.shared

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
    }
}

public struct MainTabView: View {
    @State var appState = AppState.shared
    @State var audioPlayer = AudioPlayerService.shared
    @State var selectedTab = 0
    @State var showFullPlayer = false

    public init() {}

    public var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $selectedTab) {
                // Library Tab
                NavigationStack {
                    BookshelfView()
                        #if os(iOS) || SKIP
                        .toolbarBackground(.hidden, for: .navigationBar)
                        .toolbarColorScheme(.dark, for: .navigationBar)
                        #endif
                }
                .tabItem {
                    Label("Library", systemImage: "books.vertical")
                }
                .tag(0)

                // Search Tab
                NavigationStack {
                    SearchView()
                        #if os(iOS) || SKIP
                        .toolbarBackground(.hidden, for: .navigationBar)
                        .toolbarColorScheme(.dark, for: .navigationBar)
                        #endif
                }
                .tabItem {
                    Label("Search", systemImage: "magnifyingglass")
                }
                .tag(1)

                // Downloads Tab
                NavigationStack {
                    DownloadsView()
                        #if os(iOS) || SKIP
                        .toolbarBackground(.hidden, for: .navigationBar)
                        .toolbarColorScheme(.dark, for: .navigationBar)
                        #endif
                }
                .tabItem {
                    Label("Downloads", systemImage: "arrow.down.circle")
                }
                .tag(2)

                // Settings Tab
                NavigationStack {
                    SettingsView()
                        #if os(iOS) || SKIP
                        .toolbarBackground(.hidden, for: .navigationBar)
                        .toolbarColorScheme(.dark, for: .navigationBar)
                        #endif
                }
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
                .tag(3)
            }
            .tint(.cyan)

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
        #if os(iOS) || SKIP
        .fullScreenCover(isPresented: $showFullPlayer) {
            if let session = audioPlayer.session {
                AudioPlayerView(session: session)
            }
        }
        #else
        .sheet(isPresented: $showFullPlayer) {
            if let session = audioPlayer.session {
                AudioPlayerView(session: session)
            }
        }
        #endif
    }
}
