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
    public var selectedLibraryId: String?
    public var selectedTab = 0
    
    // Real API loaded libraries
    public var libraries: [Library] = []
    public var currentLibraryId: String?

    public var currentLibrary: Library? {
        libraries.first { $0.id == currentLibraryId } ?? libraries.first
    }

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

            // Connect socket (no-op)
            SocketService.shared.connect(
                serverAddress: credentials.serverURL,
                token: credentials.token
            )
            
            // Asynchronously validate token by fetching libraries
            Task {
                await fetchLibraries()
            }
        } else {
            isAuthenticated = false
        }

        isLoading = false
    }

    public func fetchLibraries() async {
        do {
            let fetched = try await AudiobookshelfAPI.shared.getLibraries()
            self.libraries = fetched
            if self.currentLibraryId == nil {
                self.currentLibraryId = fetched.first?.id
            }
            print("[AppState] Successfully fetched \(fetched.count) libraries.")
        } catch {
            print("[AppState] Failed to fetch libraries: \(error)")
            // If unauthorized/authenticated failed, log out
            if let apiError = error as? APIError {
                switch apiError {
                case .authenticationFailed, .sessionExpired:
                    logout()
                case .serverError(let statusCode, _, let code):
                    if statusCode == 401 || code == "UNAUTHORIZED" {
                        logout()
                    }
                default:
                    break
                }
            }
        }
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

            // Connect socket (no-op)
            SocketService.shared.connect(
                serverAddress: serverURL,
                token: user.token
            )
            
            // Fetch libraries immediately
            await fetchLibraries()
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
        libraries = []
        currentLibraryId = nil
    }
}

