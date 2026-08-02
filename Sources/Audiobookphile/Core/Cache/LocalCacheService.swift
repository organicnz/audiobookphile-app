import Foundation

/// A reusable cross-platform service for reading and writing Codable models to disk asynchronously.
public actor LocalCacheService {
    public static let shared = LocalCacheService()
    
    private let fileManager = FileManager.default
    private let cacheDirectory: URL
    
    private init() {
        if let docs = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first {
            cacheDirectory = docs.appendingPathComponent("AppCache", isDirectory: true)
            try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        } else {
            cacheDirectory = URL(fileURLWithPath: NSTemporaryDirectory())
        }
    }
    
    public func save<T: Codable>(_ object: T, forKey key: String) {
        let url = cacheDirectory.appendingPathComponent("\(key).json")
        do {
            let data = try JSONEncoder().encode(object)
            try data.write(to: url, options: .atomic)
        } catch {
            print("[LocalCacheService] Failed to save cache for key \(key): \(error)")
        }
    }
    
    public func load<T: Codable>(forKey key: String, as type: T.Type) -> T? {
        let url = cacheDirectory.appendingPathComponent("\(key).json")
        guard fileManager.fileExists(atPath: url.path) else { return nil }
        
        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            print("[LocalCacheService] Failed to load cache for key \(key): \(error)")
            return nil
        }
    }
    
    public func clear(forKey key: String) {
        let url = cacheDirectory.appendingPathComponent("\(key).json")
        try? fileManager.removeItem(at: url)
    }
}
