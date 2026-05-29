//
//  DownloadsView.swift
//  Audiobookshelf
//
//  Downloads management view with Liquid Glass design.
//  Compatible with Swift 6.3 and Skip.
//

import SwiftUI
import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public enum DownloadStatus: Int, Codable {
    case pending = 0
    case downloading = 1
    case paused = 2
    case completed = 3
    case failed = 4
}

public struct Download: Identifiable, Codable {
    public var id: String { libraryItemId }
    public let libraryItemId: String
    public let title: String
    public let author: String
    public var progress: Double
    public var totalSize: Int64
    public var status: DownloadStatus
    public var audioTracks: [String]

    public init(libraryItemId: String, title: String, author: String, progress: Double, totalSize: Int64, status: DownloadStatus, audioTracks: [String] = []) {
        self.libraryItemId = libraryItemId
        self.title = title
        self.author = author
        self.progress = progress
        self.totalSize = totalSize
        self.status = status
        self.audioTracks = audioTracks
    }
}

@MainActor
public class DownloadService: NSObject, ObservableObject, URLSessionDownloadDelegate {
    public static let shared = DownloadService()

    @Published public var downloads: [Download] = []
    @Published public var activeDownloads: [String: Double] = [:]
    @Published public var downloadQueue: [String] = []
    
    private var activeBookId: String?
    private var activeTrackIndex: Int = 0
    private var activeDownloadTask: URLSessionDownloadTask?
    
    private var trackPathsMap: [String: [String]] = [:]
    private var trackSizes: [String: [Int64]] = [:]
    
    private let fm = FileManager.default
    
    private var downloadsDirectory: URL {
        let paths = fm.urls(for: .documentDirectory, in: .userDomainMask)
        return paths[0].appendingPathComponent("Downloads", isDirectory: true)
    }

    private override init() {
        super.init()
        createDownloadsDirectory()
        loadDownloads()
    }
    
    private func createDownloadsDirectory() {
        try? fm.createDirectory(at: downloadsDirectory, withIntermediateDirectories: true)
    }

    public func downloadBook(_ book: Book) async {
        if downloads.contains(where: { $0.libraryItemId == book.id && $0.status == .completed }) {
            return
        }
        if downloadQueue.contains(book.id) || activeBookId == book.id {
            return
        }
        
        do {
            print("[Download] Requesting playback session to retrieve direct track URLs for: \(book.title)")
            let session = try await AudiobookshelfAPI.shared.startPlaybackSession(libraryItemId: book.id)
            let tracks = session.audioTracks
            guard !tracks.isEmpty else {
                print("[Download] Error: no audio tracks found for \(book.title)")
                return
            }
            
            Task {
                try? await AudiobookshelfAPI.shared.closePlaybackSession(
                    sessionId: session.id,
                    currentTime: 0,
                    duration: session.duration
                )
            }
            
            let trackPaths = tracks.map { $0.contentUrl }
            let mediaSize = book.media.size ?? 0
            let totalSize = mediaSize > 0 ? mediaSize : Int64(session.duration * 32000 / 8)
            
            let download = Download(
                libraryItemId: book.id,
                title: book.title,
                author: book.author ?? "Unknown Author",
                progress: 0.0,
                totalSize: totalSize,
                status: .pending,
                audioTracks: trackPaths
            )
            
            if let index = downloads.firstIndex(where: { $0.libraryItemId == book.id }) {
                downloads[index] = download
            } else {
                downloads.append(download)
            }
            
            saveDownloadsIndex()
            
            downloadQueue.append(book.id)
            trackPathsMap[book.id] = trackPaths
            
            processQueue()
        } catch {
            print("[Download] Failed to start download for \(book.title): \(error)")
        }
    }

    public func cancelDownload(bookId: String) {
        if activeBookId == bookId {
            activeDownloadTask?.cancel()
            activeDownloadTask = nil
            activeBookId = nil
        }
        
        // Remove any resume data
        let fileURL = downloadsDirectory.appendingPathComponent("\(bookId)_resume.dat")
        try? fm.removeItem(at: fileURL)
        
        downloadQueue.removeAll { $0 == bookId }
        downloads.removeAll { $0.libraryItemId == bookId }
        activeDownloads.removeValue(forKey: bookId)
        
        saveDownloadsIndex()
        processQueue()
    }

