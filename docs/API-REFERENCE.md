# 📝 Complete API Reference - Audiobookphile REST API

## 🎯 Everything You Need for iOS Integration

This document contains EVERY API endpoint needed for the iOS app, with exact request/response examples.

---

## 🔐 Authentication

### POST /login

**Description:** Authenticate and get user token

**Request:**

```json
{
  "username": "user",
  "password": "password"
}
```

**Response (200):**

```json
{
  "user": {
    "id": "root",
    "username": "root",
    "type": "root",
    "token": "eyJhbGciOiJI...",
    "mediaProgress": [],
    "seriesHideFromContinueListening": [],
    "bookmarks": [],
    "isActive": true,
    "isLocked": false,
    "lastSeen": 1672531200000,
    "createdAt": 1672531200000,
    "permissions": {
      "download": true,
      "update": true,
      "delete": true,
      "upload": true,
      "accessAllLibraries": true,
      "accessAllTags": true,
      "accessExplicitContent": true
    },
    "librariesAccessible": [],
    "itemTagsAccessible": []
  }
}
```

**iOS Implementation:**

```swift
func login(serverURL: String, username: String, password: String) async throws -> User {
    let url = URL(string: "\(serverURL)/login")!
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")

    let body = ["username": username, "password": password]
    request.httpBody = try JSONEncoder().encode(body)

    let (data, response) = try await URLSession.shared.data(for: request)

    guard let httpResponse = response as? HTTPURLResponse,
          (200...299).contains(httpResponse.statusCode) else {
        throw APIError.authenticationFailed
    }

    let loginResponse = try JSONDecoder().decode(LoginResponse.self, from: data)
    return loginResponse.user
}
```

---

## 📚 Libraries

### GET /api/libraries

**Description:** Get all libraries user has access to

**Headers:**

```
Authorization: Bearer {token}
```

**Response (200):**

```json
{
  "libraries": [
    {
      "id": "lib_1",
      "name": "Audiobooks",
      "folders": [
        {
          "id": "fol_1",
          "fullPath": "/audiobooks",
          "libraryId": "lib_1",
          "addedAt": 1672531200000
        }
      ],
      "displayOrder": 1,
      "icon": "audiobookphile",
      "mediaType": "book",
      "provider": "audible",
      "settings": {
        "coverAspectRatio": 1,
        "disableWatcher": false,
        "skipMatchingMediaWithAsin": false,
        "skipMatchingMediaWithIsbn": false,
        "autoScanCronExpression": null
      },
      "createdAt": 1672531200000,
      "lastUpdate": 1672531200000
    }
  ]
}
```

---

## 📖 Library Items

### GET /api/libraries/{id}/items

**Description:** Get items in a library (books/audiobooks)

**Query Parameters:**

- `limit` (int) - Items per page (default: 50)
- `page` (int) - Page number (default: 0)
- `sort` (string) - Sort field (media.metadata.title, addedAt, etc.)
- `desc` (int) - 1 for descending, 0 for ascending
- `filter` (string) - Filter query
- `minified` (int) - 1 for minified response
- `collapseseries` (int) - 1 to collapse series
- `include` (string) - Comma-separated: rssfeed, progress, authors

**Headers:**

```
Authorization: Bearer {token}
```

**Response (200):**

```json
{
  "results": [
    {
      "id": "li_1",
      "libraryId": "lib_1",
      "folderId": "fol_1",
      "path": "/audiobooks/Book Title",
      "relPath": "Book Title",
      "addedAt": 1672531200000,
      "updatedAt": 1672531200000,
      "media": {
        "metadata": {
          "title": "The Midnight Library",
          "subtitle": null,
          "authorName": "Matt Haig",
          "narratorName": "Carey Mulligan",
          "seriesName": null,
          "genres": ["Fiction", "Philosophy"],
          "publishedYear": "2020",
          "publishedDate": null,
          "publisher": "Penguin Random House",
          "description": "A novel about...",
          "isbn": "9780525559474",
          "asin": "B084DQK7TL",
          "language": "en",
          "explicit": false
        },
        "coverPath": "/metadata/items/li_1/cover.jpg",
        "tags": ["favorite"],
        "audioFiles": [
          {
            "index": 1,
            "ino": "1",
            "metadata": {
              "filename": "01 - Chapter 1.mp3",
              "ext": ".mp3",
              "path": "/audiobooks/Book Title/01 - Chapter 1.mp3",
              "relPath": "01 - Chapter 1.mp3",
              "size": 5242880,
              "mtimeMs": 1672531200000,
              "ctimeMs": 1672531200000,
              "birthtimeMs": 1672531200000
            },
            "duration": 1800.0,
            "bitRate": 128000,
            "language": "en",
            "codec": "mp3",
            "mimeType": "audio/mpeg"
          }
        ],
        "chapters": [
          {
            "id": 0,
            "title": "Chapter 1",
            "start": 0,
            "end": 1800
          }
        ],
        "duration": 28800.0,
        "size": 167772160,
        "ebookFile": null
      },
      "userMediaProgress": {
        "id": "mp_1",
        "libraryItemId": "li_1",
        "episodeId": null,
        "duration": 28800.0,
        "progress": 0.5,
        "currentTime": 14400.0,
        "isFinished": false,
        "hideFromContinueListening": false,
        "lastUpdate": 1672531200000,
        "startedAt": 1672531200000,
        "finishedAt": null
      }
    }
  ],
  "total": 100,
  "limit": 50,
  "page": 0,
  "sortBy": "addedAt",
  "sortDesc": true,
  "filterBy": "all",
  "mediaType": "book",
  "minified": false,
  "collapseseries": false,
  "include": "progress"
}
```

