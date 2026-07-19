import Foundation

class FileHelper {
    static var queueURL: URL {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        return paths[0].appendingPathComponent("abp_offlineProgressQueue.json")
    }

    static func saveQueue(_ queue: [ProgressSyncQueueItem]) {
        do {
            let data = try JSONEncoder().encode(queue)
            try data.write(to: queueURL, options: .atomic)
        } catch {
            print("Failed to save queue")
        }
    }

    static func loadQueue() -> [ProgressSyncQueueItem] {
        guard let data = try? Data(contentsOf: queueURL),
              let queue = try? JSONDecoder().decode([ProgressSyncQueueItem].self, from: data) else {
            return []
        }
        return queue
    }
}