    public func pauseDownload(bookId: String) {
        guard activeBookId == bookId, let task = activeDownloadTask else { return }
        
        task.cancel { [weak self] resumeDataOrNil in
            guard let self = self else { return }
            Task { @MainActor in
                if let resumeData = resumeDataOrNil {
                    let fileURL = self.downloadsDirectory.appendingPathComponent("\(bookId)_resume.dat")
                    try? resumeData.write(to: fileURL)
                }
                
                if let index = self.downloads.firstIndex(where: { $0.libraryItemId == bookId }) {
                    self.downloads[index].status = .paused
                }
                self.activeDownloads.removeValue(forKey: bookId)
                self.activeDownloadTask = nil
                self.activeBookId = nil
                self.saveDownloadsIndex()
                self.processQueue()
            }
        }
    }

    public func resumeDownload(bookId: String) {
        if let index = downloads.firstIndex(where: { $0.libraryItemId == bookId }) {
            downloads[index].status = .pending
        }
        
        downloadQueue.removeAll { $0 == bookId }
        downloadQueue.insert(bookId, at: 0)
        
        saveDownloadsIndex()
        
        if activeBookId == nil {
            processQueue()
        }
    }

    public func deleteDownload(bookId: String) throws {
        cancelDownload(bookId: bookId)
        
        let bookDir = downloadsDirectory.appendingPathComponent(bookId)
        try? fm.removeItem(at: bookDir)
        
        downloads.removeAll { $0.libraryItemId == bookId }
        saveDownloadsIndex()
    }
    
    private func processQueue() {
        guard activeBookId == nil, !downloadQueue.isEmpty else { return }
        
        let nextBookId = downloadQueue.removeFirst()
        activeBookId = nextBookId
        activeTrackIndex = 0
        
        if let paths = trackPathsMap[nextBookId] {
            trackSizes[nextBookId] = Array(repeating: 0, count: paths.count)
            downloadNextTrack()
        } else if let index = downloads.firstIndex(where: { $0.libraryItemId == nextBookId }) {
            let paths = downloads[index].audioTracks
            if !paths.isEmpty {
                trackPathsMap[nextBookId] = paths
                trackSizes[nextBookId] = Array(repeating: 0, count: paths.count)
                downloadNextTrack()
            } else {
                print("[Download] Missing tracks for book \(nextBookId)")
                activeBookId = nil
                processQueue()
            }
        }
    }
    
    private func downloadNextTrack() {
        guard let bookId = activeBookId,
              let paths = trackPathsMap[bookId],
              activeTrackIndex < paths.count else {
            return
        }
        
        let trackPath = paths[activeTrackIndex]
        let baseURL = AudiobookshelfAPI.shared.baseURL
        let token = AudiobookshelfAPI.shared.accessToken
        
        let fullPath: String
        if trackPath.hasPrefix("http") {
            fullPath = trackPath
        } else {
            fullPath = baseURL + (trackPath.hasPrefix("/") ? "" : "/") + trackPath
        }
        
        guard var components = URLComponents(string: fullPath) else { return }
        var queryItems = components.queryItems ?? []
        if !queryItems.contains(where: { $0.name == "token" }) {
            queryItems.append(URLQueryItem(name: "token", value: token))
        }
        components.queryItems = queryItems
        
        guard let url = components.url else { return }
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let session = URLSession(configuration: .default, delegate: self, delegateQueue: nil)
        
        let fileURL = downloadsDirectory.appendingPathComponent("\(bookId)_resume.dat")
        if let resumeData = try? Data(contentsOf: fileURL) {
            try? fm.removeItem(at: fileURL)
            let task = session.downloadTask(withResumeData: resumeData)
            self.activeDownloadTask = task
        } else {
            let task = session.downloadTask(with: request)
            self.activeDownloadTask = task
        }
        
        if let index = downloads.firstIndex(where: { $0.libraryItemId == bookId }) {
            downloads[index].status = .downloading
        }
        activeDownloads[bookId] = downloads.first(where: { $0.libraryItemId == bookId })?.progress ?? 0.0
        activeDownloadTask?.resume()
    }
    
