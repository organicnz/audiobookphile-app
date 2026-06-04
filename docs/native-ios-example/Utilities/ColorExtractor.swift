//
//  ColorExtractor.swift
//  AudiobookphileClient
//
//  Extract dominant color from book cover images
//  Critical for Liquid Glass dynamic theming
//

import SwiftUI
import UIKit
import CoreImage

/// Extracts dominant colors from images for dynamic theming
class ColorExtractor {
    static let shared = ColorExtractor()

    private let context = CIContext(options: [.workingColorSpace: kCFNull as Any])
    private var colorCache = NSCache<NSString, UIColor>()

    /// Extract average color from a UIImage
    func extractColor(from image: UIImage) -> UIColor? {
        guard let inputImage = CIImage(image: image) else { return nil }

        let extentVector = CIVector(
            x: inputImage.extent.origin.x,
            y: inputImage.extent.origin.y,
            z: inputImage.extent.size.width,
            w: inputImage.extent.size.height
        )

        guard let filter = CIFilter(
            name: "CIAreaAverage",
            parameters: [
                kCIInputImageKey: inputImage,
                kCIInputExtentKey: extentVector
            ]
        ) else { return nil }

        guard let outputImage = filter.outputImage else { return nil }

        var bitmap = [UInt8](repeating: 0, count: 4)
        context.render(
            outputImage,
            toBitmap: &bitmap,
            rowBytes: 4,
            bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
            format: .RGBA8,
            colorSpace: nil
        )

        return UIColor(
            red: CGFloat(bitmap[0]) / 255,
            green: CGFloat(bitmap[1]) / 255,
            blue: CGFloat(bitmap[2]) / 255,
            alpha: 1.0
        )
    }

    /// Extract color with caching
    func extractColor(from url: URL) async -> UIColor {
        let cacheKey = url.absoluteString as NSString

        if let cached = colorCache.object(forKey: cacheKey) {
            return cached
        }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let image = UIImage(data: data),
               let color = extractColor(from: image) {
                colorCache.setObject(color, forKey: cacheKey)
                return color
            }
        } catch {
            print("Failed to load image for color extraction: \(error)")
        }

        return UIColor(red: 0.22, green: 0.22, blue: 0.22, alpha: 1.0) // Default dark gray
    }

    /// Check if a color is considered "light" (for text color contrast)
    func isLight(_ color: UIColor) -> Bool {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0

        color.getRed(&red, green: &green, blue: &blue, alpha: &alpha)

        // Using perceived brightness formula
        let brightness = (red * 299 + green * 587 + blue * 114) / 1000
        return brightness > 0.5
    }

    /// Get contrasting text color for a background
    func contrastingTextColor(for backgroundColor: UIColor) -> Color {
        return isLight(backgroundColor) ? .black : .white
    }

    /// Generate gradient colors from a base color
    func generateGradient(from baseColor: UIColor) -> [Color] {
        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0

        baseColor.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)

        // Create a gradient that darkens toward the bottom
        let topColor = UIColor(
            hue: hue,
            saturation: saturation * 0.8,
            brightness: min(1.0, brightness * 1.1),
            alpha: 1.0
        )
        let bottomColor = UIColor(
            hue: hue,
            saturation: saturation,
            brightness: brightness * 0.3,
            alpha: 1.0
        )

        return [Color(topColor), Color(bottomColor)]
    }
}

// MARK: - SwiftUI Integration

/// Observable wrapper for async color extraction
@MainActor
class DynamicColorLoader: ObservableObject {
    @Published var backgroundColor: Color = Color(red: 0.22, green: 0.22, blue: 0.22)
    @Published var textColor: Color = .white
    @Published var gradientColors: [Color] = [.black, .black]
    @Published var isLoaded = false

    private let extractor = ColorExtractor.shared

    func loadColor(from url: URL?) async {
        guard let url = url else { return }

        let uiColor = await extractor.extractColor(from: url)

        backgroundColor = Color(uiColor)
        textColor = extractor.contrastingTextColor(for: uiColor)
        gradientColors = extractor.generateGradient(from: uiColor)
        isLoaded = true
    }

    func loadColor(from image: UIImage) {
        guard let uiColor = extractor.extractColor(from: image) else { return }

        backgroundColor = Color(uiColor)
        textColor = extractor.contrastingTextColor(for: uiColor)
        gradientColors = extractor.generateGradient(from: uiColor)
        isLoaded = true
    }
}

// MARK: - View Modifier

struct DynamicBackgroundModifier: ViewModifier {
    @StateObject private var colorLoader = DynamicColorLoader()
    let imageURL: URL?

    func body(content: Content) -> some View {
        content
            .background {
                if colorLoader.isLoaded {
                    LinearGradient(
                        colors: colorLoader.gradientColors,
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .ignoresSafeArea()
                } else {
                    Color.black
                        .ignoresSafeArea()
                }
            }
            .foregroundStyle(colorLoader.textColor)
            .task {
                await colorLoader.loadColor(from: imageURL)
            }
    }
}

extension View {
    /// Apply dynamic background based on cover image
    func dynamicBackground(from imageURL: URL?) -> some View {
        modifier(DynamicBackgroundModifier(imageURL: imageURL))
    }
}

// MARK: - Preview

#Preview("Color Extraction") {
    VStack(spacing: 20) {
        Text("Dynamic Color Demo")
            .font(.title)
            .padding()
            .background(Color.blue.opacity(0.2))
            .clipShape(RoundedRectangle(cornerRadius: 10))

        HStack(spacing: 10) {
            // Simulated extracted colors
            ForEach(0..<5) { i in
                Circle()
                    .fill(Color(hue: Double(i) / 5, saturation: 0.7, brightness: 0.8))
                    .frame(width: 50, height: 50)
            }
        }
    }
    .padding()
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color.black)
}
