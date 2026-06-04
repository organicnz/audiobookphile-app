//
//  DownloadService.swift
//  AudiobookphileClient
//
//  Download and offline content management
//

import Foundation
import Combine

/// Service for managing downloads and offline content
@MainActor
class DownloadService: ObservableObject {
    static let shared = DownloadService()

    // MARK: - Published State

    @Published var downloads: [Download] = []
    @Published var activeDownloads: [String: DownloadTask] = [:]
    @Published var downloadQueue: [String] = []
    @Published var isDownloading = false

    // MARK: - Private Properties

    private let fileManager = FileManager.default
    private var urlSession: URLSession!
    private var cancellables = Set<AnyCancellable>()

    // Download directory
    private var downloadsDirectory: URL {
        let paths = fileManager.urls(for: .documentDirectory, in: .userDomainMask)
        return paths[0].appendingPathComponent("Downloads", isDirectory: true)
    }

    // MARK: - Initialization

    private init() {
        setupURLSession()
        createDownloadsDirectory()
        loadDownloads()
    }

    private func setupURLSession() {
        let config = URLSessionConfiguration.default
        urlSession = URLSession(configuration: config, delegate: nil, delegateQueue: nil)
    }

    private func createDownloadsDirectory() {
        try? fileManager.createDirectory(at: downloadsDirectory, withIntermediateDirectories: true)
    }

    // MARK: - Download Management

    /// Start downloading a book
    func downloadBook(_ book: Book) async throws {
        guard !isDownloaded(bookId: book.id) else {
            throw DownloadError.alreadyDownloaded
        }

        guard !isDownloading(bookId: book.id) else {
            throw DownloadError.alreadyDownloading
        }

        // Check network conditions
        let networkMonitor = NetworkMonitor.shared
        if networkMonitor.isMetered && !UserDefaults.standard.bool(forKey: StorageKeys.downloadUsingCellular) {
            throw DownloadError.cellularNotAllowed
        }

        // Start playback session to get audio URLs
        let session = try await AudiobookphileAPI.shared.startPlaybackSession(libraryItemId: book.id)

        let audioTracks = session.audioTracks
        guard !audioTracks.isEmpty else {
            throw DownloadError.noAudioTracks
        }

        // Create download record
        let download = Download(
            id: UUID().uuidString,
            libraryItemId: book.id,
            title: book.title,
            author: book.author ?? "Unknown",
            coverPath: nil,
            totalSize: 0,
            downloadedSize: 0,
            status: .pending,
            createdAt: Date(),
            audioTracks: audioTracks.map { $0.contentUrl }
        )

        downloads.append(download)
        saveDownloads()

        // Add to queue
        downloadQueue.append(book.id)
        processQueue()
    }

    /// Cancel an active download
    func cancelDownload(bookId: String) {
        if let task = activeDownloads[bookId] {
            task.task.cancel()
            activeDownloads.removeValue(forKey: bookId)
        }

        downloadQueue.removeAll { $0 == bookId }

        if let index = downloads.firstIndex(where: { $0.libraryItemId == bookId }) {
            downloads[index].status = .cancelled
        }

        saveDownloads()
    }

    /// Delete a downloaded book
    func deleteDownload(bookId: String) throws {
        guard let download = downloads.first(where: { $0.libraryItemId == bookId }) else {
            throw DownloadError.notFound
        }

        // Delete files
        let bookDirectory = downloadsDirectory.appendingPathComponent(bookId)
        try? fileManager.removeItem(at: bookDirectory)

        // Remove from list
        downloads.removeAll { $0.libraryItemId == bookId }
        saveDownloads()
    }

    /// Retry a failed download
    func retryDownload(bookId: String) async throws {
        guard let download = downloads.first(where: { $0.libraryItemId == bookId }),
              download.status == .failed else {
            throw DownloadError.notFound
        }

        // Reset status
        if let index = downloads.firstIndex(where: { $0.libraryItemId == bookId }) {
            downloads[index].status = .pending
            downloads[index].downloadedSize = 0
        }

        downloadQueue.append(bookId)
        processQueue()
    }

    // MARK: - Queue Processing

    private func processQueue() {
        guard !downloadQueue.isEmpty, activeDownloads.count < 2 else { return }

        let bookId = downloadQueue.removeFirst()
        guard let download = downloads.first(where: { $0.libraryItemId == bookId }) else { return }

        let task = Task {
            await startDownload(download)
        }
        activeDownloads[bookId] = DownloadTask(task: task, bookId: bookId)
    }