**iOS Implementation:**

```swift
func getLibraryItems(libraryId: String, limit: Int = 50, page: Int = 0) async throws -> [Book] {
    var components = URLComponents(string: "\(baseURL)/api/libraries/\(libraryId)/items")!
    components.queryItems = [
        URLQueryItem(name: "limit", value: "\(limit)"),
        URLQueryItem(name: "page", value: "\(page)"),
        URLQueryItem(name: "include", value: "progress")
    ]

    var request = URLRequest(url: components.url!)
    request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

    let (data, _) = try await URLSession.shared.data(for: request)

    let decoder = JSONDecoder()
    decoder.keyDecodingStrategy = .convertFromSnakeCase
    decoder.dateDecodingStrategy = .custom { decoder in
        let container = try decoder.singleValueContainer()
        let milliseconds = try container.decode(Double.self)
        return Date(timeIntervalSince1970: milliseconds / 1000.0)
    }

    let response = try decoder.decode(LibraryItemsResponse.self, from: data)
    return response.results
}
```

---

## 🎵 Playback

### POST /api/items/{id}/play

**Description:** Start a playback session

**Headers:**

```
Authorization: Bearer {token}
Content-Type: application/json
```

**Request Body:**

```json
{
  "deviceInfo": {
    "clientName": "AudiobookphileClient iOS",
    "deviceId": "device_id_here"
  },
  "forceDirectPlay": false,
  "forceTranscode": false,
  "supportedMimeTypes": ["audio/mpeg", "audio/mp4", "audio/flac"]
}
```

**Response (200):**

```json
{
  "id": "play_session_id",
  "userId": "user_id",
  "libraryId": "lib_1",
  "libraryItemId": "li_1",
  "episodeId": null,
  "mediaType": "book",
  "mediaMetadata": {
    "title": "The Midnight Library",
    "subtitle": null,
    "authorName": "Matt Haig",
    "narratorName": "Carey Mulligan"
  },
  "chapters": [
    {
      "id": 0,
      "title": "Chapter 1",
      "start": 0,
      "end": 1800
    }
  ],
  "displayTitle": "The Midnight Library",
  "displayAuthor": "Matt Haig",
  "coverPath": "/metadata/items/li_1/cover.jpg",
  "duration": 28800.0,
  "playMethod": 0,
  "mediaPlayer": "html5",
  "audioTracks": [
    {
      "index": 0,
      "startOffset": 0,
      "duration": 28800.0,
      "title": "The Midnight Library",
      "contentUrl": "http://server/api/items/li_1/file/file_id",
      "mimeType": "audio/mpeg",
      "codec": "mp3"
    }
  ],
  "currentTime": 0,
  "playbackRate": 1.0,
  "startedAt": 1672531200000,
  "updatedAt": 1672531200000
}
```

---

## 📊 Progress Sync

### POST /api/session/{id}/sync

**Description:** Sync playback progress

**Headers:**

```
Authorization: Bearer {token}
Content-Type: application/json
```

**Request Body:**

```json
{
  "currentTime": 14400.0,
  "duration": 28800.0,
  "progress": 0.5,
  "timeListened": 100.0
}
```

**Response (200):**

```json
{
  "success": true
}
```

**iOS Implementation:**

```swift
func syncProgress(sessionId: String, currentTime: TimeInterval, duration: TimeInterval) async throws {
    let url = URL(string: "\(baseURL)/api/session/\(sessionId)/sync")!
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")

    let progress = duration > 0 ? currentTime / duration : 0
    let body: [String: Any] = [
        "currentTime": currentTime,
        "duration": duration,
        "progress": progress
    ]
    request.httpBody = try JSONSerialization.data(withJSONObject: body)

    _ = try await URLSession.shared.data(for: request)
}
```

---

## 🔍 Search

### GET /api/libraries/{id}/search

**Description:** Search within a library

**Query Parameters:**

- `q` (string) - Search query
- `limit` (int) - Max results (default: 12)

**Headers:**

```
Authorization: Bearer {token}
```

**Response (200):**

```json
{
  "results": [
    {
      "libraryItem": {
        /* Same as library item response */
      },
      "matchKey": "media.metadata.title",
      "matchText": "The Midnight Library"
    }
  ]
}
```

