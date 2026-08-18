//
//  AuthViewModel.swift
//  Audiobookphile
//
//  View model exposing the authentication flows (login, 2FA, session
//  restore and logout) to SwiftUI views.
//

import Foundation
import Observation

@MainActor
@Observable
public final class AuthViewModel: BaseViewModel {
    public static let shared = AuthViewModel()

    // MARK: - Derived state

    /// Whether the user currently has a valid session.
    public var isAuthenticated: Bool { AppState.shared.isAuthenticated }

    /// The server the app is currently connected to.
    public var serverURL: String { AppState.shared.serverURL }

    /// The signed-in user, if any.
    public var currentUser: User? { AppState.shared.currentUser }

    /// Whether a 2FA challenge is awaiting completion.
    public var requires2FAChallenge: Bool { AppState.shared.requires2FAChallenge }

    /// The 2FA methods offered by the server for the pending challenge.
    public var pending2FAMethods: TwoFactorMethodsMap? { AppState.shared.pending2FAMethods }

    // MARK: - Session management

    /// Restores a persisted session on launch, if one exists.
    public func checkAuthentication() async {
        await AppState.shared.checkAuthentication()
    }

    /// Silently refreshes the access token when it is likely expired.
    public func refreshSessionIfNeeded() async {
        await AppState.shared.refreshSessionIfNeeded()
    }

    // MARK: - Sign in

    /// Signs in with a username and password, or starts a 2FA challenge
    /// when the server requires one.
    public func login(serverURL: String, username: String, password: String) async {
        await perform {
            try await AppState.shared.login(serverURL: serverURL, username: username, password: password)
        }
    }

    /// Completes a pending 2FA challenge with a verification code.
    public func verify2FAChallenge(code: String, method: String? = nil) async {
        await perform {
            try await AppState.shared.verify2FAChallenge(code: code, method: method)
        }
    }

    /// Completes a pending 2FA challenge using a native passkey.
    public func verify2FAPasskey() async {
        await perform {
            try await AppState.shared.verify2FAPasskey()
        }
    }

    /// Abandons the pending 2FA challenge.
    public func cancel2FAChallenge() {
        AppState.shared.cancel2FAChallenge()
    }

    // MARK: - Sign out

    /// Clears the session, keychain credentials and cached server state.
    public func logout() {
        AppState.shared.logout()
    }
}