    private func startDownload(_ download: Download) async {
        guard let index = downloads.firstIndex(where: { $0.id == download.id }) else { return }

        downloads[index].status = .downloading
        isDownloading = true

        let bookDirectory = downloadsDirectory.appendingPathComponent(download.libraryItemId)
        try? fileManager.createDirectory(at: bookDirectory, withIntermediateDirectories: true)

        // Download each audio track
        for (trackIndex, trackPath) in download.audioTracks.enumerated() {
            let serverURL = UserDefaults.standard.string(forKey: StorageKeys.serverURL) ?? ""
            guard let url = URL(string: "\(serverURL)\(trackPath)") else { continue }

            var request = URLRequest(url: url)
            if let credentials = try? KeychainManager.shared.loadCredentials() {
                request.setValue("Bearer \(credentials.token)", forHTTPHeaderField: "Authorization")
            }

            if Task.isCancelled { break }

            let destination = bookDirectory.appendingPathComponent("track_\(trackIndex).m4a")

            do {
                let (tempURL, _) = try await urlSession.download(for: request)
                if Task.isCancelled { break }
                try fileManager.moveItem(at: tempURL, to: destination)

                // Update progress
                let fileSize = (try? fileManager.attributesOfItem(atPath: destination.path)[.size] as? Int64) ?? 0
                downloads[index].downloadedSize += fileSize

            } catch {
                if Task.isCancelled { break }
                downloads[index].status = .failed
                downloads[index].error = error.localizedDescription
                saveDownloads()
                activeDownloads.removeValue(forKey: download.libraryItemId)
                processQueue()
                return
            }
        }

        if Task.isCancelled {
            // Clean up files if cancelled mid-way
            try? fileManager.removeItem(at: bookDirectory)
            activeDownloads.removeValue(forKey: download.libraryItemId)
            return
        }

        // Download complete
        downloads[index].status = .completed
        downloads[index].completedAt = Date()
        activeDownloads.removeValue(forKey: download.libraryItemId)

        if activeDownloads.isEmpty {
            isDownloading = false
        }

        saveDownloads()
        processQueue()
    }

    // MARK: - Status Checks

    func isDownloaded(bookId: String) -> Bool {
        downloads.first { $0.libraryItemId == bookId && $0.status == .completed } != nil
    }

    func isDownloading(bookId: String) -> Bool {
        downloads.first { $0.libraryItemId == bookId && $0.status == .downloading } != nil
    }

    func downloadProgress(bookId: String) -> Double {
        guard let download = downloads.first(where: { $0.libraryItemId == bookId }),
              download.totalSize > 0 else { return 0 }
        return Double(download.downloadedSize) / Double(download.totalSize)
    }

    func getLocalPath(bookId: String) -> URL? {
        guard isDownloaded(bookId: bookId) else { return nil }
        return downloadsDirectory.appendingPathComponent(bookId)
    }

    // MARK: - Persistence

    private func loadDownloads() {
        let downloadsFile = downloadsDirectory.appendingPathComponent("downloads.json")
        guard let data = try? Data(contentsOf: downloadsFile),
              let loaded = try? JSONDecoder().decode([Download].self, from: data) else { return }
        downloads = loaded
    }

    private func saveDownloads() {
        let downloadsFile = downloadsDirectory.appendingPathComponent("downloads.json")
        guard let data = try? JSONEncoder().encode(downloads) else { return }
        try? data.write(to: downloadsFile)
    }

    // MARK: - Storage Management

    func getTotalDownloadSize() -> Int64 {
        downloads.filter { $0.status == .completed }.reduce(0) { $0 + $1.downloadedSize }
    }

    func deleteAllDownloads() throws {
        try fileManager.removeItem(at: downloadsDirectory)
        createDownloadsDirectory()
        downloads.removeAll()
        saveDownloads()
    }
}

// MARK: - Models

struct Download: Codable, Identifiable {
    let id: String
    let libraryItemId: String
    let title: String
    let author: String
    var coverPath: String?
    var totalSize: Int64
    var downloadedSize: Int64
    var status: DownloadStatus
    var createdAt: Date
    var completedAt: Date?
    var error: String?
    var audioTracks: [String]

    var progress: Double {
        guard totalSize > 0 else { return 0 }
        return Double(downloadedSize) / Double(totalSize)
    }
}

enum DownloadStatus: String, Codable {
    case pending
    case downloading
    case completed
    case failed
    case cancelled
}

struct DownloadTask {
    let task: Task<Void, Never>
    let bookId: String
    var progress: Double = 0
}

enum DownloadError: LocalizedError {
    case alreadyDownloaded
    case alreadyDownloading
    case cellularNotAllowed
    case noAudioTracks
    case notFound
    case fileSystemError

    var errorDescription: String? {
        switch self {
        case .alreadyDownloaded: return "This book is already downloaded"
        case .alreadyDownloading: return "This book is already downloading"
        case .cellularNotAllowed: return "Downloads on cellular are disabled"
        case .noAudioTracks: return "No audio tracks found"
        case .notFound: return "Download not found"
        case .fileSystemError: return "File system error"
        }
    }
}
