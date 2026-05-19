//
//  AudiobookshelfAPI.swift
//  Audiobookshelf
//
//  Complete cross-platform API client with token refresh, error handling, and secure storage.
//  Compatible with Swift 6.3 and Skip.
//

import Foundation
#if canImport(Security)
import Security
#endif

// MARK: - API Client

@MainActor
public class AudiobookshelfAPI: ObservableObject {
    public static let shared = AudiobookshelfAPI()

    @Published public var isAuthenticated = false
    @Published public var currentUser: User?

    public var baseURL: String = ""
    public var accessToken: String = ""
    public var refreshToken: String = ""
    public var serverConnectionId: String = ""

    private let session: URLSession
    private var isRefreshingToken = false

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 300
        self.session = URLSession(configuration: config)
    }

    // MARK: - Configuration

    public func configure(serverURL: String, token: String, refreshToken: String = "", connectionId: String = "") {
        self.baseURL = serverURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        self.accessToken = token
        self.refreshToken = refreshToken
        self.serverConnectionId = connectionId
        self.isAuthenticated = !token.isEmpty
    }

    // MARK: - Authentication

    /// Authenticate with username and password
    public func login(serverURL: String, username: String, password: String) async throws -> User {
        self.baseURL = serverURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))

        guard let url = URL(string: "\(baseURL)/login") else {
            throw APIError.invalidResponse
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body = ["username": username, "password": password]
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            if httpResponse.statusCode == 401 {
                throw APIError.authenticationFailed
            }
            throw APIError.serverError(statusCode: httpResponse.statusCode)
        }

        let loginResponse = try JSONDecoder().decode(LoginResponse.self, from: data)

        self.accessToken = loginResponse.user.token
        self.refreshToken = loginResponse.user.refreshToken ?? ""
        self.currentUser = loginResponse.user
        self.isAuthenticated = true

        // Save to Keychain/Secure preferences
        try KeychainManager.shared.saveCredentials(
            serverURL: baseURL,
            token: accessToken,
            refreshToken: refreshToken
        )

        return loginResponse.user
    }

    /// Logout and clear credentials
    public func logout() {
        accessToken = ""
        refreshToken = ""
        currentUser = nil
        isAuthenticated = false

        try? KeychainManager.shared.clearCredentials()
    }

    // MARK: - Token Refresh

    /// Refresh the access token using the refresh token
    private func refreshAccessToken() async throws {
        guard !refreshToken.isEmpty else {
            throw APIError.noRefreshToken
        }

        print("[API] Refreshing access token...")

        guard let url = URL(string: "\(baseURL)/auth/refresh") else {
            throw APIError.invalidResponse
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(refreshToken, forHTTPHeaderField: "x-refresh-token")
        request.httpBody = "{}".data(using: .utf8)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw APIError.tokenRefreshFailed
        }

        let refreshResponse = try JSONDecoder().decode(LoginResponse.self, from: data)

        self.accessToken = refreshResponse.user.token
        if let newRefreshToken = refreshResponse.user.refreshToken {
            self.refreshToken = newRefreshToken
        }

        // Update Keychain/Secure preferences
        try KeychainManager.shared.saveCredentials(
            serverURL: baseURL,
            token: accessToken,
            refreshToken: self.refreshToken
        )

        print("[API] Token refreshed successfully")
    }

    // MARK: - Request Execution

    /// Execute an authenticated request with automatic token refresh
    private func executeRequest<T: Decodable>(_ request: URLRequest, responseType: T.Type) async throws -> T {
        var authRequest = request
        authRequest.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        do {
            let (data, response) = try await session.data(for: authRequest)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.invalidResponse
            }

            // Handle 401 - try token refresh
            if httpResponse.statusCode == 401 {
                return try await handleUnauthorized(originalRequest: request, responseType: responseType)
            }

            guard (200...299).contains(httpResponse.statusCode) else {
                throw APIError.serverError(statusCode: httpResponse.statusCode)
            }

            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            decoder.dateDecodingStrategy = .custom { decoder in
                let container = try decoder.singleValueContainer()
                let timestamp = try container.decode(Double.self)
                return Date(timeIntervalSince1970: timestamp / 1000.0)
            }

            return try decoder.decode(T.self, from: data)

        } catch let error as APIError {
            throw error
        } catch {
            throw APIError.networkError(underlying: error)
        }
    }

    /// Handle 401 unauthorized - refresh token and retry
    private func handleUnauthorized<T: Decodable>(originalRequest: URLRequest, responseType: T.Type) async throws -> T {
        // Prevent multiple simultaneous refresh attempts
        if isRefreshingToken {
            // Wait for refresh to complete, then retry
            try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
            return try await executeRequest(originalRequest, responseType: responseType)
        }

        isRefreshingToken = true
        defer { isRefreshingToken = false }

        do {
            try await refreshAccessToken()
            // Retry original request with new token
            return try await executeRequest(originalRequest, responseType: responseType)
        } catch {
            // Refresh failed - logout
            logout()
            throw APIError.sessionExpired
        }
    }

    // MARK: - Libraries

    /// Get all libraries
    public func getLibraries() async throws -> [Library] {
        guard let url = URL(string: "\(baseURL)/api/libraries") else {
            throw APIError.invalidResponse
        }
        let request = URLRequest(url: url)

        let response: LibrariesResponse = try await executeRequest(request, responseType: LibrariesResponse.self)
        return response.libraries
    }

    /// Get library items (books)
    public func getLibraryItems(libraryId: String, limit: Int = 50, page: Int = 0, sort: String = "addedAt", desc: Bool = true) async throws -> LibraryItemsResponse {
        guard var components = URLComponents(string: "\(baseURL)/api/libraries/\(libraryId)/items") else {
            throw APIError.invalidResponse
        }
        components.queryItems = [
            URLQueryItem(name: "limit", value: "\(limit)"),
            URLQueryItem(name: "page", value: "\(page)"),
            URLQueryItem(name: "sort", value: sort),
            URLQueryItem(name: "desc", value: desc ? "1" : "0"),
            URLQueryItem(name: "include", value: "progress")
        ]

        guard let url = components.url else {
            throw APIError.invalidResponse
        }
        let request = URLRequest(url: url)
        return try await executeRequest(request, responseType: LibraryItemsResponse.self)
    }

    /// Search library
    public func searchLibrary(libraryId: String, query: String, limit: Int = 12) async throws -> SearchResponse {
        guard var components = URLComponents(string: "\(baseURL)/api/libraries/\(libraryId)/search") else {
            throw APIError.invalidResponse
        }
        components.queryItems = [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "limit", value: "\(limit)")
        ]

        guard let url = components.url else {
            throw APIError.invalidResponse
        }
        let request = URLRequest(url: url)
        return try await executeRequest(request, responseType: SearchResponse.self)
    }

    // MARK: - Library Items

    /// Get single library item
    public func getLibraryItem(id: String) async throws -> Book {
        guard let url = URL(string: "\(baseURL)/api/items/\(id)?expanded=1&include=progress") else {
            throw APIError.invalidResponse
        }
        let request = URLRequest(url: url)
        return try await executeRequest(request, responseType: Book.self)
    }

    // MARK: - Playback

    /// Start a playback session
    public func startPlaybackSession(libraryItemId: String, episodeId: String? = nil) async throws -> PlaybackSession {
        var urlString = "\(baseURL)/api/items/\(libraryItemId)/play"
        if let episodeId = episodeId {
            urlString = "\(baseURL)/api/items/\(libraryItemId)/play/\(episodeId)"
        }

        guard let url = URL(string: urlString) else {
            throw APIError.invalidResponse
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let deviceInfo: [String: Any] = [
            "clientName": "Audiobookshelf iOS (Native SKIP)",
            "deviceId": getDeviceId()
        ]
        let body: [String: Any] = [
            "deviceInfo": deviceInfo,
            "mediaPlayer": "SKIP-ExoPlayer",
            "forceDirectPlay": true
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        return try await executeRequest(request, responseType: PlaybackSession.self)
    }

    /// Sync playback progress
    public func syncProgress(sessionId: String, currentTime: TimeInterval, duration: TimeInterval, timeListened: TimeInterval = 0) async throws {
        guard let url = URL(string: "\(baseURL)/api/session/\(sessionId)/sync") else {
            throw APIError.invalidResponse
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        let progress = duration > 0 ? currentTime / duration : 0
        let body: [String: Any] = [
            "currentTime": currentTime,
            "duration": duration,
            "progress": progress,
            "timeListened": timeListened
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (_, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw APIError.syncFailed
        }
    }

    /// Close playback session
    public func closePlaybackSession(sessionId: String, currentTime: TimeInterval, duration: TimeInterval) async throws {
        guard let url = URL(string: "\(baseURL)/api/session/\(sessionId)/close") else {
            throw APIError.invalidResponse
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        let body: [String: Any] = [
            "currentTime": currentTime,
            "duration": duration
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        _ = try await session.data(for: request)
    }

    // MARK: - Progress

    /// Get user media progress
    public func getUserProgress(libraryItemId: String, episodeId: String? = nil) async throws -> MediaProgress? {
        var urlString = "\(baseURL)/api/me/progress/\(libraryItemId)"
        if let episodeId = episodeId {
            urlString += "/\(episodeId)"
        }

        guard let url = URL(string: urlString) else {
            throw APIError.invalidResponse
        }
        let request = URLRequest(url: url)

        do {
            return try await executeRequest(request, responseType: MediaProgress.self)
        } catch APIError.serverError(statusCode: 404) {
            return nil
        }
    }

    // MARK: - Cover Images

    /// Get cover image URL
    public func getCoverURL(itemId: String, width: Int = 400) -> URL? {
        guard var components = URLComponents(string: "\(baseURL)/api/items/\(itemId)/cover") else {
            return nil
        }
        components.queryItems = [
            URLQueryItem(name: "width", value: "\(width)"),
            URLQueryItem(name: "format", value: "jpeg"),
            URLQueryItem(name: "token", value: accessToken)
        ]
        return components.url
    }

    // MARK: - Helpers

    private func getDeviceId() -> String {
        if let deviceId = UserDefaults.standard.string(forKey: "absDeviceId") {
            return deviceId
        }
        let newId = UUID().uuidString
        UserDefaults.standard.set(newId, forKey: "absDeviceId")
        return newId
    }
}

// MARK: - Response Models

public struct LoginResponse: Codable {
    public let user: User
}

public struct LibrariesResponse: Codable {
    public let libraries: [Library]
}

public struct LibraryItemsResponse: Codable {
    public let results: [Book]
    public let total: Int
    public let limit: Int
    public let page: Int
}

public struct SearchResponse: Codable {
    public struct SearchResult: Codable {
        public let libraryItem: Book
        public let matchKey: String?
        public let matchText: String?
    }
    public let results: [SearchResult]
}

// MARK: - API Errors

public enum APIError: LocalizedError {
    case invalidResponse
    case authenticationFailed
    case serverError(statusCode: Int)
    case networkError(underlying: Error)
    case noRefreshToken
    case tokenRefreshFailed
    case sessionExpired
    case syncFailed

    public var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid response from server"
        case .authenticationFailed:
            return "Authentication failed. Check your credentials."
        case .serverError(let statusCode):
            return "Server error (status: \(statusCode))"
        case .networkError(let underlying):
            return "Network error: \(underlying.localizedDescription)"
        case .noRefreshToken:
            return "No refresh token available"
        case .tokenRefreshFailed:
            return "Failed to refresh authentication"
        case .sessionExpired:
            return "Your session has expired. Please login again."
        case .syncFailed:
            return "Failed to sync progress"
        }
    }
}

// MARK: - Keychain Manager

public final class KeychainManager: Sendable {
    public static let shared = KeychainManager()
    private init() {}

    private let serverURLKey = "abs_serverURL"
    private let tokenKey = "abs_token"
    private let refreshTokenKey = "abs_refreshToken"

    public func saveCredentials(serverURL: String, token: String, refreshToken: String) throws {
        #if !SKIP
        // iOS Keychain Implementation
        let credentials = [
            "serverURL": serverURL,
            "token": token,
            "refreshToken": refreshToken
        ]
        let data = try JSONEncoder().encode(credentials)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "com.audiobookshelf.native",
            kSecAttrAccount as String: "credentials",
            kSecValueData as String: data
        ]

        SecItemDelete(query as CFDictionary)
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.saveFailed
        }
        #else
        // Android Safe SharedPreferences Store
        UserDefaults.standard.set(serverURL, forKey: serverURLKey)
        UserDefaults.standard.set(token, forKey: tokenKey)
        UserDefaults.standard.set(refreshToken, forKey: refreshTokenKey)
        #endif
    }

    public func loadCredentials() throws -> (serverURL: String, token: String, refreshToken: String)? {
        #if !SKIP
        // iOS Keychain Retrieval
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "com.audiobookshelf.native",
            kSecAttrAccount as String: "credentials",
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data,
              let credentials = try? JSONDecoder().decode([String: String].self, from: data),
              let serverURL = credentials["serverURL"],
              let token = credentials["token"] else {
            return nil
        }

        return (serverURL, token, credentials["refreshToken"] ?? "")
        #else
        // Android Secure SharedPreferences Retrieval
        guard let serverURL = UserDefaults.standard.string(forKey: serverURLKey),
              let token = UserDefaults.standard.string(forKey: tokenKey) else {
            return nil
        }
        let refreshToken = UserDefaults.standard.string(forKey: refreshTokenKey) ?? ""
        return (serverURL, token, refreshToken)
        #endif
    }

    public func clearCredentials() throws {
        #if !SKIP
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "com.audiobookshelf.native",
            kSecAttrAccount as String: "credentials"
        ]
        SecItemDelete(query as CFDictionary)
        #else
        UserDefaults.standard.removeObject(forKey: serverURLKey)
        UserDefaults.standard.removeObject(forKey: tokenKey)
        UserDefaults.standard.removeObject(forKey: refreshTokenKey)
        #endif
    }

    public enum KeychainError: Error {
        case saveFailed
        case loadFailed
    }
}