    private func handleActiveDownloadFailed(error: Error) {
        guard let bookId = activeBookId else { return }
        
        if let index = downloads.firstIndex(where: { $0.libraryItemId == bookId }) {
            downloads[index].status = .failed
            downloads[index].progress = 0.0
        }
        activeDownloads.removeValue(forKey: bookId)
        
        activeBookId = nil
        activeDownloadTask = nil
        saveDownloadsIndex()
        processQueue()
    }
    
    private func fileExtension(for mimeType: String, urlPath: String) -> String {
        if mimeType.contains("audio/mpeg") || mimeType.contains("mp3") {
            return "mp3"
        } else if mimeType.contains("audio/x-m4a") || mimeType.contains("m4a") || mimeType.contains("audio/mp4") {
            return "m4a"
        } else if mimeType.contains("audio/ogg") || mimeType.contains("ogg") {
            return "ogg"
        } else if mimeType.contains("audio/flac") || mimeType.contains("flac") {
            return "flac"
        }
        let ext = URL(fileURLWithPath: urlPath).pathExtension
        return ext.isEmpty ? "m4a" : ext
    }
    
    private func loadDownloads() {
        let fileURL = downloadsDirectory.appendingPathComponent("downloads.json")
        guard let data = try? Data(contentsOf: fileURL),
              let decoded = try? JSONDecoder().decode([Download].self, from: data) else {
            return
        }
        self.downloads = decoded.map {
            var dl = $0
            if dl.status == .downloading || dl.status == .pending {
                dl.status = .failed
                dl.progress = 0.0
            }
            return dl
        }
    }
    
    private func saveDownloadsIndex() {
        let fileURL = downloadsDirectory.appendingPathComponent("downloads.json")
        try? fm.createDirectory(at: downloadsDirectory, withIntermediateDirectories: true)
        if let data = try? JSONEncoder().encode(downloads) {
            try? data.write(to: fileURL)
        }
    }
    
    public func getLocalTrackURL(bookId: String, trackPath: String) -> URL? {
        guard let download = downloads.first(where: { $0.libraryItemId == bookId && $0.status == .completed }) else {
            return nil
        }
        
        let fileManager = FileManager.default
        let docs = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let bookDir = docs.appendingPathComponent("Downloads/\(bookId)", isDirectory: true)
        
        let trackPaths = download.audioTracks
        if let index = trackPaths.firstIndex(of: trackPath) {
            if let files = try? fileManager.contentsOfDirectory(at: bookDir, includingPropertiesForKeys: nil),
               let match = files.first(where: { $0.lastPathComponent.hasPrefix("track_\(index).") }) {
                return match
            }
        }
        
        if let files = try? fileManager.contentsOfDirectory(at: bookDir, includingPropertiesForKeys: nil),
           let match = files.first(where: { $0.lastPathComponent.hasPrefix("track_0.") }) {
            return match
        }
        
        return nil
    }
    
    // MARK: - URLSessionDownloadDelegate conformances
    
