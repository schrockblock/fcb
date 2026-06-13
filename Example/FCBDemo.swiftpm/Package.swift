// swift-tools-version: 6.3
import PackageDescription
import AppleProductTypes

let package = Package(
    name: "FCBDemo",
    platforms: [.iOS("17.0")],
    products: [
        .iOSApplication(
            name: "FCBDemo",
            targets: ["AppModule"],
            bundleIdentifier: "com.fcb.demo",
            teamIdentifier: "",
            displayVersion: "1.0",
            bundleVersion: "1",
            appIcon: .placeholder(icon: .bluetooth),
            accentColor: .presetColor(.blue),
            supportedDeviceFamilies: [.phone, .pad],
            supportedInterfaceOrientations: [.portrait],
            capabilities: [
                .bluetoothAlways(purposeString: "FCBDemo uses Bluetooth to scan, connect to, and advertise BLE services.")
            ]
        )
    ],
    dependencies: [
        .package(path: "../FCBDemoFeatures"),
    ],
    targets: [
        .executableTarget(
            name: "AppModule",
            dependencies: [
                .product(name: "FCBDemoFeatures", package: "FCBDemoFeatures"),
            ],
            path: "."
        )
    ],
    swiftLanguageModes: [.v6]
)
