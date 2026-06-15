import Foundation

#if os(iOS) && !SKIP
import Combine
#endif

public final class OfflineDownloadManager: NSObject, ObservableObject, @unchecked Sendable {
    public static let shared = OfflineDownloadManager()
    
    @Published public var downloadProgress: [String: Double] = [:]
    @Published public var activeDownloads: Set<String> = []
    
    private var session: URLSession!
    
    private override init() {
        super.init()
        let config = URLSessionConfiguration.background(withIdentifier: "com.audiobookphile.offline.downloads")
        config.isDiscretionary = false
        config.sessionSendsLaunchEvents = true
        self.session = URLSession(configuration: config, delegate: self, delegateQueue: nil)
    }
    
    public func downloadAudio(for bookId: String, url: URL) {
        let task = session.downloadTask(with: url)
        task.taskDescription = bookId
        
        DispatchQueue.main.async {
            self.activeDownloads.insert(bookId)
            self.downloadProgress[bookId] = 0.0
        }
        
        task.resume()
    }
    
    public func isDownloaded(bookId: String) -> Bool {
        return getOfflineURL(for: bookId) != nil
    }
    
    public func getOfflineURL(for bookId: String) -> URL? {
        let fileManager = FileManager.default
        let urls = fileManager.urls(for: .documentDirectory, in: .userDomainMask)
        guard let documentsURL = urls.first else { return nil }
        
        let fileURL = documentsURL.appendingPathComponent("\(bookId).mp3")
        return fileManager.fileExists(atPath: fileURL.path) ? fileURL : nil
    }
}

extension OfflineDownloadManager: URLSessionDownloadDelegate {
    public func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        guard let bookId = downloadTask.taskDescription else { return }
        
        let fileManager = FileManager.default
        let urls = fileManager.urls(for: .documentDirectory, in: .userDomainMask)
        if let documentsURL = urls.first {
            let destinationURL = documentsURL.appendingPathComponent("\(bookId).mp3")
            
            do {
                if fileManager.fileExists(atPath: destinationURL.path) {
                    try fileManager.removeItem(at: destinationURL)
                }
                try fileManager.moveItem(at: location, to: destinationURL)
                
                DispatchQueue.main.async {
                    self.activeDownloads.remove(bookId)
                    self.downloadProgress[bookId] = 1.0
                }
            } catch {
                print("Failed to move downloaded file: \(error)")
                DispatchQueue.main.async {
                    self.activeDownloads.remove(bookId)
                }
            }
        }
    }
    
    public func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        guard let bookId = downloadTask.taskDescription else { return }
        
        if totalBytesExpectedToWrite > 0 {
            let progress = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
            DispatchQueue.main.async {
                self.downloadProgress[bookId] = progress
            }
        }
    }
}