    public nonisolated func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        Task { @MainActor in
            guard let bookId = self.activeBookId else { return }
            let completedTracksSize = self.trackSizes[bookId]?.prefix(self.activeTrackIndex).reduce(0, +) ?? 0
            
            if let index = self.downloads.firstIndex(where: { $0.libraryItemId == bookId }) {
                let totalBookSize = self.downloads[index].totalSize
                let currentTotalWritten = completedTracksSize + totalBytesWritten
                
                let progress = min(0.99, Double(currentTotalWritten) / Double(max(1, totalBookSize)))
                self.downloads[index].progress = progress
                self.activeDownloads[bookId] = progress
            }
        }
    }
    
    public nonisolated func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        Task { @MainActor in
            guard let bookId = self.activeBookId else { return }
            let trackPaths = self.trackPathsMap[bookId] ?? []
            guard self.activeTrackIndex < trackPaths.count else { return }
            
            let trackPath = trackPaths[self.activeTrackIndex]
            let bookDir = self.downloadsDirectory.appendingPathComponent(bookId)
            
            do {
                try self.fm.createDirectory(at: bookDir, withIntermediateDirectories: true)
                
                let ext = self.fileExtension(for: downloadTask.response?.mimeType ?? "", urlPath: trackPath)
                let destFile = bookDir.appendingPathComponent("track_\(self.activeTrackIndex).\(ext)")
                
                if self.fm.fileExists(atPath: destFile.path) {
                    try? self.fm.removeItem(at: destFile)
                }
                
                try self.fm.moveItem(at: location, to: destFile)
                print("[Download] Saved track \(self.activeTrackIndex) to \(destFile.path)")
                
                let fileSize = (try? self.fm.attributesOfItem(atPath: destFile.path)[.size] as? Int64) ?? 0
                if self.trackSizes[bookId] == nil {
                    self.trackSizes[bookId] = Array(repeating: 0, count: trackPaths.count)
                }
                self.trackSizes[bookId]?[self.activeTrackIndex] = fileSize
                
                self.activeTrackIndex += 1
                if self.activeTrackIndex >= trackPaths.count {
                    if let index = self.downloads.firstIndex(where: { $0.libraryItemId == bookId }) {
                        self.downloads[index].status = .completed
                        self.downloads[index].progress = 1.0
                    }
                    self.activeDownloads.removeValue(forKey: bookId)
                    print("[Download] Finished all tracks for book: \(bookId)")
                    self.activeBookId = nil
                    self.activeDownloadTask = nil
                    self.saveDownloadsIndex()
                    self.processQueue()
                } else {
                    self.downloadNextTrack()
                }
            } catch {
                print("[Download] Error moving downloaded track: \(error)")
                self.handleActiveDownloadFailed(error: error)
            }
        }
    }
    
    public nonisolated func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didCompleteWithError error: Error?
    ) {
        if let error = error {
            Task { @MainActor in
                let nsError = error as NSError
                if nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled {
                    return
                }
                self.handleActiveDownloadFailed(error: error)
            }
        }
    }
}

public struct DownloadsView: View {
    @ObservedObject var downloadService = DownloadService.shared
    @State var selectedBook: Book? = nil

    public init() {}

    private var trailingPlacement: ToolbarItemPlacement {
        #if os(iOS) || SKIP
        return .navigationBarTrailing
        #else
        return .primaryAction
        #endif
    }

    public var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()

                if downloadService.downloads.isEmpty {
                    emptyState
                } else {
                    downloadsList
                }
            }
            .navigationTitle("Downloads")
            #if os(iOS) || SKIP
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                if !downloadService.downloads.isEmpty {
                    ToolbarItem(placement: trailingPlacement) {
                        #if os(iOS) || SKIP
                        EditButton()
                            .foregroundStyle(Color.appPrimary)
                        #endif
                    }
                }
            }
            .sheet(item: $selectedBook) { book in
                BookDetailView(book: book)
            }
        }
    }

    // MARK: - Views

    private var emptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "arrow.down.circle")
                .font(.system(size: 60))
                .foregroundStyle(.white.opacity(0.2))

            Text("No downloads yet")
                .font(.title3)
                .foregroundStyle(.white.opacity(0.8))

            Text("Downloaded audiobooks and episodes will appear here for offline listening.")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.5))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
    }

    private var downloadsList: some View {
        List {
            // Active Downloads
            let pendingDownloads = downloadService.downloads.filter { $0.status != .completed }
            if !pendingDownloads.isEmpty {
                Section {
                    ForEach(pendingDownloads) { download in
                        if download.status == .downloading || download.status == .paused {
                            ActiveDownloadRow(download: download)
                        } else {
                            QueueRow(download: download)
                        }
                    }
                } header: {
                    Text("Downloading")
                        .foregroundStyle(Color.appPrimary)
                }
                .listRowBackground(Color.white.opacity(0.05))
            }

            // Completed Downloads
            Section {
                ForEach(downloadService.downloads.filter { $0.status == .completed }) { download in
                    DownloadedBookRow(download: download)
                        .onTapGesture {
                            print("Selected \(download.title)")
                        }
                }
                .onDelete { indexSet in
                    deleteDownloads(at: indexSet)
                }
            } header: {
                Text("Downloaded")
                    .foregroundStyle(.white.opacity(0.6))
            }
            .listRowBackground(Color.white.opacity(0.05))
        }
        .scrollContentBackground(.hidden)
    }

    // MARK: - Actions

    private func deleteDownloads(at offsets: IndexSet) {
        let completed = downloadService.downloads.filter { $0.status == .completed }
        offsets.forEach { index in
            let download = completed[index]
            try? downloadService.deleteDownload(bookId: download.libraryItemId)
        }
    }
}

