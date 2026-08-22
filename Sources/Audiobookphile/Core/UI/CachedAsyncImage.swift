import SwiftUI
import Observation

#if canImport(UIKit)
import UIKit
#endif

#if !SKIP
import ImageIO
#endif

/// Decode budgets (max pixel dimension) for cover surfaces. Bucketed keys let
/// the player keep crisp art while grid cells hold thumbnails, and keep the
/// memory cost of each entry proportional to where it is shown.
public enum CoverDecodeBudget {
    /// Mini-player thumbnails and other ~50pt artwork.
    public static let thumbnail: CGFloat = 240
    /// Grid cells, list rows, continue-listening, and the detail header at 3x.
    public static let standard: CGFloat = 800
    /// Full-screen player artwork (blurred backdrops use standard).
    public static let player: CGFloat = 1600
}

#if os(iOS)
/// Decode an image at display size instead of materializing the provider's
/// full-resolution bitmap — a scraped 2000px cover costs ~16MB decoded but
/// ~2.5MB at the standard budget, and the thumbnail decode path skips the
/// full-size pass entirely.
nonisolated func downsampledImage(data: Data, maxPixelSize: CGFloat) -> UIImage? {
    let sourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
    guard let source = CGImageSourceCreateWithData(data as CFData, sourceOptions) else {
        return nil
    }
    let thumbnailOptions = [
        kCGImageSourceCreateThumbnailFromImageAlways: true,
        kCGImageSourceCreateThumbnailWithTransform: true,
        kCGImageSourceShouldCacheImmediately: true,
        kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
    ] as CFDictionary
    guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, thumbnailOptions) else {
        return nil
    }
    return UIImage(cgImage: cgImage)
}
#endif

/// A memory cache for UIImages to prevent flickering when scrolling `AsyncImage`.
@MainActor
class ImageMemoryCache {
    static let shared = ImageMemoryCache()

    #if os(iOS)
    private let cache = NSCache<NSURL, UIImage>()

    init() {
        cache.countLimit = 500 // Store up to 500 cover art images in RAM
        cache.totalCostLimit = 200 * 1024 * 1024 // 200 MB memory limit
    }

    private static func key(_ url: URL, maxPixelSize: CGFloat) -> NSURL {
        NSURL(string: "\(url.absoluteString)#\(Int(maxPixelSize))") ?? (url as NSURL)
    }

    func get(url: URL, maxPixelSize: CGFloat) -> UIImage? {
        return cache.object(forKey: Self.key(url, maxPixelSize: maxPixelSize))
    }

    func set(image: UIImage, for url: URL, maxPixelSize: CGFloat) {
        // Cost in decoded bytes so totalCostLimit bounds actual memory, not
        // just the entry count.
        let cost = Int(
            image.size.width * image.scale * image.size.height * image.scale * 4
        )
        cache.setObject(
            image,
            forKey: Self.key(url, maxPixelSize: maxPixelSize),
            cost: cost,
        )
    }

    private static let decodeBudgets: [CGFloat] = [
        CoverDecodeBudget.player,
        CoverDecodeBudget.standard,
        CoverDecodeBudget.thumbnail,
    ]

    /// Any already-decoded bitmap for this URL, across decode budgets — lets
    /// color extraction reuse pixels instead of a second network fetch.
    func cachedImage(for url: URL) -> UIImage? {
        for budget in Self.decodeBudgets {
            if let image = get(url: url, maxPixelSize: budget) {
                return image
            }
        }
        return nil
    }
    #else
    // Stub for Skip Android compilation if needed. Skip handles standard NSCache mostly but image mapping might differ.
    func get(url: URL, maxPixelSize: CGFloat) -> Image? { return nil }
    func set(image: Any, for url: URL, maxPixelSize: CGFloat) {}
    func cachedImage(for url: URL) -> Any? { return nil }
    #endif
}

@Observable
@MainActor
class CachedImageLoader {
    var image: Image?
    var isLoading = false

    func load(url: URL, maxPixelSize: CGFloat = CoverDecodeBudget.standard) async {
        #if os(iOS)
        if let cached = ImageMemoryCache.shared.get(url: url, maxPixelSize: maxPixelSize) {
            self.image = Image(uiImage: cached)
            return
        }

        self.image = nil
        isLoading = true

        let maxRetries = 6
        var currentAttempt = 0
        var success = false

        while currentAttempt <= maxRetries && !success && !Task.isCancelled {
            do {
                let (data, response) = try await URLSession.shared.data(from: url)

                if let httpResponse = response as? HTTPURLResponse,
                   httpResponse.statusCode == 200 {
                    // Decode off the main actor — ImageIO thumbnailing of a
                    // multi-megapixel JPEG is real work and belongs off-frame.
                    let uiImage = await Task.detached(priority: .utility) {
                        downsampledImage(data: data, maxPixelSize: maxPixelSize) ??
                            UIImage(data: data)
                    }.value
                    if let uiImage {
                        ImageMemoryCache.shared.set(
                            image: uiImage,
                            for: url,
                            maxPixelSize: maxPixelSize,
                        )
                        self.image = Image(uiImage: uiImage)
                    }
                    success = true
                } else if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 429 {
                    // Rate limit exceeded. We MUST retry with exponential backoff.
                    throw URLError(.badServerResponse)
                } else if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 404 {
                    // Not found, permanently missing for now. Do not retry.
                    break
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
    let maxPixelSize: CGFloat
    let content: (Image) -> Content
    let placeholder: () -> Placeholder

    @State var loader = CachedImageLoader()

    public init(
        url: URL?,
        maxPixelSize: CGFloat = CoverDecodeBudget.standard,
        @ViewBuilder content: @escaping (Image) -> Content,
        @ViewBuilder placeholder: @escaping () -> Placeholder
    ) {
        self.url = url
        self.maxPixelSize = maxPixelSize
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
        .task(id: url) {
            if let url = url {
                await loader.load(url: url, maxPixelSize: maxPixelSize)
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
