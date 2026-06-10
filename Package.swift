// swift-tools-version: 6.3

import PackageDescription

let package = Package(
    name: "FCB",
    platforms: [.iOS(.v17), .macOS(.v13)],
    products: [
        .library(name: "FCB", targets: ["FCB"]),
        .library(name: "FCBComposable", targets: ["FCBComposable"]),
    ],
    dependencies: [
        .package(url: "https://github.com/pointfreeco/swift-composable-architecture", from: "1.0.0"),
    ],
    targets: [
        .target(name: "FCB"),
        .target(
            name: "FCBComposable",
            dependencies: [
                "FCB",
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
            ]
        ),
        .testTarget(name: "FCBTests", dependencies: ["FCB"]),
        .testTarget(name: "FCBComposableTests", dependencies: ["FCBComposable"]),
    ],
    swiftLanguageModes: [.v6]
)