// MARK: - Active Download Row

public struct ActiveDownloadRow: View {
    public let download: Download

    @State var progress = 0.45

    public init(download: Download) {
        self.download = download
    }

    public var body: some View {
        HStack(spacing: 12) {
            // Cover (placeholder for now)
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.gray.opacity(0.3))
                .frame(width: 40, height: 60)
                .overlay {
                    Image(systemName: "book.closed")
                        .foregroundStyle(.white.opacity(0.3))
                }

            VStack(alignment: .leading, spacing: 6) {
                Text(download.title)
                    .font(.headline)
                    .foregroundStyle(.white)
                    .lineLimit(1)

                ProgressView(value: download.progress)
                    .tint(download.status == .paused ? .gray : .appPrimary)

                HStack {
                    Text(download.status == .paused ? "Paused" : "\(Int(download.progress * 100))%")
                        .font(.caption)
                        .foregroundStyle(download.status == .paused ? .gray : Color.appPrimary)

                    Spacer()

                    Text(ByteCountFormatter.string(fromByteCount: download.totalSize, countStyle: .file))
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.5))
                }
            }

            if download.status == .paused {
                Button {
                    DownloadService.shared.resumeDownload(bookId: download.libraryItemId)
                } label: {
                    Image(systemName: "play.circle.fill")
                        .foregroundStyle(.white.opacity(0.8))
                        .font(.title2)
                }
            } else {
                Button {
                    DownloadService.shared.pauseDownload(bookId: download.libraryItemId)
                } label: {
                    Image(systemName: "pause.circle.fill")
                        .foregroundStyle(.white.opacity(0.8))
                        .font(.title2)
                }
            }

            Button {
                DownloadService.shared.cancelDownload(bookId: download.libraryItemId)
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.white.opacity(0.4))
            }
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Queue Row

public struct QueueRow: View {
    public let download: Download

    public init(download: Download) {
        self.download = download
    }

    public var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "hourglass")
                .foregroundStyle(.white.opacity(0.5))
                .frame(width: 40)

            VStack(alignment: .leading, spacing: 4) {
                Text(download.title)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.8))

                Text("Waiting...")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.5))
            }

            Spacer()
            
            Button {
                DownloadService.shared.resumeDownload(bookId: download.libraryItemId)
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .foregroundStyle(Color.appPrimary)
                    .font(.title3)
            }
            
            Button {
                DownloadService.shared.cancelDownload(bookId: download.libraryItemId)
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.white.opacity(0.4))
            }
        }
    }
}

// MARK: - Downloaded Book Row

public struct DownloadedBookRow: View {
    public let download: Download

    public init(download: Download) {
        self.download = download
    }

    public var body: some View {
        HStack(spacing: 16) {
            // Cover
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.appPrimary.opacity(0.15))
                .frame(width: 45, height: 68)
                .overlay {
                    Image(systemName: "book.fill")
                        .foregroundStyle(.white.opacity(0.3))
                }

            VStack(alignment: .leading, spacing: 4) {
                Text(download.title)
                    .font(.headline)
                    .foregroundStyle(.white)

                Text(download.author)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.7))

                HStack(spacing: 6) {
                    Image(systemName: "clock")
                        .font(.caption2)
                    Text("14h 32m")
                        .font(.caption)

                    Text("•")

                    Text(ByteCountFormatter.string(fromByteCount: download.totalSize, countStyle: .file))
                        .font(.caption)
                }
                .foregroundStyle(.white.opacity(0.5))
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.3))
        }
        .padding(.vertical, 4)
    }
}
