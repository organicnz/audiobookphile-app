//
//  DownloadsView.swift
//  AudiobookphileClient
//
//  Downloads management view with Liquid Glass design
//

import SwiftUI

struct DownloadsView: View {
    @ObservedObject var downloadService = DownloadService.shared
    @State private var selectedBook: Book?

    var body: some View {
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
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if !downloadService.downloads.isEmpty {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        EditButton()
                            .foregroundStyle(.cyan)
                    }
                }
            }
            .navigationDestination(
                isPresented: Binding(
                    get: { selectedBook != nil },
                    set: { if !$0 { selectedBook = nil } }
                )
            ) {
                if let book = selectedBook {
                    BookDetailView(book: book)
                }
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
                            // In a real app we'd fetch the Book object from DB/API
                            // For now just print
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

struct ActiveDownloadRow: View {
    let download: Download

    // Mock progress since we don't have a real stream here
    @State private var progress = 0.45

    var body: some View {
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

struct QueueRow: View {
    let download: Download

    var body: some View {
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

struct DownloadedBookRow: View {
    let download: Download

    var body: some View {
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
                    Text("14h 32m") // Would come from metadata
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

#Preview {
    DownloadsView()
}
