// swift-tools-version: 6.0
// This is a Skip (https://skip.dev) package.
import PackageDescription

let package = Package(
    name: "audiobookphile-app-native",
    defaultLocalization: "en",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "Audiobookphile", type: .dynamic, targets: ["Audiobookphile"]),
    ],
    dependencies: [
        .package(url: "https://github.com/skiptools/skip.git", from: "1.8.14"),
        .package(url: "https://github.com/skiptools/skip-fuse-ui.git", from: "1.0.0")
    ],
    targets: [
        .target(name: "Audiobookphile", dependencies: [
            .product(name: "SkipFuseUI", package: "skip-fuse-ui")
        ], resources: [.process("Resources")]),
    ]
)
