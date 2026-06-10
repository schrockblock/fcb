// swift-tools-version: 6.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "FCB",
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "FCB",
            targets: ["FCB"]
        ),
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "FCB"
        ),
        .testTarget(
            name: "FCBTests",
            dependencies: ["FCB"]
        ),
    ],
    swiftLanguageModes: [.v6]
)
