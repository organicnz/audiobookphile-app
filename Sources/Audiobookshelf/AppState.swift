//
//  AppState.swift
//  Audiobookshelf
//
//  Shared application state, compatible with Swift 6.3 and Skip.
//

import Foundation
import Observation
import SkipFuse
import SwiftUI

@Observable
@MainActor
public class AppState {
    public static let shared = AppState()

    public var isAuthenticated = false
    public var isLoading = true
    public var currentUser: User?
    public var showingPlayer = false
    public var selectedLibraryId: String?

    public init() {
        checkAuthentication()
    }

    public func checkAuthentication() {
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
        } else {
            isAuthenticated = false
        }

        isLoading = false
    }

    public func login(serverURL: String, username: String, password: String) async throws {
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
            isLoading = false
            throw error
        }

        isLoading = false
    }

    public func logout() {
        AudiobookshelfAPI.shared.logout()
        SocketService.shared.disconnect()
        isAuthenticated = false
        currentUser = nil
    }
}
