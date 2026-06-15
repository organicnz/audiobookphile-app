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
        .package(url: "https://source.skip.tools/skip.git", from: "1.8.14"),
        .package(url: "https://source.skip.tools/skip-fuse-ui.git", from: "1.0.0"),
        .package(url: "https://github.com/Flight-School/AnyCodable", from: "0.6.7")
    ],
    targets: [
        .target(name: "Audiobookphile", dependencies: [
            .product(name: "SkipFuseUI", package: "skip-fuse-ui"),
            "AnyCodable"
        ], resources: [.process("Resources")]),
    ]
)
