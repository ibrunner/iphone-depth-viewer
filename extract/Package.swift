// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "depth-extract",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.3.0"),
    ],
    targets: [
        .target(name: "DepthExtractKit"),
        .executableTarget(
            name: "depth-extract",
            dependencies: [
                "DepthExtractKit",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ]),
        .testTarget(name: "DepthExtractKitTests", dependencies: ["DepthExtractKit"]),
    ]
)
