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
    @Published var image: Image?
    @Published var isLoading = false

    func load(url: URL) async {
        #if os(iOS)
        if let cached = ImageMemoryCache.shared.get(url: url) {
            self.image = Image(uiImage: cached)
            return
        }

        isLoading = true

        let maxRetries = 6
        var currentAttempt = 0
        var success = false

        while currentAttempt <= maxRetries && !success && !Task.isCancelled {
            do {
                let (data, response) = try await URLSession.shared.data(from: url)

                if let httpResponse = response as? HTTPURLResponse,
                   httpResponse.statusCode == 200,
                   let uiImage = UIImage(data: data) {
                    ImageMemoryCache.shared.set(image: uiImage, for: url)
                    self.image = Image(uiImage: uiImage)
                    success = true
                } else if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 429 {
                    // Rate limit exceeded. We MUST retry with exponential backoff.
                    throw URLError(.badServerResponse)
                } else {
                    // Not a 200 or not an image. We should retry to allow backend scraping to finish.
                    throw URLError(.badServerResponse)
                }
            } catch {
                currentAttempt += 1
                if currentAttempt <= maxRetries {
                    let backoff = pow(2.0, Double(currentAttempt)) * 1.0 // 2s, 4s, 8s, 16s, 32s, 64s
                    try? await Task.sleep(nanoseconds: UInt64(backoff * 1_000_000_000))
                } else {
                    print("Failed to load image after \(maxRetries) retries: \(error)")
                }
            }
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
