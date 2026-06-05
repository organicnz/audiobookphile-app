import sys

path = "Sources/Audiobookphile/AudioPlayerService.swift"
with open(path, "r") as f:
    content = f.read()

bookmark_methods = """
    // MARK: - Bookmarks
    
    private let bookmarksKeyPrefix = "abs_bookmarks_"
    
    public func getBookmarks(for libraryItemId: String) -> [Bookmark] {
        guard let data = UserDefaults.standard.data(forKey: bookmarksKeyPrefix + libraryItemId),
              let bookmarks = try? JSONDecoder().decode([Bookmark].self, from: data) else {
            return []
        }
        return bookmarks.sorted(by: { $0.time < $1.time })
    }
    
    public func addBookmark(title: String) {
        guard let session = session else { return }
        let newBookmark = Bookmark(
            libraryItemId: session.libraryItemId,
            title: title.isEmpty ? "Bookmark at \(formatTime(currentTime))" : title,
            time: currentTime
        )
        
        var currentBookmarks = getBookmarks(for: session.libraryItemId)
        currentBookmarks.append(newBookmark)
        
        if let data = try? JSONEncoder().encode(currentBookmarks) {
            UserDefaults.standard.set(data, forKey: bookmarksKeyPrefix + session.libraryItemId)
        }
    }
    
    public func deleteBookmark(_ bookmark: Bookmark) {
        var currentBookmarks = getBookmarks(for: bookmark.libraryItemId)
        currentBookmarks.removeAll { $0.id == bookmark.id }
        
        if let data = try? JSONEncoder().encode(currentBookmarks) {
            UserDefaults.standard.set(data, forKey: bookmarksKeyPrefix + bookmark.libraryItemId)
        }
    }
    
    private func formatTime(_ time: TimeInterval) -> String {
        let hours = Int(time) / 3600
        let minutes = Int(time) / 60 % 60
        let seconds = Int(time) % 60
        if hours > 0 {
            return String(format: "%i:%02i:%02i", hours, minutes, seconds)
        } else {
            return String(format: "%02i:%02i", minutes, seconds)
        }
    }
"""

if "MARK: - Bookmarks" not in content:
    content = content.replace("// MARK: - Sleep Timer", bookmark_methods + "\n    // MARK: - Sleep Timer")
    with open(path, "w") as f:
        f.write(content)
