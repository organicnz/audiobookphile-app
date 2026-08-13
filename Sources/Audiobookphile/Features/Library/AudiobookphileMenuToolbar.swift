//
//  AudiobookphileMenuToolbar.swift
//  Audiobookphile
//
//  AudioBooth-style Server & Library Menu Toolbar and Settings/Stats Navigation items.
//  Compatible with Swift 6.3 and Skip.
//

import SwiftUI

@MainActor
public struct AudiobookphileMenuToolbar: ViewModifier {
    @Environment(AppState.self) private var appState
    let title: String

    public init(title: String) {
        self.title = title
    }

    public func body(content: Content) -> some View {
        @Bindable var bindableAppState = appState
        
        content
            .navigationTitle(title)
            #if os(iOS) || SKIP
            .navigationBarTitleDisplayMode(.large)
            #endif
            .toolbar {
                audiobookphileServerMenuToolbarItem(
                    appState: appState,
                    showingAccount: Bindable(bindableAppState.navigation).showingAccount,
                    showingConnectModal: Bindable(bindableAppState.navigation).showingConnectModal
                )
                audiobookphileTrailingToolbarItems(
                    showingStats: Bindable(bindableAppState.navigation).showingStats,
                    showingSettings: Bindable(bindableAppState.navigation).showingSettings
                )
            }
    }
}

public extension View {
    /// Applies AudioBooth-styled top-bar navigation menus (library switcher pill & settings/stats gear).
    @MainActor
    func audiobookphileNavigationToolbar(title: String) -> some View {
        modifier(AudiobookphileMenuToolbar(title: title))
    }
}

private var leadingToolbarPlacement: ToolbarItemPlacement {
    #if os(iOS) || SKIP
    return .topBarLeading
    #else
    return .navigation
    #endif
}

private var trailingToolbarPlacement: ToolbarItemPlacement {
    #if os(iOS) || SKIP
    return .topBarTrailing
    #else
    return .primaryAction
    #endif
}

@MainActor
@ToolbarContentBuilder
public func audiobookphileServerMenuToolbarItem(
    appState: AppState,
    showingAccount: Binding<Bool>,
    showingConnectModal: Binding<Bool>
) -> some ToolbarContent {
    ToolbarItem(placement: leadingToolbarPlacement) {
        Menu {
            Section("Current Library") {
                ForEach(appState.libraries) { library in
                    Button {
                        appState.currentLibraryId = library.id
                    } label: {
                        HStack {
                            Text(library.name)
                            if library.id == appState.currentLibraryId {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            }

            Section("Server Connection") {
                Label(
                    appState.serverURL.isEmpty ? "No Server Connected" : appState.serverURL,
                    systemImage: "server.rack"
                )
                Button {
                    showingConnectModal.wrappedValue = true
                } label: {
                    Label("Manage / Connect Server", systemImage: "server.rack")
                }
                Button {
                    showingAccount.wrappedValue = true
                } label: {
                    Label("Account & Server Details", systemImage: "person.crop.circle")
                }
            }

            Section("Session") {
                Button(role: .destructive) {
                    appState.logout()
                } label: {
                    Label("Log Out / Disconnect", systemImage: "rectangle.portrait.and.arrow.right")
                }
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "server.rack")
                    .font(.subheadline)
                    .foregroundStyle(Color.appPrimary)
                Text(appState.currentLibrary?.name ?? "All Books")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundStyle(Color.textPrimary)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundStyle(Color.appPrimary)
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 10)
            .background(Color.appSecondaryBackground.opacity(0.85))
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(Color.appPrimary.opacity(0.4), lineWidth: 1)
            )
        }
    }
}

@MainActor
@ToolbarContentBuilder
public func audiobookphileTrailingToolbarItems(
    showingStats: Binding<Bool>,
    showingSettings: Binding<Bool>
) -> some ToolbarContent {
    ToolbarItem(placement: trailingToolbarPlacement) {
        HStack(spacing: 16) {
            Button {
                showingStats.wrappedValue = true
            } label: {
                Image(systemName: "chart.bar.fill")
                    .font(.subheadline)
            }
            .tint(.primary)

            Button {
                showingSettings.wrappedValue = true
            } label: {
                Image(systemName: "gear")
                    .font(.subheadline)
            }
            .accessibilityIdentifier("abp_settings_button")
            .tint(.primary)
        }
    }
}
