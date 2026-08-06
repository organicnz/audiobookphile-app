import Foundation
import Observation

/// Handles authentication, token refresh, and login workflows.
@MainActor
public class AuthManager {
    public static let shared = AuthManager()
    
    private let proactiveRefreshThreshold: TimeInterval = 50 * 60
    private var tokenIssuedAt: Date?
    
    public init() {}
    
    public func checkAuthentication(appState: AppState) async {
        appState.isLoading = true
        
        if let credentials = try? KeychainManager.shared.loadCredentials() {
            if !credentials.serverURL.contains("supabase.co") && !credentials.serverURL.contains("vercel.app") {
                print("[AuthManager] Found old non-Supabase server credentials. Migrating/Clearing...")
                logout(appState: appState)
                appState.isLoading = false
                return
            }

            appState.serverURL = credentials.serverURL
            appState.token = credentials.token
            appState.isAuthenticated = true
            tokenIssuedAt = Date()

            SocketService.shared.connect(
                serverAddress: credentials.serverURL,
                token: credentials.token
            )

            await AudiobookphileAPI.shared.configure(
                serverURL: credentials.serverURL,
                token: credentials.token,
                refreshToken: credentials.refreshToken
            )

            do {
                appState.currentUser = try await AudiobookphileAPI.shared.getCurrentUserProfile()
            } catch {
                print("[AuthManager] Failed to fetch current user profile: \(error)")
                appState.currentUser = User(
                    id: "local_user",
                    username: "audiobookphile",
                    email: nil,
                    type: "admin",
                    token: credentials.token,
                    refreshToken: credentials.refreshToken,
                    mediaProgress: [],
                    seriesHideFromContinueListening: [],
                    bookmarks: [],
                    isActive: true,
                    isLocked: false,
                    lastSeen: nil,
                    createdAt: Date(),
                    permissions: UserPermissions(download: true, update: true, delete: true, upload: true, accessAllLibraries: true, accessAllTags: true, accessExplicitContent: true, createEreader: true, selectedTagsNotAccessible: nil),
                    librariesAccessible: [],
                    itemTagsAccessible: [],
                    hasOpenIDLink: nil,
                    isOldToken: nil
                )
            }

            do {
                appState.settings = try await AudiobookphileAPI.shared.getPreferences()
            } catch {
                print("[AuthManager] Failed to fetch preferences on launch: \(error)")
            }

            await appState.fetchLibraries()
        } else {
            appState.isAuthenticated = false
        }

        appState.isLoading = false
    }

    public func refreshSessionIfNeeded(appState: AppState) async {
        guard appState.isAuthenticated else { return }

        let needsRefresh: Bool
        if let issued = tokenIssuedAt {
            needsRefresh = Date().timeIntervalSince(issued) > proactiveRefreshThreshold
        } else {
            needsRefresh = true
        }

        guard needsRefresh else {
            print("[AuthManager] Token still fresh, skipping foreground refresh.")
            return
        }

        print("[AuthManager] Token likely expired, attempting silent foreground refresh...")

        do {
            try await AudiobookphileAPI.shared.refreshTokensFromForeground()
            tokenIssuedAt = Date()
            print("[AuthManager] Silent foreground token refresh succeeded.")
        } catch let error as APIError {
            switch error {
            case .authenticationFailed, .sessionExpired, .noRefreshToken:
                print("[AuthManager] Refresh token rejected, logging out: \(error)")
                logout(appState: appState)
            default:
                print("[AuthManager] Foreground refresh failed (transient): \(error)")
            }
        } catch {
            print("[AuthManager] Foreground refresh failed (transient): \(error)")
        }
    }

    public func login(serverURL: String, username: String, password: String, appState: AppState) async throws {
        appState.isLoading = true

        do {
            let loginResponse = try await AudiobookphileAPI.shared.login(
                serverURL: serverURL,
                username: username,
                password: password
            )

            if loginResponse.requires2FA == true, let userId = loginResponse.userId, let tempToken = loginResponse.tempToken {
                appState.pending2FAUserId = userId
                appState.pending2FATempToken = tempToken
                appState.pending2FAServerURL = serverURL
                appState.pending2FAMethods = loginResponse.methods
                appState.requires2FAChallenge = true
                appState.isLoading = false
                return
            }

            guard let user = loginResponse.user else {
                throw APIError.invalidResponse
            }

            appState.serverURL = serverURL
            appState.token = user.token
            appState.currentUser = user
            appState.isAuthenticated = true

            SocketService.shared.connect(
                serverAddress: serverURL,
                token: user.token
            )

            do {
                appState.settings = try await AudiobookphileAPI.shared.getPreferences()
            } catch {
                print("[AuthManager] Failed to fetch preferences on login: \(error)")
            }

            await appState.fetchLibraries()
        } catch {
            appState.isAuthenticated = false
            appState.isLoading = false
            throw error
        }

        appState.isLoading = false
    }

    public func verify2FAChallenge(code: String, method: String? = nil, appState: AppState) async throws {
        guard let userId = appState.pending2FAUserId, let tempToken = appState.pending2FATempToken, let serverURL = appState.pending2FAServerURL else {
            return
        }
        appState.isLoading = true
        do {
            let loginResponse = try await AudiobookphileAPI.shared.verify2FALogin(
                userId: userId,
                tempToken: tempToken,
                code: code,
                method: method
            )
            guard let user = loginResponse.user else {
                throw APIError.invalidResponse
            }
            appState.serverURL = serverURL
            appState.token = user.token
            appState.currentUser = user
            appState.isAuthenticated = true
            appState.requires2FAChallenge = false
            appState.pending2FAUserId = nil
            appState.pending2FATempToken = nil
            appState.pending2FAServerURL = nil
            appState.pending2FAMethods = nil

            SocketService.shared.connect(
                serverAddress: serverURL,
                token: user.token
            )

            do {
                appState.settings = try await AudiobookphileAPI.shared.getPreferences()
            } catch {
                print("[AuthManager] Failed to fetch preferences after 2FA login: \(error)")
            }

            await appState.fetchLibraries()
        } catch {
            appState.isLoading = false
            throw error
        }
        appState.isLoading = false
    }

    public func logout(appState: AppState) {
        Task {
            await AudiobookphileAPI.shared.logout()
        }
        SocketService.shared.disconnect()
        appState.isAuthenticated = false
        appState.currentUser = nil
        appState.libraries = []
        appState.currentLibraryId = nil
        appState.serverURL = ""
        appState.token = ""
        appState.settings = AppSettings()
        UserDefaults.standard.removeObject(forKey: StorageKeys.lastLibraryId)
    }
}
