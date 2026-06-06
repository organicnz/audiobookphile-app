//
//  AppState.swift
//  Audiobookphile
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
    
    public var serverURL: String = ""
    public var token: String = ""

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
            // Migration check: If the saved server is not the new Supabase backend, clear it.
            if !credentials.serverURL.contains("supabase.co") {
                print("[AppState] Found old non-Supabase server credentials. Migrating/Clearing...")
                logout()
                isLoading = false
                return
            }

            self.serverURL = credentials.serverURL
            self.token = credentials.token
            
            Task {
                await AudiobookphileAPI.shared.configure(
                serverURL: credentials.serverURL,
                token: credentials.token,
                refreshToken: credentials.refreshToken
            )
            }
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
            let fetched = try await AudiobookphileAPI.shared.getLibraries()
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
            let user = try await AudiobookphileAPI.shared.login(
                serverURL: serverURL,
                username: username,
                password: password
            )

            self.serverURL = serverURL
            self.token = user.token

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
        Task {
            await AudiobookphileAPI.shared.logout()
        }
        SocketService.shared.disconnect()
        isAuthenticated = false
        currentUser = nil
        libraries = []
        currentLibraryId = nil
        serverURL = ""
        token = ""
    }
    
    public func getCoverURL(itemId: String, width: Int = 400) -> URL? {
        guard !serverURL.isEmpty, !token.isEmpty else { return nil }
        guard var components = URLComponents(string: "\(serverURL)/api/items/\(itemId)/cover") else {
            return nil
        }
        components.queryItems = [
            URLQueryItem(name: "width", value: "\(width)"),
            URLQueryItem(name: "format", value: "jpeg"),
            URLQueryItem(name: "token", value: token)
        ]
        return components.url
    }
}

