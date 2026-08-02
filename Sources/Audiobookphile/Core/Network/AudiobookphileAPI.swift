//
//  AudiobookphileAPI.swift
//  Audiobookphile
//
//  Complete cross-platform API client with token refresh, error handling, and secure storage.
//  Compatible with Swift 6.3 and Skip.
//

import Foundation
import OSLog
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
#if canImport(Security)
import Security
#endif
import Observation

// MARK: - API Client

public actor AudiobookphileAPI {
    public static let shared = AudiobookphileAPI()

    public var isAuthenticated = false
    public var currentUser: User?

    public var baseURL: String = ""
    public var accessToken: String = ""
    public var refreshToken: String = ""
    public var serverConnectionId: String = ""

    private func endpointUrlString(for path: String) -> String {
        let isDirectSupabase = baseURL.contains(".supabase.co") || baseURL.contains("54321")
        let isVercelProxy = baseURL.contains("vercel.app") || baseURL.hasSuffix("/api")
        let isSupabaseBackend = isDirectSupabase || isVercelProxy

        var base = baseURL
        if isDirectSupabase && !baseURL.contains("/functions/v1") {
            base = "\(baseURL)/functions/v1"
        }

        var adjustedPath = path
        if isSupabaseBackend && !path.starts(with: "/api") {
            adjustedPath = "/api\(path)"
        }

        if base.hasSuffix("/api") && adjustedPath.starts(with: "/api") {
            adjustedPath = String(adjustedPath.dropFirst(4))
        }

        return "\(base)\(adjustedPath)"
    }

    private let session: URLSession
    private var refreshTask: Task<Void, Error>?

    private var defaultDecoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            if container.decodeNil() {
                return Date(timeIntervalSince1970: 0)
            }
            if let timestamp = try? container.decode(Double.self) {
                if timestamp > 100_000_000_000 {
                    return Date(timeIntervalSince1970: timestamp / 1000.0)
                } else {
                    return Date(timeIntervalSince1970: timestamp)
                }
            }
            if let dateString = try? container.decode(String.self) {
                if let doubleVal = Double(dateString) {
                    if doubleVal > 100_000_000_000 {
                        return Date(timeIntervalSince1970: doubleVal / 1000.0)
                    } else {
                        return Date(timeIntervalSince1970: doubleVal)
                    }
                }
                let formatter = ISO8601DateFormatter()
                formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                if let date = formatter.date(from: dateString) {
                    return date
                }
                formatter.formatOptions = [.withInternetDateTime]
                if let date = formatter.date(from: dateString) {
                    return date
                }
            }
            return Date(timeIntervalSince1970: 0)
        }
        return decoder
    }

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 10
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
    public func login(serverURL: String, username: String, password: String) async throws -> LoginResponse {
        self.baseURL = serverURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))

        guard let url = URL(string: endpointUrlString(for: "/login")) else {
            throw APIError.invalidResponse
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let anonKey = EnvironmentConfig.supabaseAnonKey
        if !anonKey.isEmpty {
            request.setValue(anonKey, forHTTPHeaderField: "apikey")
        }

        let body = ["username": username, "password": password]
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            if let errorResponse = try? JSONDecoder().decode(APIErrorResponse.self, from: data), let msg = errorResponse.parsedMessage {
                if httpResponse.statusCode == 401 {
                    throw APIError.authenticationFailed
                }
                throw APIError.serverError(statusCode: httpResponse.statusCode, message: msg, code: errorResponse.error?.code)
            }
            if httpResponse.statusCode == 401 {
                throw APIError.authenticationFailed
            }
            throw APIError.serverError(statusCode: httpResponse.statusCode, message: "Unknown server error", code: nil)
        }

        let decoder = defaultDecoder
        let loginResponse = try decoder.decode(LoginResponse.self, from: data)

        if loginResponse.requires2FA == true {
            return loginResponse
        }

        guard let user = loginResponse.user else {
            throw APIError.invalidResponse
        }

        self.accessToken = user.token
        self.refreshToken = user.refreshToken ?? ""
        self.currentUser = user
        self.isAuthenticated = true

        // Save to Keychain/Secure preferences
        try KeychainManager.shared.saveCredentials(
            serverURL: baseURL,
            token: accessToken,
            refreshToken: refreshToken
        )

        return loginResponse
    }

    /// Complete 2FA challenge during login
    public func verify2FALogin(userId: String, tempToken: String, code: String, method: String? = nil) async throws -> LoginResponse {
        guard let url = URL(string: "\(baseURL)/api/auth/2fa/verify-login") else {
            throw APIError.invalidResponse
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        var body: [String: String] = [
            "userId": userId,
            "tempToken": tempToken,
            "code": code
        ]
        if let method = method {
            body["method"] = method
        }
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        guard (200...299).contains(httpResponse.statusCode) else {
            if let errorResponse = try? JSONDecoder().decode(APIErrorResponse.self, from: data), let msg = errorResponse.parsedMessage {
                throw APIError.serverError(statusCode: httpResponse.statusCode, message: msg, code: nil)
            }
            throw APIError.serverError(statusCode: httpResponse.statusCode, message: "Invalid 2FA code", code: nil)
        }

        let loginResponse = try defaultDecoder.decode(LoginResponse.self, from: data)
        guard let user = loginResponse.user else {
            throw APIError.invalidResponse
        }

        self.accessToken = user.token
        self.refreshToken = user.refreshToken ?? ""
        self.currentUser = user
        self.isAuthenticated = true

        try KeychainManager.shared.saveCredentials(
            serverURL: baseURL,
            token: accessToken,
            refreshToken: refreshToken
        )

        return loginResponse
    }

    /// Enroll in 2FA (generate secret and QR URI)
    public func enroll2FA() async throws -> TwoFactorEnrollResponse {
        return try await executeRequest(try createAuthRequest(path: "/api/auth/2fa/enroll", method: "POST"), responseType: TwoFactorEnrollResponse.self)
    }

    /// Verify code and activate 2FA
    public func verify2FA(code: String) async throws -> TwoFactorActionResponse {
        let body = try JSONEncoder().encode(["code": code])
        return try await executeRequest(try createAuthRequest(path: "/api/auth/2fa/verify", method: "POST", body: body), responseType: TwoFactorActionResponse.self)
    }

    /// Disable 2FA
    public func disable2FA(code: String) async throws -> TwoFactorActionResponse {
        let body = try JSONEncoder().encode(["code": code])
        return try await executeRequest(try createAuthRequest(path: "/api/auth/2fa/disable", method: "POST", body: body), responseType: TwoFactorActionResponse.self)
    }

    /// Enroll PIN Code 2FA
    public func enroll2FAPin(pinCode: String) async throws -> TwoFactorActionResponse {
        let body = try JSONEncoder().encode(["pinCode": pinCode])
        return try await executeRequest(try createAuthRequest(path: "/api/auth/2fa/enroll-pin", method: "POST", body: body), responseType: TwoFactorActionResponse.self)
    }

    /// Enroll Biometric 2FA
    public func enroll2FABiometric(deviceId: String) async throws -> TwoFactorActionResponse {
        let body = try JSONEncoder().encode(["deviceId": deviceId])
        return try await executeRequest(try createAuthRequest(path: "/api/auth/2fa/enroll-biometric", method: "POST", body: body), responseType: TwoFactorActionResponse.self)
    }

    private func createAuthRequest(path: String, method: String, body: Data? = nil) throws -> URLRequest {
        guard let url = URL(string: endpointUrlString(for: path)) else {
            throw APIError.invalidResponse
        }
        var request = URLRequest(url: url)
        request.httpMethod = method
        if let body = body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = body
        }
        return request
    }

    public func logout() {
        accessToken = ""
        refreshToken = ""
        currentUser = nil
        isAuthenticated = false

        Task { @MainActor in
            AppState.shared.isAuthenticated = false
        }

        try? KeychainManager.shared.clearCredentials()
    }

    // MARK: - Token Refresh

    /// Refresh the access token using the refresh token
    /// Manually triggers a token refresh, usually called when returning to the foreground
    public func refreshTokensFromForeground() async throws {
        _ = try await refreshAccessToken()
    }

    private func refreshAccessToken() async throws {
        if let existingTask = refreshTask {
            logger.info("Awaiting existing token refresh task...")
            return try await existingTask.value
        }

        let task = Task<Void, Error> {
            try await self.performRefreshToken()
        }

        refreshTask = task
        defer { refreshTask = nil }
        return try await task.value
    }

    private func performRefreshToken() async throws {
        guard !self.refreshToken.isEmpty else {
            throw APIError.noRefreshToken
        }

        logger.info("Refreshing access token...")

        guard let url = URL(string: endpointUrlString(for: "/auth/refresh")) else {
            throw APIError.invalidResponse
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(self.refreshToken, forHTTPHeaderField: "x-refresh-token")

        let anonKey = EnvironmentConfig.supabaseAnonKey
        if !anonKey.isEmpty {
            request.setValue(anonKey, forHTTPHeaderField: "apikey")
        }
        request.httpBody = "{}".data(using: .utf8)

        let (data, response) = try await self.session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        if (400...403).contains(httpResponse.statusCode) {
            throw APIError.authenticationFailed
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw APIError.serverError(statusCode: httpResponse.statusCode, message: "Token refresh failed", code: nil)
        }

        let decoder = defaultDecoder
        let refreshResponse = try decoder.decode(LoginResponse.self, from: data)

        guard let user = refreshResponse.user else {
            throw APIError.invalidResponse
        }
        self.accessToken = user.token
        // Preserve the existing refresh token if the backend returns nil.
        // The /authorize endpoint returns null when the JWT is still valid
        // and no rotation occurred — discarding it here was causing the iOS
        // client to lose its refresh token and force re-login next session.
        if let newRefreshToken = user.refreshToken, !newRefreshToken.isEmpty {
            self.refreshToken = newRefreshToken
        }

        // Update Keychain/Secure preferences
        try? KeychainManager.shared.saveCredentials(
            serverURL: self.baseURL,
            token: self.accessToken,
            refreshToken: self.refreshToken
        )
        logger.info("Token refreshed successfully")
    }

    // MARK: - Request Execution

    /// Execute an authenticated request with automatic token refresh
    private func executeRequest<T: Decodable>(_ request: URLRequest, responseType: T.Type, isRetry: Bool = false) async throws -> T {
        var authRequest = request
        authRequest.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        authRequest.setValue("Audiobookphile/2026.1 (Apple)", forHTTPHeaderField: "User-Agent")
        authRequest.setValue("2026.07.24", forHTTPHeaderField: "X-App-Version")

        let anonKey = EnvironmentConfig.supabaseAnonKey
        if !anonKey.isEmpty {
            authRequest.setValue(anonKey, forHTTPHeaderField: "apikey")
        }

        var attempts = 0
        let maxAttempts = isRetry ? 1 : 4

        while true {
            attempts += 1
            do {
                let (data, response) = try await session.data(for: authRequest)

                guard let httpResponse = response as? HTTPURLResponse else {
                    throw APIError.invalidResponse
                }

                // Handle 401 or 403 - try token refresh
                if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
                    if isRetry {
                        if httpResponse.statusCode == 401 {
                            logout()
                            throw APIError.sessionExpired
                        } else {
                            throw APIError.serverError(statusCode: 403, message: "Forbidden", code: nil)
                        }
                    }
                    return try await handleUnauthorized(originalRequest: request, responseType: responseType)
                }

                // If 5xx server error, attempt retry with exponential backoff
                if (500...599).contains(httpResponse.statusCode) && attempts < maxAttempts {
                    let delayNano = UInt64(Double(1 << (attempts - 1)) * 1_000_000_000)
                    try? await Task.sleep(nanoseconds: delayNano)
                    continue
                }

                guard (200...299).contains(httpResponse.statusCode) else {
                    if let errorResponse = try? JSONDecoder().decode(APIErrorResponse.self, from: data), let msg = errorResponse.parsedMessage {
                        throw APIError.serverError(statusCode: httpResponse.statusCode, message: msg, code: errorResponse.error?.code)
                    }
                    throw APIError.serverError(statusCode: httpResponse.statusCode, message: "Unknown server error", code: nil)
                }

            let decoder = defaultDecoder

            do {
                // Dump raw JSON for PlaybackSession debugging
                if T.self == PlaybackSession.self {
                    let jsonStr = String(data: data, encoding: .utf8) ?? "unable to decode"
                    let dumpPath = NSTemporaryDirectory() + "playback_session_raw.json"
                    try? jsonStr.write(toFile: dumpPath, atomically: true, encoding: .utf8)
                    logger.info("PlaybackSession raw JSON dumped to: \(dumpPath) (\(data.count) bytes)")
                }
                return try decoder.decode(T.self, from: data)
            } catch let decodingError as DecodingError {
                let errorDetails = "[DecodingError] Details: \(decodingError)\nFor type: \(T.self)\nJSON length: \(data.count) bytes\n"
                if T.self == PlaybackSession.self {
                    let errorPath = NSTemporaryDirectory() + "playback_session_decode_error.txt"
                    try? errorDetails.write(toFile: errorPath, atomically: true, encoding: .utf8)
                }
                try? errorDetails.write(toFile: NSTemporaryDirectory() + "audiobookphile_decoding_error.txt", atomically: true, encoding: .utf8)
                throw decodingError
            } catch {
                throw error
            }

            } catch let error as APIError {
                throw error
            } catch {
                if attempts < maxAttempts {
                    let delayNano = UInt64(Double(1 << (attempts - 1)) * 1_000_000_000)
                    try? await Task.sleep(nanoseconds: delayNano)
                    continue
                }
                throw APIError.networkError(underlying: error)
            }
        }
    }

    /// Handle 401 unauthorized - refresh token and retry
    private func handleUnauthorized<T: Decodable>(originalRequest: URLRequest, responseType: T.Type) async throws -> T {
        do {
            try await refreshAccessToken()
            // Retry original request with new token
            return try await executeRequest(originalRequest, responseType: responseType, isRetry: true)
        } catch APIError.authenticationFailed, APIError.invalidResponse {
            // Refresh explicitly rejected - logout
            logout()
            throw APIError.sessionExpired
        } catch {
            // Other errors (e.g. network offline) - propagate error without logging out
            throw error
        }
    }

    // MARK: - Libraries

    /// Get all libraries
    public func getLibraries() async throws -> [Library] {
        guard let url = URL(string: endpointUrlString(for: "/api/libraries")) else {
            throw APIError.invalidResponse
        }
        let request = URLRequest(url: url)

        let response: LibrariesResponse = try await executeRequest(request, responseType: LibrariesResponse.self)
        return response.libraries
    }

    /// Get library items (books)
    public func getLibraryItems(libraryId: String, limit: Int? = nil, page: Int = 0, sort: String = "addedAt", desc: Bool = true) async throws -> LibraryItemsResponse {
        guard var components = URLComponents(string: endpointUrlString(for: "/api/libraries/\(libraryId)/items")) else {
            throw APIError.invalidResponse
        }
        var queryItems = [
            URLQueryItem(name: "page", value: "\(page)"),
            URLQueryItem(name: "sort", value: sort),
            URLQueryItem(name: "desc", value: desc ? "1" : "0"),
            URLQueryItem(name: "include", value: "progress")
        ]
        if let limit = limit {
            queryItems.append(URLQueryItem(name: "limit", value: "\(limit)"))
        }
        components.queryItems = queryItems

        guard let url = components.url else {
            throw APIError.invalidResponse
        }
        let request = URLRequest(url: url)
        return try await executeRequest(request, responseType: LibraryItemsResponse.self)
    }

    /// Trigger Z.AI smart sorting for library items by criteria
    public func smartSortLibraryItems(libraryId: String, criteria: String = "chronological reading order") async throws -> [String] {
        guard let url = URL(string: endpointUrlString(for: "/api/libraries/\(libraryId)/smart-sort")) else {
            throw APIError.invalidResponse
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: ["criteria": criteria])

        struct SmartSortResponse: Decodable {
            let sortedIds: [String]
            let provider: String?
        }
        let res: SmartSortResponse = try await executeRequest(request, responseType: SmartSortResponse.self)
        return res.sortedIds
    }

    /// Trigger backend deduplication for library items
    public func deduplicateLibraryItems(libraryId: String) async throws -> Int {
        guard let url = URL(string: endpointUrlString(for: "/api/libraries/\(libraryId)/deduplicate")) else {
            throw APIError.invalidResponse
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"

        struct DeduplicateResponse: Decodable {
            let success: Bool
            let removedCount: Int?
        }
        let res: DeduplicateResponse = try await executeRequest(request, responseType: DeduplicateResponse.self)
        return res.removedCount ?? 0
    }

    /// Search library
    public func searchLibrary(libraryId: String, query: String, limit: Int = 12) async throws -> SearchResponse {
        guard var components = URLComponents(string: endpointUrlString(for: "/api/libraries/\(libraryId)/search")) else {
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

    /// Fetch personalized shelves (continue listening, recently added, etc.)
    public func getLibraryPersonalized(libraryId: String) async throws -> [PersonalizedShelf] {
        guard let url = URL(string: endpointUrlString(for: "/api/libraries/\(libraryId)/personalized")) else {
            throw APIError.invalidResponse
        }
        let request = URLRequest(url: url)
        return try await executeRequest(request, responseType: [PersonalizedShelf].self)
    }

    /// Batch fetch multiple library items by IDs in a single HTTP request
    public func getBatchLibraryItems(itemIds: [String]) async throws -> [Book] {
        guard let url = URL(string: endpointUrlString(for: "/api/items/batch")) else {
            throw APIError.invalidResponse
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body = ["itemIds": Array(itemIds.prefix(50))]
        request.httpBody = try JSONEncoder().encode(body)

        struct BatchResponse: Decodable {
            let items: [Book]
        }
        let response: BatchResponse = try await executeRequest(request, responseType: BatchResponse.self)
        return response.items
    }

    private struct SemanticEdgeResponse: Codable, Sendable {
        let results: [Book]?
        let error: String?
    }

    /// Semantic search using Edge Function
    public func searchSemantic(query: String) async throws -> SearchResponse {
        guard let url = URL(string: endpointUrlString(for: "/search-semantic")) else {
            throw APIError.invalidResponse
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = ["query": query]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let response = try await executeRequest(request, responseType: SemanticEdgeResponse.self)

        if let error = response.error {
            throw APIError.serverError(statusCode: 500, message: error, code: nil)
        }

        let items = response.results ?? []
        let searchResults = items.map { book in
            SearchResponse.SearchResult(libraryItem: book, matchKey: "title", matchText: book.media.metadata.title)
        }

        return SearchResponse(results: searchResults)
    }

    public struct ChapterAIInsights: Codable, Sendable {
        public let summary: String
        public let keyTakeaways: [String]
        public let mood: String?
    }

    private struct ChapterAIResponse: Codable, Sendable {
        let insights: ChapterAIInsights?
        let error: String?
    }

    /// Fetch AI insights & chapter summaries using Supabase Edge Function
    public func fetchChapterAIInsights(title: String, author: String?, chapterTitle: String, chapterIndex: Int?) async throws -> ChapterAIInsights {
        guard let url = URL(string: endpointUrlString(for: "/chapter-ai")) else {
            throw APIError.invalidResponse
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        var body: [String: Any] = [
            "title": title,
            "chapterTitle": chapterTitle
        ]
        if let author = author, !author.isEmpty { body["author"] = author }
        if let idx = chapterIndex { body["chapterIndex"] = idx }

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let response = try await executeRequest(request, responseType: ChapterAIResponse.self)
        if let error = response.error {
            throw APIError.serverError(statusCode: 500, message: error, code: nil)
        }
        guard let insights = response.insights else {
            throw APIError.invalidResponse
        }
        return insights
    }

    // MARK: - Bookmarks

    public func fetchBookmarks(libraryItemId: String) async throws -> [Bookmark] {
        guard let url = URL(string: endpointUrlString(for: "/api/me/bookmarks?libraryItemId=\(libraryItemId)")) else {
            throw APIError.invalidResponse
        }
        let request = URLRequest(url: url)
        let response = try await executeRequest(request, responseType: BookmarksResponse.self)
        return response.bookmarks
    }

    public struct BookmarkCreateRequest: Codable {
        let library_item_id: String
        let time_pos: Double
        let title: String?
    }

    public struct SingleBookmarkResponse: Codable {
        let bookmark: Bookmark
    }

    public func createBookmark(libraryItemId: String, timePos: Double, title: String? = nil) async throws -> Bookmark {
        guard let url = URL(string: endpointUrlString(for: "/api/me/bookmarks")) else {
            throw APIError.invalidResponse
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let payload = BookmarkCreateRequest(library_item_id: libraryItemId, time_pos: timePos, title: title)
        request.httpBody = try JSONEncoder().encode(payload)

        let response = try await executeRequest(request, responseType: SingleBookmarkResponse.self)
        return response.bookmark
    }

    public func deleteBookmark(bookmarkId: String) async throws {
        guard let url = URL(string: endpointUrlString(for: "/api/me/bookmarks/\(bookmarkId)")) else {
            throw APIError.invalidResponse
        }
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        _ = try await executeRequest(request, responseType: EmptyResponse.self)
    }

    // MARK: - Library Items

    /// Get single library item
    public func getLibraryItem(id: String) async throws -> Book {
        guard let url = URL(string: endpointUrlString(for: "/api/items/\(id)?expanded=1&include=progress")) else {
            throw APIError.invalidResponse
        }
        let request = URLRequest(url: url)
        return try await executeRequest(request, responseType: Book.self)
    }

    // MARK: - Playback

    /// Start a playback session
    public func getDownloadManifest(libraryItemId: String) async throws -> DownloadManifest {
        guard let url = URL(string: endpointUrlString(for: "/api/items/\(libraryItemId)/download")) else {
            throw APIError.invalidResponse
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        return try await executeRequest(request, responseType: DownloadManifest.self)
    }

    public func startPlaybackSession(libraryItemId: String, episodeId: String? = nil) async throws -> PlaybackSession {
        var path = "/api/items/\(libraryItemId)/play"
        if let episodeId = episodeId {
            path = "/api/items/\(libraryItemId)/play/\(episodeId)"
        }

        guard let url = URL(string: endpointUrlString(for: path)) else {
            throw APIError.invalidResponse
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let deviceInfo: [String: Any] = [
            "clientName": "Audiobookphile iOS (Native SKIP)",
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

    /// Sync playback progress — routes through executeRequest for automatic token refresh
    public func syncProgress(sessionId: String, episodeId: String? = nil, currentTime: TimeInterval, duration: TimeInterval, timeListened: TimeInterval = 0) async throws {
        guard let url = URL(string: endpointUrlString(for: "/api/session/\(sessionId)/sync")) else {
            throw APIError.invalidResponse
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let progress = duration > 0 ? currentTime / duration : 0
        var body: [String: Any] = [
            "currentTime": currentTime,
            "duration": duration,
            "progress": progress,
            "timeListened": timeListened
        ]
        if let episodeId = episodeId {
            body["episodeId"] = episodeId
        }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let _: EmptyResponse = try await executeRequest(request, responseType: EmptyResponse.self)
    }

    /// Bulk sync playback progress — routes through executeRequest for automatic token refresh
    public func bulkSyncProgress(items: [ProgressSyncQueueItem]) async throws -> [String] {
        guard !items.isEmpty else { return [] }

        guard let url = URL(string: endpointUrlString(for: "/api/session/bulk-sync")) else {
            throw APIError.invalidResponse
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let payloads = items.map { item -> [String: Any] in
            let progress = item.duration > 0 ? item.currentTime / item.duration : 0
            var body: [String: Any] = [
                "sessionId": item.sessionId,
                "currentTime": item.currentTime,
                "duration": item.duration,
                "progress": progress,
                "timeListened": item.timeListened
            ]
            if let episodeId = item.episodeId {
                body["episodeId"] = episodeId
            }
            return body
        }

        request.httpBody = try JSONSerialization.data(withJSONObject: payloads)

        let result: BulkSyncResponse = try await executeRequest(request, responseType: BulkSyncResponse.self)
        return result.syncedSessionIds ?? []
    }

    /// Close playback session — routes through executeRequest for automatic token refresh
    public func closePlaybackSession(sessionId: String, episodeId: String? = nil, currentTime: TimeInterval, duration: TimeInterval, timeListened: TimeInterval = 0) async throws {
        guard let url = URL(string: endpointUrlString(for: "/api/session/\(sessionId)/close")) else {
            throw APIError.invalidResponse
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        var body: [String: Any] = [
            "currentTime": currentTime,
            "duration": duration,
            "timeListened": timeListened
        ]
        if let episodeId = episodeId {
            body["episodeId"] = episodeId
        }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let _: EmptyResponse = try await executeRequest(request, responseType: EmptyResponse.self)
    }

    // MARK: - Progress

    /// Get user media progress
    public func getUserProgress(libraryItemId: String, episodeId: String? = nil) async throws -> MediaProgress? {
        var path = "/api/me/progress/\(libraryItemId)"
        if let episodeId = episodeId {
            path += "/\(episodeId)"
        }

        guard let url = URL(string: endpointUrlString(for: path)) else {
            throw APIError.invalidResponse
        }
        let request = URLRequest(url: url)

        do {
            return try await executeRequest(request, responseType: MediaProgress.self)
        } catch APIError.serverError(let statusCode, _, _) where statusCode == 404 {
            return nil
        }
    }

    // MARK: - Cover Images

    /// Get cover image URL
    public func getCoverURL(itemId: String, width: Int = 400, updatedAt: Date? = nil) -> URL? {
        guard var components = URLComponents(string: endpointUrlString(for: "/api/items/\(itemId)/cover")) else {
            return nil
        }
        var queryItems = [
            URLQueryItem(name: "width", value: "\(width)"),
            URLQueryItem(name: "format", value: "jpeg"),
            URLQueryItem(name: "token", value: accessToken)
        ]

        if let updated = updatedAt {
            queryItems.append(URLQueryItem(name: "ts", value: "\(Int(updated.timeIntervalSince1970))"))
        } else {
            // Fallback cache buster if updatedAt isn't provided but we want to avoid stale broken redirects
            queryItems.append(URLQueryItem(name: "ts", value: "1"))
        }

        let anonKey = EnvironmentConfig.supabaseAnonKey
        if !anonKey.isEmpty {
            queryItems.append(URLQueryItem(name: "apikey", value: anonKey))
        }

        components.queryItems = queryItems
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

    // MARK: - Preferences

    public struct PreferencesResponse: Codable, Sendable {
        public let preferences: AppSettings?
    }

    public func getPreferences() async throws -> AppSettings {
        guard let url = URL(string: endpointUrlString(for: "/api/users/me/preferences")) else {
            throw APIError.invalidResponse
        }

        let request = URLRequest(url: url)

        let response = try await executeRequest(request, responseType: PreferencesResponse.self)
        return response.preferences ?? AppSettings()
    }

    public func updatePreferences(_ settings: AppSettings) async throws -> AppSettings {
        guard let url = URL(string: endpointUrlString(for: "/api/users/me/preferences")) else {
            throw APIError.invalidResponse
        }

        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let encoder = JSONEncoder()
        request.httpBody = try encoder.encode(settings)

        let response = try await executeRequest(request, responseType: PreferencesResponse.self)
        return response.preferences ?? settings
    }

    // MARK: - Library Stats

    /// Get library statistics (total items, duration, authors, genres, etc.)
    public func getLibraryStats(libraryId: String) async throws -> LibraryStats {
        guard let url = URL(string: endpointUrlString(for: "/api/libraries/\(libraryId)/stats")) else {
            throw APIError.invalidResponse
        }
        let request = URLRequest(url: url)
        return try await executeRequest(request, responseType: LibraryStats.self)
    }

    // MARK: - Authors

    /// Get paginated authors for a library
    public func getLibraryAuthors(libraryId: String, limit: Int = 24, page: Int = 0, sort: String = "name", desc: Bool = false) async throws -> AuthorsResponse {
        guard var components = URLComponents(string: endpointUrlString(for: "/api/libraries/\(libraryId)/authors")) else {
            throw APIError.invalidResponse
        }
        components.queryItems = [
            URLQueryItem(name: "limit", value: "\(limit)"),
            URLQueryItem(name: "page", value: "\(page)"),
            URLQueryItem(name: "sort", value: sort),
            URLQueryItem(name: "desc", value: desc ? "1" : "0")
        ]
        guard let url = components.url else { throw APIError.invalidResponse }
        let request = URLRequest(url: url)
        return try await executeRequest(request, responseType: AuthorsResponse.self)
    }

    /// Get a single author with their books
    public func getAuthorDetail(authorId: String) async throws -> AuthorSummary {
        guard let url = URL(string: endpointUrlString(for: "/api/authors/\(authorId)")) else {
            throw APIError.invalidResponse
        }
        let request = URLRequest(url: url)
        return try await executeRequest(request, responseType: AuthorSummary.self)
    }

    // MARK: - Series

    /// Get paginated series for a library
    public func getLibrarySeries(libraryId: String, limit: Int = 24, page: Int = 0, sort: String = "name", desc: Bool = false) async throws -> SeriesResponse {
        guard var components = URLComponents(string: endpointUrlString(for: "/api/libraries/\(libraryId)/series")) else {
            throw APIError.invalidResponse
        }
        components.queryItems = [
            URLQueryItem(name: "limit", value: "\(limit)"),
            URLQueryItem(name: "page", value: "\(page)"),
            URLQueryItem(name: "sort", value: sort),
            URLQueryItem(name: "desc", value: desc ? "1" : "0")
        ]
        guard let url = components.url else { throw APIError.invalidResponse }
        let request = URLRequest(url: url)
        return try await executeRequest(request, responseType: SeriesResponse.self)
    }

    // MARK: - Collections

    /// Get paginated collections for a library
    public func getLibraryCollections(libraryId: String, limit: Int = 24, page: Int = 0, sort: String = "name", desc: Bool = false) async throws -> CollectionsResponse {
        guard var components = URLComponents(string: endpointUrlString(for: "/api/libraries/\(libraryId)/collections")) else {
            throw APIError.invalidResponse
        }
        components.queryItems = [
            URLQueryItem(name: "limit", value: "\(limit)"),
            URLQueryItem(name: "page", value: "\(page)"),
            URLQueryItem(name: "sort", value: sort),
            URLQueryItem(name: "desc", value: desc ? "1" : "0")
        ]
        guard let url = components.url else { throw APIError.invalidResponse }
        let request = URLRequest(url: url)
        return try await executeRequest(request, responseType: CollectionsResponse.self)
    }

    // MARK: - Playlists

    /// Get paginated playlists for a library
    public func getLibraryPlaylists(libraryId: String, limit: Int = 24, page: Int = 0, sort: String = "name", desc: Bool = false) async throws -> PlaylistsResponse {
        guard var components = URLComponents(string: endpointUrlString(for: "/api/libraries/\(libraryId)/playlists")) else {
            throw APIError.invalidResponse
        }
        components.queryItems = [
            URLQueryItem(name: "limit", value: "\(limit)"),
            URLQueryItem(name: "page", value: "\(page)"),
            URLQueryItem(name: "sort", value: sort),
            URLQueryItem(name: "desc", value: desc ? "1" : "0")
        ]
        guard let url = components.url else { throw APIError.invalidResponse }
        let request = URLRequest(url: url)
        return try await executeRequest(request, responseType: PlaylistsResponse.self)
    }

    // MARK: - Match All

    /// Trigger metadata matching for all items in a library (runs in background)
    public func triggerMatchAll(libraryId: String) async throws {
        guard let url = URL(string: endpointUrlString(for: "/api/libraries/\(libraryId)/matchall")) else {
            throw APIError.invalidResponse
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        let _: EmptyResponse = try await executeRequest(request, responseType: EmptyResponse.self)
    }

    public func getUserStats() async throws -> UserStatsData {
        guard let url = URL(string: endpointUrlString(for: "/api/me/stats")) else {
            throw APIError.invalidResponse
        }
        let request = URLRequest(url: url)
        return try await executeRequest(request, responseType: UserStatsData.self)
    }

    public func getCurrentUserProfile() async throws -> User {
        guard let url = URL(string: endpointUrlString(for: "/api/me")) else {
            throw APIError.invalidResponse
        }
        let request = URLRequest(url: url)
        let res: LoginResponse = try await executeRequest(request, responseType: LoginResponse.self)
        guard let user = res.user else {
            throw APIError.invalidResponse
        }
        return user
    }

    public func getSimilarItems(itemId: String) async throws -> [Book] {
        guard let url = URL(string: endpointUrlString(for: "/api/items/\(itemId)/similar")) else {
            throw APIError.invalidResponse
        }
        let request = URLRequest(url: url)
        let res: SimilarItemsResponse = try await executeRequest(request, responseType: SimilarItemsResponse.self)
        return res.similarItems
    }

    // MARK: - Search History

    public func fetchSearchHistory() async throws -> [SearchHistoryItem] {
        guard let url = URL(string: endpointUrlString(for: "/api/me/search/history")) else {
            throw APIError.invalidResponse
        }
        let request = URLRequest(url: url)
        let response = try await executeRequest(request, responseType: [SearchHistoryItem].self)
        return response
    }

    public func addSearchHistory(query: String) async throws -> SearchHistoryItem {
        guard let url = URL(string: endpointUrlString(for: "/api/me/search/history")) else {
            throw APIError.invalidResponse
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body = ["query": query]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        return try await executeRequest(request, responseType: SearchHistoryItem.self)
    }

    public func clearSearchHistory() async throws {
        guard let url = URL(string: endpointUrlString(for: "/api/me/search/history")) else {
            throw APIError.invalidResponse
        }
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        _ = try await executeRequest(request, responseType: EmptyResponse.self)
    }

    // MARK: - Admin: Invite User

    /// Invite a new user by email (admin only).
    /// Calls `POST /api/auth/invite` with the current access token.
    public func inviteUser(email: String, username: String? = nil, userType: String = "user") async throws -> InviteUserResponse {
        guard let url = URL(string: endpointUrlString(for: "/api/auth/invite")) else {
            throw APIError.invalidResponse
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        var body: [String: String] = ["email": email, "userType": userType]
        if let username, !username.isEmpty {
            body["username"] = username
        }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        return try await executeRequest(request, responseType: InviteUserResponse.self)
    }
}

// MARK: - Response Models

public struct TwoFactorMethodsMap: Codable, Sendable {
    public let totp: Bool?
    public let pin: Bool?
    public let biometric: Bool?
}

public struct LoginResponse: Codable, Sendable {
    public let user: User?
    public let requires2FA: Bool?
    public let userId: String?
    public let email: String?
    public let tempToken: String?
    public let methods: TwoFactorMethodsMap?
}

public struct TwoFactorEnrollResponse: Codable, Sendable {
    public let secret: String?
    public let uri: String?
    public let error: String?
}

public struct TwoFactorActionResponse: Codable, Sendable {
    public let success: Bool?
    public let error: String?
}

/// Placeholder response for endpoints that return JSON but we don't need to decode.
public struct EmptyResponse: Codable, Sendable {}

public struct InviteUserResponse: Codable, Sendable {
    public let success: Bool?
    public let error: String?
}

public struct BulkSyncResponse: Codable, Sendable {
    public let success: Bool?
    public let syncedSessionIds: [String]?
    public let error: String?
}

public struct LibrariesResponse: Codable, Sendable {
    public let libraries: [Library]
}

public struct LibraryItemsResponse: Codable, Sendable {
    public let results: [Book]
    public let total: Int
    public let limit: Int
    public let page: Int

    enum CodingKeys: String, CodingKey {
        case results, total, limit, page
    }

    public init(results: [Book], total: Int, limit: Int, page: Int) {
        self.results = results
        self.total = total
        self.limit = limit
        self.page = page
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        results = (try container.decodeIfPresent([Book].self, forKey: .results)) ?? []
        total = (try container.decodeIfPresent(Int.self, forKey: .total)) ?? results.count
        limit = (try container.decodeIfPresent(Int.self, forKey: .limit)) ?? 0
        page = (try container.decodeIfPresent(Int.self, forKey: .page)) ?? 0
    }
}

public struct SearchResponse: Codable, Sendable {
    public struct SearchResult: Codable, Sendable {
        public let libraryItem: Book
        public let matchKey: String?
        public let matchText: String?
    }
    public let results: [SearchResult]
}

public struct PersonalizedShelf: Codable, Sendable {
    public let id: String
    public let label: String
    public let labelStringKey: String
    public let type: String
    public let entities: [Book]
    public let total: Int
}

public struct AuthorsResponse: Codable, Sendable {
    public let authors: [AuthorSummary]
    public let total: Int
    public let limit: Int
    public let page: Int
}

public struct SeriesResponse: Codable, Sendable {
    public let results: [SeriesSummary]
    public let total: Int
    public let limit: Int
    public let page: Int
}

public struct CollectionsResponse: Codable, Sendable {
    public let results: [CollectionSummary]
    public let total: Int
    public let limit: Int
    public let page: Int
}

public struct PlaylistsResponse: Codable, Sendable {
    public let results: [PlaylistSummary]
    public let total: Int
    public let limit: Int
    public let page: Int
}

// MARK: - API Errors

public enum APIError: LocalizedError {
    case invalidResponse
    case authenticationFailed
    case serverError(statusCode: Int, message: String, code: String?)
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
        case .serverError(let statusCode, let message, let code):
            if let code = code {
                return "\(message) (\(code))"
            }
            return "\(message) (status: \(statusCode))"
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

    private let serverURLKey = "abp_serverURL"
    private let tokenKey = "abp_token"
    private let refreshTokenKey = "abp_refreshToken"

    public func saveCredentials(serverURL: String, token: String, refreshToken: String) throws {
        #if !SKIP && !os(Android)
        // iOS Keychain Implementation
        // kSecAttrAccessibleAfterFirstUnlock ensures credentials survive device
        // lock/restart cycles. Without this, the default "WhenUnlocked" policy
        // makes credentials unreachable after a device restart until the user
        // unlocks the phone — causing the app to show the login screen.
        let credentials = [
            "serverURL": serverURL,
            "token": token,
            "refreshToken": refreshToken
        ]
        let data = try JSONEncoder().encode(credentials)

        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "com.audiobookphile.native",
            kSecAttrAccount as String: "credentials"
        ]
        SecItemDelete(deleteQuery as CFDictionary)

        var addQuery = deleteQuery
        addQuery[kSecValueData as String] = data
        addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        let status = SecItemAdd(addQuery as CFDictionary, nil)
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
        #if !SKIP && !os(Android)
        // iOS Keychain Retrieval
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "com.audiobookphile.native",
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
        #if !SKIP && !os(Android)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "com.audiobookphile.native",
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
