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

    /// Tracks when the current access token was issued / last refreshed.
    /// Used to proactively refresh before the JWT expires (default 1h).
    private var tokenIssuedAt: Date?

    /// How many seconds before expiry to trigger a proactive refresh.
    /// Default Supabase JWT expiry is 3600s (1h); refresh at 50 min.
    private let proactiveRefreshThreshold: TimeInterval = 50 * 60

    public var currentLibrary: Library? {
        libraries.first { $0.id == currentLibraryId } ?? libraries.first
    }

    public init() {
        Task {
            await checkAuthentication()
        }
    }

    public func checkAuthentication() async {
        isLoading = true

        // Try to load saved credentials
        if let credentials = try? KeychainManager.shared.loadCredentials() {
            // Migration check: If the saved server is not the new Supabase backend, clear it.
            if !credentials.serverURL.contains("supabase.co") && !credentials.serverURL.contains("vercel.app") {
                print("[AppState] Found old non-Supabase server credentials. Migrating/Clearing...")
                logout()
                isLoading = false
                return
            }

            self.serverURL = credentials.serverURL
            self.token = credentials.token

            isAuthenticated = true
            tokenIssuedAt = Date()

            // Connect socket (no-op)
            SocketService.shared.connect(
                serverAddress: credentials.serverURL,
                token: credentials.token
            )

            await AudiobookphileAPI.shared.configure(
                serverURL: credentials.serverURL,
                token: credentials.token,
                refreshToken: credentials.refreshToken
            )

            // Await library fetch so currentLibraryId is set before
            // isLoading is cleared — otherwise BookshelfView renders
            // with a nil libraryId and shows no books.
            await fetchLibraries()
        } else {
            isAuthenticated = false
        }

        isLoading = false
    }

    /// Called when the app returns to foreground (ScenePhase.active / onResume).
    /// Silently refreshes the access token if it's likely expired without
    /// disrupting the UI or showing the login screen for transient errors.
    public func refreshSessionIfNeeded() async {
        guard isAuthenticated else { return }

        let needsRefresh: Bool
        if let issued = tokenIssuedAt {
            needsRefresh = Date().timeIntervalSince(issued) > proactiveRefreshThreshold
        } else {
            // No recorded issue time — always refresh to be safe
            needsRefresh = true
        }

        guard needsRefresh else {
            print("[AppState] Token still fresh, skipping foreground refresh.")
            return
        }

        print("[AppState] Token likely expired, attempting silent foreground refresh...")

        do {
            // The API client's internal refresh will use the stored refresh token,
            // get new tokens, and persist them to Keychain.
            try await AudiobookphileAPI.shared.refreshTokensFromForeground()
            tokenIssuedAt = Date()
            print("[AppState] Silent foreground token refresh succeeded.")
        } catch let error as APIError {
            switch error {
            case .authenticationFailed, .sessionExpired, .noRefreshToken:
                // Refresh token is genuinely invalid — must re-login
                print("[AppState] Refresh token rejected, logging out: \(error)")
                logout()
            default:
                // Network error, timeout, etc. — don't log out, retry later
                print("[AppState] Foreground refresh failed (transient): \(error)")
            }
        } catch {
            // Non-API error (network, etc.) — don't log out
            print("[AppState] Foreground refresh failed (transient): \(error)")
        }
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

    public func getCoverURL(itemId: String, width: Int = 400, updatedAt: Date? = nil) -> URL? {
        guard !serverURL.isEmpty else { return nil }

        let isDirectSupabase = serverURL.contains(".supabase.co") || serverURL.contains("54321")
        var base = serverURL
        if isDirectSupabase && !serverURL.contains("/functions/v1") {
            base = "\(serverURL)/functions/v1"
        }

        var adjustedPath = "/api/items/\(itemId)/cover"
        if base.hasSuffix("/api") && adjustedPath.starts(with: "/api") {
            adjustedPath = String(adjustedPath.dropFirst(4))
        }

        let endpoint = base.hasSuffix("/") ? "\(base)\(adjustedPath.dropFirst())" : "\(base)\(adjustedPath)"
        guard var components = URLComponents(string: endpoint) else { return nil }

        var queryItems = [
            URLQueryItem(name: "width", value: "\(width)"),
            URLQueryItem(name: "format", value: "jpeg"),
            URLQueryItem(name: "token", value: token)
        ]

        if let updated = updatedAt {
            queryItems.append(URLQueryItem(name: "ts", value: "\(Int(updated.timeIntervalSince1970))"))
        } else {
            queryItems.append(URLQueryItem(name: "ts", value: "1"))
        }

        let anonKey = EnvironmentConfig.supabaseAnonKey
        if !anonKey.isEmpty {
            queryItems.append(URLQueryItem(name: "apikey", value: anonKey))
        }

        components.queryItems = queryItems
        return components.url
    }
}
