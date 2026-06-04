import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

/// A memory cache for UIImages to prevent flickering when scrolling `AsyncImage`.
@MainActor
class ImageMemoryCache {
    static let shared = ImageMemoryCache()
    
    #if os(iOS)
    private let cache = NSCache<NSURL, UIImage>()
    
    init() {
        cache.countLimit = 100 // Limit to 100 images
    }
    
    func get(url: URL) -> UIImage? {
        return cache.object(forKey: url as NSURL)
    }
    
    func set(image: UIImage, for url: URL) {
        cache.setObject(image, forKey: url as NSURL)
    }
    #else
    // Stub for Skip Android compilation if needed. Skip handles standard NSCache mostly but image mapping might differ.
    func get(url: URL) -> Image? { return nil }
    func set(image: Any, for url: URL) {}
    #endif
}

@MainActor
class CachedImageLoader: ObservableObject {
    @Published var image: Image? = nil
    @Published var isLoading = false
    
    func load(url: URL) async {
        #if os(iOS)
        if let cached = ImageMemoryCache.shared.get(url: url) {
            self.image = Image(uiImage: cached)
            return
        }
        
        isLoading = true
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let uiImage = UIImage(data: data) {
                ImageMemoryCache.shared.set(image: uiImage, for: url)
                self.image = Image(uiImage: uiImage)
            }
        } catch {
            print("Failed to load image: \(error)")
        }
        
        isLoading = false
        #else
        // For non-iOS (Skip), just let the view fallback to normal AsyncImage
        #endif
    }
}

public struct CachedAsyncImage<Content: View, Placeholder: View>: View {
    let url: URL?
    let content: (Image) -> Content
    let placeholder: () -> Placeholder
    
    @StateObject var loader = CachedImageLoader()
    
    public init(
        url: URL?,
        @ViewBuilder content: @escaping (Image) -> Content,
        @ViewBuilder placeholder: @escaping () -> Placeholder
    ) {
        self.url = url
        self.content = content
        self.placeholder = placeholder
    }
    
    public var body: some View {
        #if os(iOS)
        ZStack {
            if let image = loader.image {
                content(image)
            } else {
                placeholder()
            }
        }
        .task {
            if let url = url {
                await loader.load(url: url)
            }
        }
        #else
        // Fallback for Skip compilation
        if let url = url {
            AsyncImage(url: url) { phase in
                if let image = phase.image {
                    content(image)
                } else if phase.error != nil {
                    placeholder()
                } else {
                    placeholder()
                }
            }
        } else {
            placeholder()
        }
        #endif
    }
}
