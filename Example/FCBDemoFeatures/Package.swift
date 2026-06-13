// swift-tools-version: 6.3

import PackageDescription

let package = Package(
    name: "FCBDemoFeatures",
    platforms: [.iOS(.v17), .macOS(.v13)],
    products: [
        .library(name: "FCBDemoFeatures", targets: ["FCBDemoFeatures"]),
    ],
    dependencies: [
        .package(path: "../.."),
    ],
    targets: [
        .target(
            name: "FCBDemoFeatures",
            dependencies: [
                .product(name: "FCBComposable", package: "FCB"),
            ]
        ),
        .testTarget(
            name: "FCBDemoFeaturesTests",
            dependencies: ["FCBDemoFeatures"]
        ),
    ],
    swiftLanguageModes: [.v6]
)
