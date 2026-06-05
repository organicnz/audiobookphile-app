import sys

path = "Sources/Audiobookphile/Views/AudioPlayerViewModel.swift"
with open(path, "r") as f:
    content = f.read()

methods = """
    public var bookmarks: [Bookmark] {
        AudioPlayerService.shared.getBookmarks(for: session.libraryItemId)
    }
    
    public var hasBookmarks: Bool {
        !bookmarks.isEmpty
    }
    
    public func addBookmark(title: String) {
        AudioPlayerService.shared.addBookmark(title: title)
    }
    
    public func deleteBookmark(_ bookmark: Bookmark) {
        AudioPlayerService.shared.deleteBookmark(bookmark)
    }
"""

if "func addBookmark" not in content:
    content = content.replace("public func setPlaybackRate(_ rate: Float)", methods + "\n    public func setPlaybackRate(_ rate: Float)")
    with open(path, "w") as f:
        f.write(content)
