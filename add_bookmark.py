import sys
import os

path = "Sources/Audiobookphile/Models.swift"
with open(path, "r") as f:
    content = f.read()

bookmark_struct = """
public struct Bookmark: Codable, Identifiable, Hashable, Equatable {
    public let id: UUID
    public let libraryItemId: String
    public let title: String
    public let time: TimeInterval
    public let createdAt: Date
    
    public init(id: UUID = UUID(), libraryItemId: String, title: String, time: TimeInterval, createdAt: Date = Date()) {
        self.id = id
        self.libraryItemId = libraryItemId
        self.title = title
        self.time = time
        self.createdAt = createdAt
    }
}
"""

if "struct Bookmark" not in content:
    content += "\n" + bookmark_struct + "\n"
    with open(path, "w") as f:
        f.write(content)
