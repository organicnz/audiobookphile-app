import Foundation

/// Defines all strongly-typed API endpoints for the Audiobookphile backend.
public enum APIEndpoint {
    case login
    case authRefresh
    case getLibraries
    case getLibraryItems(libraryId: String)
    case getLibrarySmartSort(libraryId: String)
    case getLibraryDeduplicate(libraryId: String)
    case searchLibrary(libraryId: String)
    case getPersonalized(libraryId: String)
    case getBatchItems
    case searchSemantic
    case chapterAI
    case getBookmarks(libraryItemId: String)
    case createBookmark
    case deleteBookmark(bookmarkId: String)
    case getItemDetails(id: String)
    case downloadItem(libraryItemId: String)
    case syncSession(sessionId: String)
    case bulkSyncSession
    case closeSession(sessionId: String)
    case getCover(itemId: String)
    case getPreferences
    case getLibraryStats(libraryId: String)
    case getAuthors(libraryId: String)
    case getAuthor(authorId: String)
    case getSeries(libraryId: String)
    case getCollections(libraryId: String)
    case getPlaylists(libraryId: String)
    case matchAll(libraryId: String)
    case getMeStats
    case getMe
    case getSimilarItems(itemId: String)
    case getSearchHistory
    case authInvite
    case custom(path: String)
    
    public func urlString(baseURL: String) -> String {
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
    
    private var path: String {
        switch self {
        case .login: return "/login"
        case .authRefresh: return "/auth/refresh"
        case .getLibraries: return "/api/libraries"
        case .getLibraryItems(let libraryId): return "/api/libraries/\(libraryId)/items"
        case .getLibrarySmartSort(let libraryId): return "/api/libraries/\(libraryId)/smart-sort"
        case .getLibraryDeduplicate(let libraryId): return "/api/libraries/\(libraryId)/deduplicate"
        case .searchLibrary(let libraryId): return "/api/libraries/\(libraryId)/search"
        case .getPersonalized(let libraryId): return "/api/libraries/\(libraryId)/personalized"
        case .getBatchItems: return "/api/items/batch"
        case .searchSemantic: return "/search-semantic"
        case .chapterAI: return "/chapter-ai"
        case .getBookmarks(let libraryItemId): return "/api/me/bookmarks?libraryItemId=\(libraryItemId)"
        case .createBookmark: return "/api/me/bookmarks"
        case .deleteBookmark(let bookmarkId): return "/api/me/bookmarks/\(bookmarkId)"
        case .getItemDetails(let id): return "/api/items/\(id)?expanded=1&include=progress"
        case .downloadItem(let libraryItemId): return "/api/items/\(libraryItemId)/download"
        case .syncSession(let sessionId): return "/api/session/\(sessionId)/sync"
        case .bulkSyncSession: return "/api/session/bulk-sync"
        case .closeSession(let sessionId): return "/api/session/\(sessionId)/close"
        case .getCover(let itemId): return "/api/items/\(itemId)/cover"
        case .getPreferences: return "/api/users/me/preferences"
        case .getLibraryStats(let libraryId): return "/api/libraries/\(libraryId)/stats"
        case .getAuthors(let libraryId): return "/api/libraries/\(libraryId)/authors"
        case .getAuthor(let authorId): return "/api/authors/\(authorId)"
        case .getSeries(let libraryId): return "/api/libraries/\(libraryId)/series"
        case .getCollections(let libraryId): return "/api/libraries/\(libraryId)/collections"
        case .getPlaylists(let libraryId): return "/api/libraries/\(libraryId)/playlists"
        case .matchAll(let libraryId): return "/api/libraries/\(libraryId)/matchall"
        case .getMeStats: return "/api/me/stats"
        case .getMe: return "/api/me"
        case .getSimilarItems(let itemId): return "/api/items/\(itemId)/similar"
        case .getSearchHistory: return "/api/me/search/history"
        case .authInvite: return "/api/auth/invite"
        case .custom(let path): return path
        }
    }
}
