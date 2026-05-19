//
//  DownloadsView.swift
//  Audiobookshelf
//
//  Downloads management view with Liquid Glass design.
//  Compatible with Swift 6.3 and Skip.
//

import SwiftUI

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

    public init(libraryItemId: String, title: String, author: String, progress: Double, totalSize: Int64, status: DownloadStatus) {
        self.libraryItemId = libraryItemId
        self.title = title
        self.author = author
        self.progress = progress
        self.totalSize = totalSize
        self.status = status
    }
}

@MainActor
public class DownloadService: ObservableObject {
    public static let shared = DownloadService()

    @Published public var downloads: [Download] = []
    @Published public var activeDownloads: [String: Double] = [:]
    @Published public var downloadQueue: [String] = []

    private init() {
        // Generate mock data for demonstration
        downloads = [
            Download(
                libraryItemId: "book-1",
                title: "The Midnight Library",
                author: "Matt Haig",
                progress: 1.0,
                totalSize: 450000000,
                status: .completed
            ),
            Download(
                libraryItemId: "book-2",
                title: "Project Hail Mary",
                author: "Andy Weir",
                progress: 0.65,
                totalSize: 720000000,
                status: .downloading
            )
        ]
        activeDownloads = ["book-2": 0.65]
    }

    public func cancelDownload(bookId: String) {
        downloads.removeAll { $0.libraryItemId == bookId }
        activeDownloads.removeValue(forKey: bookId)
        downloadQueue.removeAll { $0 == bookId }
    }

    public func deleteDownload(bookId: String) throws {
        downloads.removeAll { $0.libraryItemId == bookId }
        activeDownloads.removeValue(forKey: bookId)
        downloadQueue.removeAll { $0 == bookId }
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
                            .foregroundStyle(.cyan)
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
            if !downloadService.activeDownloads.isEmpty || !downloadService.downloadQueue.isEmpty {
                Section {
                    ForEach(downloadService.activeDownloads.keys.sorted(), id: \.self) { id in
                        if let download = downloadService.downloads.first(where: { $0.libraryItemId == id }) {
                            ActiveDownloadRow(download: download)
                        }
                    }

                    ForEach(downloadService.downloadQueue, id: \.self) { id in
                        if let download = downloadService.downloads.first(where: { $0.libraryItemId == id }) {
                            QueueRow(download: download)
                        }
                    }
                } header: {
                    Text("Downloading")
                        .foregroundStyle(.cyan)
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
                    .tint(.cyan)

                HStack {
                    Text("\(Int(download.progress * 100))%")
                        .font(.caption)
                        .foregroundStyle(.cyan)

                    Spacer()

                    Text(ByteCountFormatter.string(fromByteCount: download.totalSize, countStyle: .file))
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.5))
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
                .fill(Color.blue.opacity(0.2))
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
