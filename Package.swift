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
        .package(url: "https://source.skip.tools/skip-fuse-ui.git", "1.0.0"..<"1.17.0"),
        .package(url: "https://github.com/Flight-School/AnyCodable", from: "0.6.7"),
        .package(url: "https://github.com/getsentry/sentry-cocoa.git", from: "9.26.0")
    ],
    targets: [
        .target(name: "Audiobookphile", dependencies: [
            .product(name: "SkipFuseUI", package: "skip-fuse-ui"),
            "AnyCodable",
            .product(name: "Sentry", package: "sentry-cocoa", condition: .when(platforms: [.iOS, .macOS]))
        ], resources: [.process("Resources")]),
        .testTarget(name: "AudiobookphileTests", dependencies: ["Audiobookphile"]),
    ]
)