---

## 📥 Download

### GET /api/items/{id}/file/{fileId}

**Description:** Download audio file

**Headers:**

```
Authorization: Bearer {token}
Range: bytes=0-1023  (optional, for streaming)
```

**Response (200):** Binary audio data with appropriate Content-Type header

**iOS Implementation:**

```swift
func downloadAudioFile(itemId: String, fileId: String, to destination: URL, progress: @escaping (Double) -> Void) async throws {
    let url = URL(string: "\(baseURL)/api/items/\(itemId)/file/\(fileId)")!
    var request = URLRequest(url: url)
    request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

    let (asyncBytes, response) = try await URLSession.shared.bytes(for: request)

    guard let httpResponse = response as? HTTPURLResponse,
          (200...299).contains(httpResponse.statusCode) else {
        throw APIError.downloadFailed
    }

    let totalBytes = httpResponse.expectedContentLength
    var downloadedBytes: Int64 = 0

    let fileHandle = try FileHandle(forWritingTo: destination)

    for try await byte in asyncBytes {
        downloadedBytes += 1
        fileHandle.write(Data([byte]))

        if downloadedBytes % 1024 == 0 {  // Update every KB
            progress(Double(downloadedBytes) / Double(totalBytes))
        }
    }

    try fileHandle.close()
}
```

---

## 📷 Cover Images

### GET /api/items/{id}/cover

**Description:** Get book cover image

**Query Parameters:**

- `width` (int) - Resize width
- `height` (int) - Resize height
- `format` (string) - jpeg, webp, png
- `raw` (int) - 1 for original file

**Headers:**

```
Authorization: Bearer {token}
```

**Response (200):** Binary image data

**iOS Implementation:**

```swift
func getCoverURL(itemId: String, width: Int = 400) -> URL? {
    var components = URLComponents(string: "\(baseURL)/api/items/\(itemId)/cover")!
    components.queryItems = [
        URLQueryItem(name: "width", value: "\(width)"),
        URLQueryItem(name: "format", value: "jpeg"),
        URLQueryItem(name: "token", value: token)  // For AsyncImage
    ]
    return components.url
}

// Usage with SwiftUI
AsyncImage(url: getCoverURL(itemId: book.id))
```

---

## 🔌 WebSocket

### Connect to /socket.io/

**Description:** Real-time updates for progress, library changes, etc.

**Connection:**

```swift
import SocketIO

class SocketService {
    private var manager: SocketManager?
    private var socket: SocketIOClient?

    func connect(serverURL: String, token: String) {
        let url = URL(string: serverURL)!
        manager = SocketManager(
            socketURL: url,
            config: [
                .log(false),
                .compress,
                .connectParams(["token": token])
            ]
        )

        socket = manager?.defaultSocket

        socket?.on(clientEvent: .connect) { data, ack in
            print("Socket connected")
        }

        socket?.on("user_item_progress_updated") { data, ack in
            // Handle progress update
            if let progressData = data.first as? [String: Any] {
                self.handleProgressUpdate(progressData)
            }
        }

        socket?.connect()
    }

    private func handleProgressUpdate(_ data: [String: Any]) {
        // Update local progress
    }
}
```

**Events to Listen For:**

- `user_item_progress_updated` - Progress synced from another device
- `item_updated` - Library item changed
- `item_added` - New item added
- `item_removed` - Item deleted

---

## 🛡️ Error Handling

### Common HTTP Status Codes

**401 Unauthorized:**

```json
{
  "error": "Unauthorized"
}
```

**Action:** Re-authenticate

**404 Not Found:**

```json
{
  "error": "Not found"
}
```

**Action:** Show error to user

**500 Server Error:**

```json
{
  "error": "Internal server error"
}
```

**Action:** Retry with exponential backoff

**iOS Error Handling:**

```swift
enum APIError: Error {
    case networkError
    case authenticationFailed
    case notFound
    case serverError
    case decodingError

    var localizedDescription: String {
        switch self {
        case .networkError:
            return "Network connection failed"
        case .authenticationFailed:
            return "Login failed. Check credentials."
        case .notFound:
            return "Resource not found"
        case .serverError:
            return "Server error. Try again later."
        case .decodingError:
            return "Data parsing error"
        }
    }
}
```

---

## 📝 Complete APIClient Implementation

See `SPEED-RUN.md` Day 1 for complete implementation.

---

## 🎯 Testing Endpoints

**Recommended Testing Order:**

1. ✅ POST /login
2. ✅ GET /api/libraries
3. ✅ GET /api/libraries/{id}/items
4. ✅ POST /api/items/{id}/play
5. ✅ POST /api/session/{id}/sync
6. ✅ GET /api/items/{id}/cover

**Test Server:** Use your own Audiobookphile server or demo server

---

_Complete API documentation: https://api.audiobookphile.org/_
