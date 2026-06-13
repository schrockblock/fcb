# FCBDemo Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a SwiftUI + TCA iOS demo app under `Example/` that exercises the full surface of `BluetoothCentralClient` and `BluetoothPeripheralClient` from FCBComposable, with TestStore-based tests for every Reducer.

**Architecture:** Two-package layout: `Example/FCBDemoFeatures/` is a SwiftPM library containing all reducers, value types, and SwiftUI views — testable via `swift test`. `Example/FCBDemo.swiftpm/` is a Swift Playgrounds App Project that pulls in `FCBDemoFeatures` and provides the `@main App` + Info.plist-equivalent permissions. This split lets reducers be tested with `swift test` while the actual iOS app builds via Xcode's `.iOSApplication` SwiftPM product type.

**Tech Stack:** Swift 6.3, iOS 17+, SwiftUI, swift-composable-architecture 1.x (already a transitive dependency via FCBComposable), Swift Testing for unit tests, TCA `TestStore` for reducer tests.

---

## Spec reference

Implements `docs/superpowers/specs/2026-06-12-fcb-demo-app-design.md`. Mapping:
- **AppFeature** → Task 11.
- **CentralFeature** → Task 4.
- **PeripheralDetailFeature** → Task 5.
- **GATTBuilderFeature** → Task 7.
- **AdvertisingFeature** → Task 8.
- **RequestLogFeature** → Task 9.
- **PeripheralFeature** (composer) → Task 10.
- **Shared utilities (HexCoding, CBUUIDParsing, PreviewDependencies)** → Task 3.
- **iOS app shell + Info.plist permissions** → Task 12.
- **Smoke build / final test run** → Task 13.

## File layout

```
Example/
├── FCBDemoFeatures/
│   ├── Package.swift                              # iOS-only library, depends on ../..
│   ├── Sources/FCBDemoFeatures/
│   │   ├── Shared/
│   │   │   ├── HexCoding.swift
│   │   │   ├── CBUUIDParsing.swift
│   │   │   └── PreviewDependencies.swift
│   │   ├── App/
│   │   │   ├── AppFeature.swift
│   │   │   └── AppView.swift
│   │   ├── Central/
│   │   │   ├── CentralFeature.swift
│   │   │   ├── CentralView.swift
│   │   │   ├── PeripheralDetailFeature.swift
│   │   │   └── PeripheralDetailView.swift
│   │   └── Peripheral/
│   │       ├── PeripheralFeature.swift
│   │       ├── PeripheralView.swift
│   │       ├── GATTBuilderFeature.swift
│   │       ├── GATTBuilderView.swift
│   │       ├── AdvertisingFeature.swift
│   │       ├── AdvertisingView.swift
│   │       ├── RequestLogFeature.swift
│   │       └── RequestLogView.swift
│   └── Tests/FCBDemoFeaturesTests/
│       ├── CentralFeatureTests.swift
│       ├── PeripheralDetailFeatureTests.swift
│       ├── GATTBuilderFeatureTests.swift
│       ├── AdvertisingFeatureTests.swift
│       ├── RequestLogFeatureTests.swift
│       └── AppFeatureTests.swift
└── FCBDemo.swiftpm/
    ├── Package.swift                              # .iOSApplication product, depends on FCBDemoFeatures
    └── FCBDemoAppEntry.swift                      # @main, builds AppFeature store, renders AppView
```

## Task index

- **Phase A — Scaffolding:** Task 1 (`FCBDemoFeatures/Package.swift`), Task 2 (.gitignore), Task 3 (Shared utilities).
- **Phase B — Central tab:** Task 4 (CentralFeature), Task 5 (PeripheralDetailFeature), Task 6 (Central views).
- **Phase C — Peripheral tab:** Task 7 (GATTBuilderFeature), Task 8 (AdvertisingFeature), Task 9 (RequestLogFeature), Task 10 (PeripheralFeature composer + views).
- **Phase D — App composition:** Task 11 (AppFeature + AppView).
- **Phase E — iOS app shell:** Task 12 (FCBDemo.swiftpm).
- **Phase F — Wrap-up:** Task 13 (smoke build + full test run).

## Conventions

- Every test-bearing task follows the user-level CLAUDE.md mutation-testing protocol: (a) tests green, (b) batch-mutate the reducer, confirm targeted tests fail, (c) revert, confirm green.
- One command per `bash` line.
- Reducers use TCA's `@Reducer` macro, `@ObservableState`, `Reduce { ... }`, `Scope`, and `.run` / `.send` effects.
- TestStore tests are `@MainActor` and use exhaustive matching.
- Each task ends with a commit.
- Test fixture peripherals use a fixed `UUID(uuidString: "00000000-0000-0000-0000-00000000000N")!` pattern for determinism.

---

## Phase A — Scaffolding

### Task 1: Create `FCBDemoFeatures` SwiftPM library

**Files:**
- Create: `Example/FCBDemoFeatures/Package.swift`
- Create: `Example/FCBDemoFeatures/Sources/FCBDemoFeatures/Placeholder.swift`
- Create: `Example/FCBDemoFeatures/Tests/FCBDemoFeaturesTests/PlaceholderTests.swift`

- [ ] **Step 1: Create the directory structure**

Run: `mkdir -p Example/FCBDemoFeatures/Sources/FCBDemoFeatures/Shared`
Run: `mkdir -p Example/FCBDemoFeatures/Sources/FCBDemoFeatures/App`
Run: `mkdir -p Example/FCBDemoFeatures/Sources/FCBDemoFeatures/Central`
Run: `mkdir -p Example/FCBDemoFeatures/Sources/FCBDemoFeatures/Peripheral`
Run: `mkdir -p Example/FCBDemoFeatures/Tests/FCBDemoFeaturesTests`

- [ ] **Step 2: Create `Example/FCBDemoFeatures/Package.swift`**

```swift
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
```

- [ ] **Step 3: Create a placeholder source file so the target builds**

`Example/FCBDemoFeatures/Sources/FCBDemoFeatures/Placeholder.swift`:

```swift
// Placeholder — replaced by real content in Task 3.
internal struct _Placeholder {}
```

- [ ] **Step 4: Create a placeholder test file**

`Example/FCBDemoFeatures/Tests/FCBDemoFeaturesTests/PlaceholderTests.swift`:

```swift
import Testing
@testable import FCBDemoFeatures

struct PlaceholderTests {
    @Test func placeholderExists() {
        _ = _Placeholder()
    }
}
```

- [ ] **Step 5: Resolve and build**

Run: `swift package --package-path Example/FCBDemoFeatures resolve`
Expected: succeeds, downloading no new dependencies (FCB is local).

Run: `swift build --package-path Example/FCBDemoFeatures`
Expected: succeeds.

Run: `swift test --package-path Example/FCBDemoFeatures`
Expected: 1/1 pass.

- [ ] **Step 6: Commit**

Run: `git add Example/FCBDemoFeatures`
Run: `git commit -m "Scaffold FCBDemoFeatures SwiftPM library"`

---

### Task 2: Ignore Xcode build artifacts inside Example

**Files:**
- Modify: `.gitignore`

- [ ] **Step 1: Append to `.gitignore`**

Append these lines to `/Users/ell/development/ios/pods/FCB/.gitignore`:

```
# FCBDemo build artifacts
Example/FCBDemoFeatures/.build/
Example/FCBDemoFeatures/.swiftpm/
Example/FCBDemo.swiftpm/.build/
Example/FCBDemo.swiftpm/.swiftpm/configuration/registries.json
Example/FCBDemo.swiftpm/.swiftpm/xcode/package.xcworkspace/contents.xcworkspacedata
```

- [ ] **Step 2: Commit**

Run: `git add .gitignore`
Run: `git commit -m "Ignore FCBDemo build artifacts"`

---

### Task 3: Shared utilities (HexCoding, CBUUIDParsing, PreviewDependencies)

**Files:**
- Create: `Example/FCBDemoFeatures/Sources/FCBDemoFeatures/Shared/HexCoding.swift`
- Create: `Example/FCBDemoFeatures/Sources/FCBDemoFeatures/Shared/CBUUIDParsing.swift`
- Create: `Example/FCBDemoFeatures/Sources/FCBDemoFeatures/Shared/PreviewDependencies.swift`
- Create: `Example/FCBDemoFeatures/Tests/FCBDemoFeaturesTests/SharedTests.swift`
- Delete: `Example/FCBDemoFeatures/Sources/FCBDemoFeatures/Placeholder.swift`
- Delete: `Example/FCBDemoFeatures/Tests/FCBDemoFeaturesTests/PlaceholderTests.swift`

- [ ] **Step 1: Write the failing tests**

`Example/FCBDemoFeatures/Tests/FCBDemoFeaturesTests/SharedTests.swift`:

```swift
import CoreBluetooth
import Foundation
import Testing
@testable import FCBDemoFeatures

struct HexCodingTests {
    @Test func decodeValidHex() {
        #expect(HexCoding.decode("DEADBEEF") == Data([0xDE, 0xAD, 0xBE, 0xEF]))
    }
    @Test func decodeLowercaseHex() {
        #expect(HexCoding.decode("deadbeef") == Data([0xDE, 0xAD, 0xBE, 0xEF]))
    }
    @Test func decodeWithSpaces() {
        #expect(HexCoding.decode("DE AD BE EF") == Data([0xDE, 0xAD, 0xBE, 0xEF]))
    }
    @Test func decodeWith0xPrefix() {
        #expect(HexCoding.decode("0xDEAD") == Data([0xDE, 0xAD]))
    }
    @Test func decodeInvalidLength() {
        #expect(HexCoding.decode("ABC") == nil)
    }
    @Test func decodeInvalidChars() {
        #expect(HexCoding.decode("GG") == nil)
    }
    @Test func decodeEmpty() {
        #expect(HexCoding.decode("") == Data())
    }
    @Test func encodeRoundTrip() {
        let original = Data([0x01, 0x02, 0x03])
        #expect(HexCoding.encode(original) == "010203")
    }
}

struct CBUUIDParsingTests {
    @Test func parseShortUUID() {
        #expect(CBUUIDParsing.parse("180F") == CBUUID(string: "180F"))
    }
    @Test func parseFullUUID() {
        let s = "0000180F-0000-1000-8000-00805F9B34FB"
        #expect(CBUUIDParsing.parse(s) == CBUUID(string: s))
    }
    @Test func parseInvalid() {
        #expect(CBUUIDParsing.parse("nope") == nil)
    }
    @Test func parseTrimsWhitespace() {
        #expect(CBUUIDParsing.parse("  180F  ") == CBUUID(string: "180F"))
    }
    @Test func parseListBasic() {
        let parsed = CBUUIDParsing.parseList("180F, 2A19")
        #expect(parsed == [CBUUID(string: "180F"), CBUUID(string: "2A19")])
    }
    @Test func parseListSkipsInvalid() {
        let parsed = CBUUIDParsing.parseList("180F, nope, 2A19")
        #expect(parsed == [CBUUID(string: "180F"), CBUUID(string: "2A19")])
    }
    @Test func parseListEmpty() {
        #expect(CBUUIDParsing.parseList("") == [])
    }
}
```

- [ ] **Step 2: Run tests — expect compile failure**

Run: `swift test --package-path Example/FCBDemoFeatures --filter HexCodingTests`
Expected: cannot find `HexCoding`. Red phase.

- [ ] **Step 3: Write `HexCoding.swift`**

```swift
import Foundation

public enum HexCoding {
    public static func decode(_ input: String) -> Data? {
        let cleaned = input
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "0x", with: "", options: [.anchored, .caseInsensitive])
        guard cleaned.count.isMultiple(of: 2) else { return nil }
        var data = Data()
        data.reserveCapacity(cleaned.count / 2)
        var idx = cleaned.startIndex
        while idx < cleaned.endIndex {
            let next = cleaned.index(idx, offsetBy: 2)
            guard let byte = UInt8(cleaned[idx..<next], radix: 16) else { return nil }
            data.append(byte)
            idx = next
        }
        return data
    }

    public static func encode(_ data: Data) -> String {
        data.map { String(format: "%02X", $0) }.joined()
    }
}
```

- [ ] **Step 4: Write `CBUUIDParsing.swift`**

```swift
@preconcurrency import CoreBluetooth
import Foundation

public enum CBUUIDParsing {
    public static func parse(_ input: String) -> CBUUID? {
        let trimmed = input.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }
        // CBUUID(string:) accepts both 16-bit shorts (4 hex chars) and full 128-bit UUIDs.
        // It returns garbage for invalid input rather than nil, so validate first.
        let isShort = trimmed.count == 4 && trimmed.allSatisfy { $0.isHexDigit }
        let isFull = trimmed.count == 36 && UUID(uuidString: trimmed) != nil
        guard isShort || isFull else { return nil }
        return CBUUID(string: trimmed)
    }

    public static func parseList(_ input: String) -> [CBUUID] {
        input
            .split(separator: ",")
            .compactMap { parse(String($0)) }
    }
}
```

- [ ] **Step 5: Write `PreviewDependencies.swift`**

```swift
import ComposableArchitecture
import FCBComposable
import Foundation

extension DependencyValues {
    /// Returns a copy of these values with both BLE clients set to `previewValue`.
    /// Use in SwiftUI `#Preview` blocks: `withDependencies { $0.previewBluetooth() } operation: { … }`.
    public mutating func previewBluetooth() {
        bluetoothCentralClient = .previewValue
        bluetoothPeripheralClient = .previewValue
    }
}
```

- [ ] **Step 6: Delete placeholder files**

Run: `rm Example/FCBDemoFeatures/Sources/FCBDemoFeatures/Placeholder.swift`
Run: `rm Example/FCBDemoFeatures/Tests/FCBDemoFeaturesTests/PlaceholderTests.swift`

- [ ] **Step 7: Run tests — confirm pass**

Run: `swift test --package-path Example/FCBDemoFeatures`
Expected: 15/15 tests pass (8 HexCoding + 7 CBUUIDParsing).

- [ ] **Step 8: Mutation test**

In `HexCoding.decode`, replace the `while` loop body with `return nil`. In `CBUUIDParsing.parse`, replace the `isShort || isFull` guard with `return nil`.

Run: `swift test --package-path Example/FCBDemoFeatures`
Expected: most HexCoding decode tests fail; `decodeInvalidLength`, `decodeInvalidChars`, `decodeEmpty` still pass. CBUUIDParsing tests all fail except `parseInvalid` and `parseListEmpty`.

- [ ] **Step 9: Revert, confirm green**

Rewrite the two files with original content from Steps 3-4.

Run: `swift test --package-path Example/FCBDemoFeatures`
Expected: 15/15 pass.

- [ ] **Step 10: Commit**

Run: `git add Example/FCBDemoFeatures`
Run: `git commit -m "Add HexCoding, CBUUIDParsing, PreviewDependencies utilities"`

---

## Phase B — Central tab

### Task 4: `CentralFeature` reducer + tests

**Files:**
- Create: `Example/FCBDemoFeatures/Sources/FCBDemoFeatures/Central/CentralFeature.swift`
- Create: `Example/FCBDemoFeatures/Tests/FCBDemoFeaturesTests/CentralFeatureTests.swift`

- [ ] **Step 1: Write the failing tests**

`Example/FCBDemoFeatures/Tests/FCBDemoFeaturesTests/CentralFeatureTests.swift`:

```swift
import ComposableArchitecture
@preconcurrency import CoreBluetooth
import FCBComposable
import Foundation
import Testing
@testable import FCBDemoFeatures

@MainActor
struct CentralFeatureTests {
    private static let fixtureID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
    private static func fixture(rssi: Int = -55, name: String? = "Sensor") -> DiscoveredPeripheral {
        DiscoveredPeripheral(
            peripheral: Peripheral(id: fixtureID, name: name, state: .disconnected),
            advertisementData: AdvertisementData(localName: name),
            rssi: rssi
        )
    }

    @Test func onAppearSubscribesToStateStream() async {
        let store = TestStore(initialState: CentralFeature.State()) {
            CentralFeature()
        } withDependencies: {
            $0.bluetoothCentralClient.state = {
                AsyncStream { cont in
                    cont.yield(.poweredOn)
                    cont.finish()
                }
            }
        }
        store.exhaustivity = .off
        await store.send(.onAppear)
        await store.receive(\.stateStreamUpdate) { $0.managerState = .poweredOn }
    }

    @Test func startScanRequiresPoweredOn() async {
        let store = TestStore(initialState: CentralFeature.State()) {
            CentralFeature()
        } withDependencies: {
            $0.bluetoothCentralClient.scan = { _, _ in .never }
            $0.bluetoothCentralClient.stopScan = { }
        }
        await store.send(.startScanTapped) {
            $0.scanError = "Bluetooth is not powered on."
        }
    }

    @Test func startScanYieldsDiscoveredPeripherals() async {
        let store = TestStore(
            initialState: CentralFeature.State(managerState: .poweredOn)
        ) {
            CentralFeature()
        } withDependencies: {
            $0.bluetoothCentralClient.scan = { _, _ in
                AsyncStream { cont in
                    cont.yield(Self.fixture())
                    cont.finish()
                }
            }
            $0.bluetoothCentralClient.stopScan = { }
        }
        await store.send(.startScanTapped) { $0.isScanning = true }
        await store.receive(\.scanEvent) {
            $0.discovered = [Self.fixture()]
        }
        await store.send(.stopScanTapped) { $0.isScanning = false }
    }

    @Test func scanDeduplicatesByPeripheralID() async {
        let store = TestStore(
            initialState: CentralFeature.State(
                managerState: .poweredOn,
                discovered: [Self.fixture(rssi: -80)]
            )
        ) {
            CentralFeature()
        }
        await store.send(.scanEvent(Self.fixture(rssi: -40))) {
            $0.discovered = [Self.fixture(rssi: -40)]
        }
        #expect(store.state.discovered.count == 1)
    }

    @Test func clearListEmptiesDiscovered() async {
        let store = TestStore(
            initialState: CentralFeature.State(discovered: [Self.fixture()])
        ) {
            CentralFeature()
        }
        await store.send(.clearListTapped) { $0.discovered = [] }
    }
}
```

- [ ] **Step 2: Run tests — expect compile failure**

Run: `swift test --package-path Example/FCBDemoFeatures --filter CentralFeatureTests`
Expected: cannot find `CentralFeature`. Red phase.

- [ ] **Step 3: Write `CentralFeature.swift`**

```swift
import ComposableArchitecture
@preconcurrency import CoreBluetooth
import FCBComposable
import Foundation

@Reducer
public struct CentralFeature {
    @ObservableState
    public struct State: Equatable {
        public var managerState: CBManagerState
        public var isScanning: Bool
        public var discovered: IdentifiedArrayOf<DiscoveredPeripheralRow>
        public var path: StackState<PeripheralDetailFeature.State>
        public var scanError: String?

        public init(
            managerState: CBManagerState = .unknown,
            isScanning: Bool = false,
            discovered: IdentifiedArrayOf<DiscoveredPeripheralRow> = [],
            path: StackState<PeripheralDetailFeature.State> = .init(),
            scanError: String? = nil
        ) {
            self.managerState = managerState
            self.isScanning = isScanning
            self.discovered = discovered
            self.path = path
            self.scanError = scanError
        }
    }

    public enum Action {
        case onAppear
        case stateStreamUpdate(CBManagerState)
        case startScanTapped
        case stopScanTapped
        case scanEvent(DiscoveredPeripheral)
        case peripheralTapped(UUID)
        case clearListTapped
        case path(StackActionOf<PeripheralDetailFeature>)
    }

    @Dependency(\.bluetoothCentralClient) var client

    enum CancelID: Hashable {
        case stateStream
        case scan
    }

    public init() {}

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                return .run { send in
                    for await s in client.state() {
                        await send(.stateStreamUpdate(s))
                    }
                }
                .cancellable(id: CancelID.stateStream, cancelInFlight: true)

            case .stateStreamUpdate(let s):
                state.managerState = s
                return .none

            case .startScanTapped:
                guard state.managerState == .poweredOn else {
                    state.scanError = "Bluetooth is not powered on."
                    return .none
                }
                state.isScanning = true
                state.scanError = nil
                return .run { send in
                    for await peripheral in client.scan(nil, nil) {
                        await send(.scanEvent(peripheral))
                    }
                }
                .cancellable(id: CancelID.scan, cancelInFlight: true)

            case .stopScanTapped:
                state.isScanning = false
                return .merge(
                    .run { _ in await client.stopScan() },
                    .cancel(id: CancelID.scan)
                )

            case .scanEvent(let discovered):
                state.discovered[id: discovered.peripheral.id] =
                    DiscoveredPeripheralRow(discovered: discovered)
                return .none

            case .peripheralTapped(let id):
                guard let row = state.discovered[id: id] else { return .none }
                state.path.append(
                    PeripheralDetailFeature.State(peripheral: row.discovered.peripheral)
                )
                return .none

            case .clearListTapped:
                state.discovered.removeAll()
                return .none

            case .path:
                return .none
            }
        }
        .forEach(\.path, action: \.path) {
            PeripheralDetailFeature()
        }
    }
}

public struct DiscoveredPeripheralRow: Equatable, Identifiable {
    public var id: UUID { discovered.peripheral.id }
    public var discovered: DiscoveredPeripheral

    public init(discovered: DiscoveredPeripheral) {
        self.discovered = discovered
    }
}
```

Note: `DiscoveredPeripheralRow` wraps `DiscoveredPeripheral` because `IdentifiedArrayOf` needs `Identifiable` conformance with an `id` property. `DiscoveredPeripheral` is `Hashable` but does not declare `Identifiable` (its identity is `peripheral.id`, which the wrapper exposes).

Also note: `PeripheralDetailFeature` is referenced but doesn't exist yet (Task 5). For this task to compile, add a temporary stub at the bottom of `CentralFeature.swift`:

```swift
// Temporary stub — replaced by full implementation in Task 5.
@Reducer
public struct PeripheralDetailFeature {
    @ObservableState
    public struct State: Equatable, Identifiable {
        public let peripheral: Peripheral
        public var id: UUID { peripheral.id }
    }
    public enum Action { case _placeholder }
    public init() {}
    public var body: some ReducerOf<Self> {
        Reduce { _, _ in .none }
    }
}
```

Task 5 deletes the stub and creates `PeripheralDetailFeature.swift` with the real reducer.

- [ ] **Step 4: Run tests — confirm pass**

Run: `swift test --package-path Example/FCBDemoFeatures --filter CentralFeatureTests`
Expected: 5/5 pass.

- [ ] **Step 5: Mutation test**

In `startScanTapped`'s reducer body, change `state.isScanning = true` to `state.isScanning = false`. In `scanEvent`, change `state.discovered[id: discovered.peripheral.id] = ...` to no-op (delete the line). In `clearListTapped`, change `state.discovered.removeAll()` to no-op.

Run: `swift test --package-path Example/FCBDemoFeatures --filter CentralFeatureTests`
Expected: `startScanYieldsDiscoveredPeripherals`, `scanDeduplicatesByPeripheralID`, `clearListEmptiesDiscovered` all fail. `onAppearSubscribesToStateStream` and `startScanRequiresPoweredOn` still pass.

- [ ] **Step 6: Revert, confirm green**

Rewrite the file from Step 3. Run tests. Expect 5/5 pass.

- [ ] **Step 7: Commit**

Run: `git add Example/FCBDemoFeatures/Sources/FCBDemoFeatures/Central/CentralFeature.swift Example/FCBDemoFeatures/Tests/FCBDemoFeaturesTests/CentralFeatureTests.swift`
Run: `git commit -m "Add CentralFeature reducer with scan and navigation"`

---

### Task 5: `PeripheralDetailFeature` reducer + tests

**Files:**
- Modify: `Example/FCBDemoFeatures/Sources/FCBDemoFeatures/Central/CentralFeature.swift` (remove temporary stub at the bottom)
- Create: `Example/FCBDemoFeatures/Sources/FCBDemoFeatures/Central/PeripheralDetailFeature.swift`
- Create: `Example/FCBDemoFeatures/Tests/FCBDemoFeaturesTests/PeripheralDetailFeatureTests.swift`

- [ ] **Step 1: Write the failing tests**

`Example/FCBDemoFeatures/Tests/FCBDemoFeaturesTests/PeripheralDetailFeatureTests.swift`:

```swift
import ComposableArchitecture
@preconcurrency import CoreBluetooth
import FCBComposable
import Foundation
import Testing
@testable import FCBDemoFeatures

@MainActor
struct PeripheralDetailFeatureTests {
    private static let pid = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
    private static let serviceID = CBUUID(string: "180F")
    private static let charID = CBUUID(string: "2A19")

    private static func sampleService() -> Service {
        Service(id: serviceID, peripheralID: pid, isPrimary: true)
    }
    private static func sampleCharacteristic(properties: CBCharacteristicProperties = [.read, .write, .notify]) -> Characteristic {
        Characteristic(id: charID, serviceID: serviceID, peripheralID: pid,
                       properties: properties, value: nil, isNotifying: false)
    }
    private static func samplePeripheral() -> Peripheral {
        Peripheral(id: pid, name: "Sensor", state: .disconnected)
    }

    @Test func connectSuccessPathTransitionsToConnected() async {
        let connected = Peripheral(id: pid, name: "Sensor", state: .connected)
        let store = TestStore(
            initialState: PeripheralDetailFeature.State(peripheral: samplePeripheral())
        ) {
            PeripheralDetailFeature()
        } withDependencies: {
            $0.bluetoothCentralClient.connect = { _, _ in connected }
            $0.bluetoothCentralClient.events = { .never }
        }
        store.exhaustivity = .off
        await store.send(.connectTapped) { $0.connectionState = .connecting }
        await store.receive(\.connected) { $0.connectionState = .connected }
    }

    @Test func connectFailureSurfacesError() async {
        let store = TestStore(
            initialState: PeripheralDetailFeature.State(peripheral: samplePeripheral())
        ) {
            PeripheralDetailFeature()
        } withDependencies: {
            $0.bluetoothCentralClient.connect = { _, _ in
                throw BluetoothError.connectionFailed(peripheralID: Self.pid, underlying: nil)
            }
            $0.bluetoothCentralClient.events = { .never }
        }
        store.exhaustivity = .off
        await store.send(.connectTapped) { $0.connectionState = .connecting }
        await store.receive(\.connectFailed) {
            $0.connectError = "connectionFailed(peripheralID: \(Self.pid), underlying: nil)"
            $0.connectionState = .disconnected
        }
    }

    @Test func discoverServicesPopulatesList() async {
        let store = TestStore(
            initialState: PeripheralDetailFeature.State(
                peripheral: samplePeripheral(),
                connectionState: .connected
            )
        ) {
            PeripheralDetailFeature()
        } withDependencies: {
            $0.bluetoothCentralClient.discoverServices = { _, _ in [Self.sampleService()] }
            $0.bluetoothCentralClient.events = { .never }
        }
        store.exhaustivity = .off
        await store.send(.discoverServicesTapped)
        await store.receive(\.servicesDiscovered) {
            $0.services = [Self.sampleService()]
        }
    }

    @Test func readValueSetsCharacteristicValue() async {
        let store = TestStore(
            initialState: PeripheralDetailFeature.State(
                peripheral: samplePeripheral(),
                connectionState: .connected
            )
        ) {
            PeripheralDetailFeature()
        } withDependencies: {
            $0.bluetoothCentralClient.readValue = { _, _ in Data([0x42]) }
            $0.bluetoothCentralClient.events = { .never }
        }
        store.exhaustivity = .off
        await store.send(.readTapped(characteristicID: Self.charID))
        await store.receive(\.valueRead) {
            $0.characteristicValues[Self.charID] = Data([0x42])
        }
    }

    @Test func writeWithInvalidHexSetsError() async {
        let store = TestStore(
            initialState: PeripheralDetailFeature.State(
                peripheral: samplePeripheral(),
                connectionState: .connected,
                pendingWriteText: [Self.charID: "NOT_HEX"]
            )
        ) {
            PeripheralDetailFeature()
        } withDependencies: {
            $0.bluetoothCentralClient.events = { .never }
            $0.bluetoothCentralClient.writeValue = { _, _, _, _ in
                Issue.record("writeValue should not be called for invalid hex")
            }
        }
        await store.send(.writeTapped(characteristicID: Self.charID, withResponse: true)) {
            $0.operationError = "Invalid hex"
        }
    }

    @Test func disconnectClearsState() async {
        let store = TestStore(
            initialState: PeripheralDetailFeature.State(
                peripheral: samplePeripheral(),
                connectionState: .connected,
                services: [Self.sampleService()],
                characteristics: [Self.serviceID: [Self.sampleCharacteristic()]],
                characteristicValues: [Self.charID: Data([0xAB])],
                notifyingCharacteristics: [Self.charID]
            )
        ) {
            PeripheralDetailFeature()
        } withDependencies: {
            $0.bluetoothCentralClient.disconnect = { _ in }
            $0.bluetoothCentralClient.events = { .never }
        }
        store.exhaustivity = .off
        await store.send(.disconnectTapped)
        await store.receive(\.disconnected) {
            $0.connectionState = .disconnected
            $0.services = []
            $0.characteristics = [:]
            $0.characteristicValues = [:]
            $0.notifyingCharacteristics = []
        }
    }
}
```

- [ ] **Step 2: Remove the temporary stub from `CentralFeature.swift`**

Delete the `// Temporary stub — replaced by full implementation in Task 5.` block (the entire `@Reducer public struct PeripheralDetailFeature { ... }` declaration at the bottom of `CentralFeature.swift`).

- [ ] **Step 3: Run tests — expect compile failure**

Run: `swift test --package-path Example/FCBDemoFeatures --filter PeripheralDetailFeatureTests`
Expected: cannot find `PeripheralDetailFeature` (after the stub deletion). Red phase.

- [ ] **Step 4: Write `PeripheralDetailFeature.swift`**

```swift
import ComposableArchitecture
@preconcurrency import CoreBluetooth
import FCBComposable
import Foundation

@Reducer
public struct PeripheralDetailFeature {
    @ObservableState
    public struct State: Equatable, Identifiable {
        public let peripheral: Peripheral
        public var id: UUID { peripheral.id }
        public var connectionState: ConnectionState
        public var services: IdentifiedArrayOf<ServiceRow>
        public var characteristics: [CBUUID: IdentifiedArrayOf<CharacteristicRow>]
        public var characteristicValues: [CBUUID: Data]
        public var notifyingCharacteristics: Set<CBUUID>
        public var connectError: String?
        public var operationError: String?
        public var pendingWriteText: [CBUUID: String]

        public init(
            peripheral: Peripheral,
            connectionState: ConnectionState = .disconnected,
            services: IdentifiedArrayOf<ServiceRow> = [],
            characteristics: [CBUUID: IdentifiedArrayOf<CharacteristicRow>] = [:],
            characteristicValues: [CBUUID: Data] = [:],
            notifyingCharacteristics: Set<CBUUID> = [],
            connectError: String? = nil,
            operationError: String? = nil,
            pendingWriteText: [CBUUID: String] = [:]
        ) {
            self.peripheral = peripheral
            self.connectionState = connectionState
            self.services = services
            self.characteristics = characteristics
            self.characteristicValues = characteristicValues
            self.notifyingCharacteristics = notifyingCharacteristics
            self.connectError = connectError
            self.operationError = operationError
            self.pendingWriteText = pendingWriteText
        }
    }

    public enum Action {
        case onAppear
        case connectTapped
        case disconnectTapped
        case connected(Peripheral)
        case connectFailed(BluetoothError)
        case disconnected
        case eventStreamEvent(CentralEvent)
        case discoverServicesTapped
        case servicesDiscovered([Service])
        case servicesDiscoveryFailed(BluetoothError)
        case discoverCharacteristicsTapped(serviceID: CBUUID)
        case characteristicsDiscovered(serviceID: CBUUID, [Characteristic])
        case readTapped(characteristicID: CBUUID)
        case valueRead(characteristicID: CBUUID, Data)
        case writeTextChanged(characteristicID: CBUUID, String)
        case writeTapped(characteristicID: CBUUID, withResponse: Bool)
        case writeCompleted(characteristicID: CBUUID)
        case toggleNotifyTapped(characteristicID: CBUUID)
        case notifyValueReceived(characteristicID: CBUUID, Data)
        case operationFailed(BluetoothError)
    }

    @Dependency(\.bluetoothCentralClient) var client

    enum CancelID: Hashable {
        case events(UUID)
        case notify(CBUUID)
    }

    public init() {}

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                let pid = state.peripheral.id
                return .run { send in
                    for await event in client.events() {
                        await send(.eventStreamEvent(event))
                    }
                }
                .cancellable(id: CancelID.events(pid), cancelInFlight: true)

            case .connectTapped:
                state.connectionState = .connecting
                state.connectError = nil
                let pid = state.peripheral.id
                return .run { send in
                    do {
                        let p = try await client.connect(pid, nil)
                        await send(.connected(p))
                    } catch let error as BluetoothError {
                        await send(.connectFailed(error))
                    } catch {
                        await send(.connectFailed(BluetoothError(error)))
                    }
                }

            case .disconnectTapped:
                let pid = state.peripheral.id
                return .run { send in
                    do {
                        try await client.disconnect(pid)
                        await send(.disconnected)
                    } catch let error as BluetoothError {
                        await send(.operationFailed(error))
                    } catch {
                        await send(.operationFailed(BluetoothError(error)))
                    }
                }

            case .connected(let p):
                state.connectionState = p.state
                return .none

            case .connectFailed(let err):
                state.connectionState = .disconnected
                state.connectError = "\(err)"
                return .none

            case .disconnected:
                state.connectionState = .disconnected
                state.services = []
                state.characteristics = [:]
                state.characteristicValues = [:]
                state.notifyingCharacteristics = []
                return .none

            case .eventStreamEvent(let event):
                if case .didDisconnect(let p, _) = event, p.id == state.peripheral.id {
                    state.connectionState = .disconnected
                    state.services = []
                    state.characteristics = [:]
                    state.characteristicValues = [:]
                    state.notifyingCharacteristics = []
                }
                return .none

            case .discoverServicesTapped:
                let pid = state.peripheral.id
                return .run { send in
                    do {
                        let services = try await client.discoverServices(pid, nil)
                        await send(.servicesDiscovered(services))
                    } catch let error as BluetoothError {
                        await send(.servicesDiscoveryFailed(error))
                    } catch {
                        await send(.servicesDiscoveryFailed(BluetoothError(error)))
                    }
                }

            case .servicesDiscovered(let services):
                state.services = IdentifiedArray(uniqueElements: services.map(ServiceRow.init))
                return .none

            case .servicesDiscoveryFailed(let err):
                state.operationError = "\(err)"
                return .none

            case .discoverCharacteristicsTapped(let serviceID):
                let pid = state.peripheral.id
                return .run { send in
                    do {
                        let chars = try await client.discoverCharacteristics(pid, serviceID, nil)
                        await send(.characteristicsDiscovered(serviceID: serviceID, chars))
                    } catch let error as BluetoothError {
                        await send(.operationFailed(error))
                    } catch {
                        await send(.operationFailed(BluetoothError(error)))
                    }
                }

            case .characteristicsDiscovered(let serviceID, let chars):
                state.characteristics[serviceID] = IdentifiedArray(uniqueElements: chars.map(CharacteristicRow.init))
                return .none

            case .readTapped(let cid):
                let pid = state.peripheral.id
                return .run { send in
                    do {
                        let data = try await client.readValue(pid, cid)
                        await send(.valueRead(characteristicID: cid, data))
                    } catch let error as BluetoothError {
                        await send(.operationFailed(error))
                    } catch {
                        await send(.operationFailed(BluetoothError(error)))
                    }
                }

            case .valueRead(let cid, let data):
                state.characteristicValues[cid] = data
                return .none

            case .writeTextChanged(let cid, let text):
                state.pendingWriteText[cid] = text
                return .none

            case .writeTapped(let cid, let withResponse):
                guard let data = HexCoding.decode(state.pendingWriteText[cid] ?? "") else {
                    state.operationError = "Invalid hex"
                    return .none
                }
                let pid = state.peripheral.id
                let type: CBCharacteristicWriteType = withResponse ? .withResponse : .withoutResponse
                return .run { send in
                    do {
                        try await client.writeValue(data, pid, cid, type)
                        await send(.writeCompleted(characteristicID: cid))
                    } catch let error as BluetoothError {
                        await send(.operationFailed(error))
                    } catch {
                        await send(.operationFailed(BluetoothError(error)))
                    }
                }

            case .writeCompleted(let cid):
                state.pendingWriteText[cid] = ""
                return .none

            case .toggleNotifyTapped(let cid):
                let pid = state.peripheral.id
                let enabling = !state.notifyingCharacteristics.contains(cid)
                if enabling {
                    state.notifyingCharacteristics.insert(cid)
                } else {
                    state.notifyingCharacteristics.remove(cid)
                }
                return .run { send in
                    do {
                        try await client.setNotify(enabling, pid, cid)
                        if enabling {
                            for try await data in client.notifications(pid, cid) {
                                await send(.notifyValueReceived(characteristicID: cid, data))
                            }
                        }
                    } catch let error as BluetoothError {
                        await send(.operationFailed(error))
                    } catch {
                        await send(.operationFailed(BluetoothError(error)))
                    }
                }
                .cancellable(id: CancelID.notify(cid), cancelInFlight: !enabling)

            case .notifyValueReceived(let cid, let data):
                state.characteristicValues[cid] = data
                return .none

            case .operationFailed(let err):
                state.operationError = "\(err)"
                return .none
            }
        }
    }
}

public struct ServiceRow: Equatable, Identifiable {
    public var id: CBUUID { service.id }
    public var service: Service
    public init(_ service: Service) { self.service = service }
}

public struct CharacteristicRow: Equatable, Identifiable {
    public var id: CBUUID { characteristic.id }
    public var characteristic: Characteristic
    public init(_ characteristic: Characteristic) { self.characteristic = characteristic }
}
```

- [ ] **Step 5: Adjust test expectations**

The tests in Step 1 expect `services: [Service]` but the reducer stores `IdentifiedArrayOf<ServiceRow>`. Update the test in `discoverServicesPopulatesList` to assert:

```swift
$0.services = [ServiceRow(Self.sampleService())]
```

And in `disconnectClearsState`, the initial state's `services:` argument needs to be:

```swift
services: [ServiceRow(Self.sampleService())]
```

And `characteristics:` needs:

```swift
characteristics: [Self.serviceID: [CharacteristicRow(Self.sampleCharacteristic())]]
```

- [ ] **Step 6: Run tests — confirm pass**

Run: `swift test --package-path Example/FCBDemoFeatures --filter PeripheralDetailFeatureTests`
Expected: 6/6 pass.

- [ ] **Step 7: Mutation test**

In `connectTapped`, change `state.connectionState = .connecting` to no-op. In `disconnected`, comment out the `state.services = []` line. In `writeTapped`'s `nil` branch, change `state.operationError = "Invalid hex"` to no-op.

Run: `swift test --package-path Example/FCBDemoFeatures --filter PeripheralDetailFeatureTests`
Expected: `connectSuccessPathTransitionsToConnected`, `disconnectClearsState`, `writeWithInvalidHexSetsError` all fail.

- [ ] **Step 8: Revert, confirm green**

Rewrite from Step 4 content. Run tests. Expect 6/6 pass.

- [ ] **Step 9: Commit**

Run: `git add Example/FCBDemoFeatures/Sources/FCBDemoFeatures/Central/PeripheralDetailFeature.swift Example/FCBDemoFeatures/Tests/FCBDemoFeaturesTests/PeripheralDetailFeatureTests.swift Example/FCBDemoFeatures/Sources/FCBDemoFeatures/Central/CentralFeature.swift`
Run: `git commit -m "Add PeripheralDetailFeature reducer"`

---

### Task 6: Central views

**Files:**
- Create: `Example/FCBDemoFeatures/Sources/FCBDemoFeatures/Central/CentralView.swift`
- Create: `Example/FCBDemoFeatures/Sources/FCBDemoFeatures/Central/PeripheralDetailView.swift`

No new tests (SwiftUI view tests are out of scope; views are exercised via compile-only).

- [ ] **Step 1: Write `CentralView.swift`**

```swift
import ComposableArchitecture
@preconcurrency import CoreBluetooth
import FCBComposable
import SwiftUI

public struct CentralView: View {
    @Bindable public var store: StoreOf<CentralFeature>

    public init(store: StoreOf<CentralFeature>) {
        self.store = store
    }

    public var body: some View {
        NavigationStack(path: $store.scope(state: \.path, action: \.path)) {
            VStack(spacing: 0) {
                banner
                controls
                List {
                    ForEach(sortedDiscovered) { row in
                        Button {
                            store.send(.peripheralTapped(row.id))
                        } label: {
                            rowView(row)
                        }
                    }
                }
                if let err = store.scanError {
                    Text(err).foregroundStyle(.red).padding(.horizontal)
                }
            }
            .navigationTitle("Central")
            .onAppear { store.send(.onAppear) }
        } destination: { detailStore in
            PeripheralDetailView(store: detailStore)
        }
    }

    private var banner: some View {
        Text("BLE: \(label(for: store.managerState))")
            .font(.caption)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(8)
            .background(.thinMaterial)
    }

    private var controls: some View {
        HStack {
            Button(store.isScanning ? "Stop Scan" : "Start Scan") {
                store.send(store.isScanning ? .stopScanTapped : .startScanTapped)
            }
            .disabled(!store.isScanning && store.managerState != .poweredOn)
            Spacer()
            Button("Clear", role: .destructive) {
                store.send(.clearListTapped)
            }
            .disabled(store.discovered.isEmpty)
        }
        .padding(.horizontal)
    }

    private var sortedDiscovered: [DiscoveredPeripheralRow] {
        store.discovered.elements.sorted { $0.discovered.rssi > $1.discovered.rssi }
    }

    @ViewBuilder
    private func rowView(_ row: DiscoveredPeripheralRow) -> some View {
        VStack(alignment: .leading) {
            Text(row.discovered.peripheral.name ?? "Unknown")
                .font(.body)
            HStack {
                Text(row.id.uuidString.prefix(8))
                    .font(.caption2.monospaced())
                Spacer()
                Text("\(row.discovered.rssi) dBm")
                    .font(.caption.monospaced())
            }
            .foregroundStyle(.secondary)
        }
    }

    private func label(for s: CBManagerState) -> String {
        switch s {
        case .poweredOn: return "Powered On"
        case .poweredOff: return "Powered Off"
        case .resetting: return "Resetting"
        case .unauthorized: return "Unauthorized"
        case .unsupported: return "Unsupported"
        case .unknown: return "Unknown"
        @unknown default: return "Unknown"
        }
    }
}

#Preview {
    CentralView(
        store: Store(initialState: CentralFeature.State()) {
            CentralFeature()
        } withDependencies: {
            $0.previewBluetooth()
        }
    )
}
```

- [ ] **Step 2: Write `PeripheralDetailView.swift`**

```swift
import ComposableArchitecture
@preconcurrency import CoreBluetooth
import FCBComposable
import SwiftUI

public struct PeripheralDetailView: View {
    @Bindable public var store: StoreOf<PeripheralDetailFeature>

    public init(store: StoreOf<PeripheralDetailFeature>) {
        self.store = store
    }

    public var body: some View {
        List {
            Section("Peripheral") {
                LabeledContent("Name", value: store.peripheral.name ?? "Unknown")
                LabeledContent("UUID", value: store.peripheral.id.uuidString)
                    .font(.caption.monospaced())
                LabeledContent("State", value: stateLabel)
                connectButtons
                if let err = store.connectError {
                    Text(err).foregroundStyle(.red)
                }
                if let err = store.operationError {
                    Text(err).foregroundStyle(.red)
                }
            }

            if store.connectionState == .connected {
                Section("Services") {
                    Button("Discover Services") {
                        store.send(.discoverServicesTapped)
                    }
                    ForEach(store.services) { row in
                        DisclosureGroup(row.id.uuidString) {
                            serviceCharacteristics(row.id)
                        }
                    }
                }
            }
        }
        .navigationTitle(store.peripheral.name ?? "Peripheral")
        .onAppear { store.send(.onAppear) }
    }

    @ViewBuilder private var connectButtons: some View {
        switch store.connectionState {
        case .disconnected:
            Button("Connect") { store.send(.connectTapped) }
        case .connecting:
            ProgressView("Connecting…")
        case .connected:
            Button("Disconnect", role: .destructive) { store.send(.disconnectTapped) }
        case .disconnecting:
            ProgressView("Disconnecting…")
        }
    }

    private var stateLabel: String {
        switch store.connectionState {
        case .disconnected: return "Disconnected"
        case .connecting: return "Connecting"
        case .connected: return "Connected"
        case .disconnecting: return "Disconnecting"
        }
    }

    @ViewBuilder
    private func serviceCharacteristics(_ serviceID: CBUUID) -> some View {
        Button("Discover Characteristics") {
            store.send(.discoverCharacteristicsTapped(serviceID: serviceID))
        }
        if let chars = store.characteristics[serviceID] {
            ForEach(chars) { row in
                characteristicView(row.characteristic)
            }
        }
    }

    @ViewBuilder
    private func characteristicView(_ c: Characteristic) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(c.id.uuidString).font(.caption.monospaced())
            HStack(spacing: 6) {
                if c.properties.contains(.read) { badge("R") }
                if c.properties.contains(.write) { badge("W") }
                if c.properties.contains(.writeWithoutResponse) { badge("Wn") }
                if c.properties.contains(.notify) { badge("N") }
                if c.properties.contains(.indicate) { badge("I") }
            }
            if let data = store.characteristicValues[c.id] {
                Text("Value: \(HexCoding.encode(data))").font(.caption.monospaced())
            }
            if c.properties.contains(.read) {
                Button("Read") {
                    store.send(.readTapped(characteristicID: c.id))
                }
            }
            if c.properties.contains(.write) || c.properties.contains(.writeWithoutResponse) {
                TextField("Hex to write", text: bindingFor(c.id))
                    .textInputAutocapitalization(.never)
                HStack {
                    if c.properties.contains(.write) {
                        Button("Write w/ Response") {
                            store.send(.writeTapped(characteristicID: c.id, withResponse: true))
                        }
                    }
                    if c.properties.contains(.writeWithoutResponse) {
                        Button("Write w/o Response") {
                            store.send(.writeTapped(characteristicID: c.id, withResponse: false))
                        }
                    }
                }
            }
            if c.properties.contains(.notify) || c.properties.contains(.indicate) {
                Toggle("Notify",
                       isOn: Binding(
                            get: { store.notifyingCharacteristics.contains(c.id) },
                            set: { _ in store.send(.toggleNotifyTapped(characteristicID: c.id)) }))
            }
        }
        .padding(.vertical, 6)
    }

    private func badge(_ text: String) -> some View {
        Text(text)
            .font(.caption2.bold())
            .padding(.horizontal, 6).padding(.vertical, 2)
            .background(Color.accentColor.opacity(0.2))
            .clipShape(Capsule())
    }

    private func bindingFor(_ cid: CBUUID) -> Binding<String> {
        Binding(
            get: { store.pendingWriteText[cid] ?? "" },
            set: { store.send(.writeTextChanged(characteristicID: cid, $0)) }
        )
    }
}
```

- [ ] **Step 3: Build — confirm compiles**

Run: `swift build --package-path Example/FCBDemoFeatures`
Expected: succeeds.

- [ ] **Step 4: Commit**

Run: `git add Example/FCBDemoFeatures/Sources/FCBDemoFeatures/Central`
Run: `git commit -m "Add CentralView and PeripheralDetailView"`

---

## Phase C — Peripheral tab

### Task 7: `GATTBuilderFeature` reducer + tests

**Files:**
- Create: `Example/FCBDemoFeatures/Sources/FCBDemoFeatures/Peripheral/GATTBuilderFeature.swift`
- Create: `Example/FCBDemoFeatures/Tests/FCBDemoFeaturesTests/GATTBuilderFeatureTests.swift`

- [ ] **Step 1: Write the failing tests**

```swift
import ComposableArchitecture
@preconcurrency import CoreBluetooth
import FCBComposable
import Foundation
import Testing
@testable import FCBDemoFeatures

@MainActor
struct GATTBuilderFeatureTests {
    @Test func addServiceWithValidUUIDAppends() async {
        let store = TestStore(
            initialState: GATTBuilderFeature.State(newServiceUUIDInput: "180F")
        ) {
            GATTBuilderFeature()
        }
        await store.send(.addServiceTapped) {
            $0.services = [DraftService(id: CBUUID(string: "180F"), isPrimary: true, characteristics: [])]
            $0.newServiceUUIDInput = ""
        }
    }

    @Test func addServiceWithInvalidUUIDSetsError() async {
        let store = TestStore(
            initialState: GATTBuilderFeature.State(newServiceUUIDInput: "nope")
        ) {
            GATTBuilderFeature()
        }
        await store.send(.addServiceTapped) {
            $0.publishError = "Invalid UUID"
        }
    }

    @Test func togglePropertyAddsOrRemovesBit() async {
        let serviceUUID = CBUUID(string: "180F")
        let charUUID = CBUUID(string: "2A19")
        let store = TestStore(
            initialState: GATTBuilderFeature.State(
                services: [DraftService(id: serviceUUID, isPrimary: true,
                                         characteristics: [DraftCharacteristic(
                                            id: charUUID,
                                            properties: [.read],
                                            permissions: [.readable],
                                            initialValueText: "")])]
            )
        ) {
            GATTBuilderFeature()
        }
        await store.send(.togglePropertyTapped(serviceID: serviceUUID, characteristicID: charUUID, .write)) {
            $0.services[id: serviceUUID]!.characteristics[id: charUUID]!.properties = [.read, .write]
        }
        await store.send(.togglePropertyTapped(serviceID: serviceUUID, characteristicID: charUUID, .write)) {
            $0.services[id: serviceUUID]!.characteristics[id: charUUID]!.properties = [.read]
        }
    }

    @Test func publishSuccessMarksPublishedID() async {
        let serviceUUID = CBUUID(string: "180F")
        let published = Service(id: serviceUUID, peripheralID: UUID(), isPrimary: true)
        let store = TestStore(
            initialState: GATTBuilderFeature.State(
                services: [DraftService(id: serviceUUID, isPrimary: true, characteristics: [])]
            )
        ) {
            GATTBuilderFeature()
        } withDependencies: {
            $0.bluetoothPeripheralClient.add = { _ in published }
        }
        store.exhaustivity = .off
        await store.send(.publishServiceTapped(serviceID: serviceUUID))
        await store.receive(\.servicePublished) {
            $0.publishedServiceIDs = [serviceUUID]
        }
    }

    @Test func publishFailureSurfacesError() async {
        let serviceUUID = CBUUID(string: "180F")
        let store = TestStore(
            initialState: GATTBuilderFeature.State(
                services: [DraftService(id: serviceUUID, isPrimary: true, characteristics: [])]
            )
        ) {
            GATTBuilderFeature()
        } withDependencies: {
            $0.bluetoothPeripheralClient.add = { _ in throw BluetoothError.poweredOff }
        }
        store.exhaustivity = .off
        await store.send(.publishServiceTapped(serviceID: serviceUUID))
        await store.receive(\.publishFailed) {
            $0.publishError = "poweredOff"
        }
    }
}
```

- [ ] **Step 2: Run tests — expect compile failure**

Run: `swift test --package-path Example/FCBDemoFeatures --filter GATTBuilderFeatureTests`
Expected: cannot find `GATTBuilderFeature`. Red phase.

- [ ] **Step 3: Write `GATTBuilderFeature.swift`**

```swift
import ComposableArchitecture
@preconcurrency import CoreBluetooth
import FCBComposable
import Foundation

public struct DraftService: Equatable, Identifiable {
    public var id: CBUUID
    public var isPrimary: Bool
    public var characteristics: IdentifiedArrayOf<DraftCharacteristic>

    public init(id: CBUUID, isPrimary: Bool, characteristics: IdentifiedArrayOf<DraftCharacteristic>) {
        self.id = id
        self.isPrimary = isPrimary
        self.characteristics = characteristics
    }
}

public struct DraftCharacteristic: Equatable, Identifiable {
    public var id: CBUUID
    public var properties: CBCharacteristicProperties
    public var permissions: CBAttributePermissions
    public var initialValueText: String

    public init(id: CBUUID, properties: CBCharacteristicProperties, permissions: CBAttributePermissions, initialValueText: String) {
        self.id = id
        self.properties = properties
        self.permissions = permissions
        self.initialValueText = initialValueText
    }

    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.id == rhs.id
            && lhs.properties.rawValue == rhs.properties.rawValue
            && lhs.permissions.rawValue == rhs.permissions.rawValue
            && lhs.initialValueText == rhs.initialValueText
    }
}

@Reducer
public struct GATTBuilderFeature {
    @ObservableState
    public struct State: Equatable {
        public var services: IdentifiedArrayOf<DraftService>
        public var publishedServiceIDs: Set<CBUUID>
        public var newServiceUUIDInput: String
        public var publishError: String?

        public init(
            services: IdentifiedArrayOf<DraftService> = [],
            publishedServiceIDs: Set<CBUUID> = [],
            newServiceUUIDInput: String = "",
            publishError: String? = nil
        ) {
            self.services = services
            self.publishedServiceIDs = publishedServiceIDs
            self.newServiceUUIDInput = newServiceUUIDInput
            self.publishError = publishError
        }
    }

    public enum Action {
        case newServiceUUIDChanged(String)
        case addServiceTapped
        case isPrimaryToggled(serviceID: CBUUID, Bool)
        case removeServiceTapped(serviceID: CBUUID)
        case addCharacteristicTapped(serviceID: CBUUID)
        case characteristicUUIDChanged(serviceID: CBUUID, characteristicID: CBUUID, String)
        case togglePropertyTapped(serviceID: CBUUID, characteristicID: CBUUID, CBCharacteristicProperties)
        case togglePermissionTapped(serviceID: CBUUID, characteristicID: CBUUID, CBAttributePermissions)
        case initialValueChanged(serviceID: CBUUID, characteristicID: CBUUID, String)
        case removeCharacteristicTapped(serviceID: CBUUID, characteristicID: CBUUID)
        case publishServiceTapped(serviceID: CBUUID)
        case servicePublished(CBUUID)
        case publishFailed(BluetoothError)
        case removeAllPublishedTapped
        case removeAllPublishedCompleted
    }

    @Dependency(\.bluetoothPeripheralClient) var client

    public init() {}

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .newServiceUUIDChanged(let text):
                state.newServiceUUIDInput = text
                return .none

            case .addServiceTapped:
                guard let uuid = CBUUIDParsing.parse(state.newServiceUUIDInput) else {
                    state.publishError = "Invalid UUID"
                    return .none
                }
                state.services.append(DraftService(id: uuid, isPrimary: true, characteristics: []))
                state.newServiceUUIDInput = ""
                state.publishError = nil
                return .none

            case .isPrimaryToggled(let sid, let value):
                state.services[id: sid]?.isPrimary = value
                return .none

            case .removeServiceTapped(let sid):
                let wasPublished = state.publishedServiceIDs.contains(sid)
                state.services.remove(id: sid)
                state.publishedServiceIDs.remove(sid)
                if wasPublished {
                    return .run { _ in await client.remove(sid) }
                }
                return .none

            case .addCharacteristicTapped(let sid):
                let new = DraftCharacteristic(
                    id: CBUUID(nsuuid: UUID()),
                    properties: [.read],
                    permissions: [.readable],
                    initialValueText: ""
                )
                state.services[id: sid]?.characteristics.append(new)
                return .none

            case .characteristicUUIDChanged(let sid, let cid, let text):
                if let newID = CBUUIDParsing.parse(text),
                   var char = state.services[id: sid]?.characteristics[id: cid] {
                    state.services[id: sid]?.characteristics.remove(id: cid)
                    char.id = newID
                    state.services[id: sid]?.characteristics.append(char)
                }
                return .none

            case .togglePropertyTapped(let sid, let cid, let prop):
                if var char = state.services[id: sid]?.characteristics[id: cid] {
                    if char.properties.contains(prop) {
                        char.properties.remove(prop)
                    } else {
                        char.properties.insert(prop)
                    }
                    state.services[id: sid]?.characteristics[id: cid] = char
                }
                return .none

            case .togglePermissionTapped(let sid, let cid, let perm):
                if var char = state.services[id: sid]?.characteristics[id: cid] {
                    if char.permissions.contains(perm) {
                        char.permissions.remove(perm)
                    } else {
                        char.permissions.insert(perm)
                    }
                    state.services[id: sid]?.characteristics[id: cid] = char
                }
                return .none

            case .initialValueChanged(let sid, let cid, let text):
                state.services[id: sid]?.characteristics[id: cid]?.initialValueText = text
                return .none

            case .removeCharacteristicTapped(let sid, let cid):
                state.services[id: sid]?.characteristics.remove(id: cid)
                return .none

            case .publishServiceTapped(let sid):
                guard let draft = state.services[id: sid] else { return .none }
                let mutable = MutableService(
                    id: draft.id,
                    isPrimary: draft.isPrimary,
                    characteristics: draft.characteristics.map { c in
                        MutableCharacteristic(
                            id: c.id,
                            properties: c.properties,
                            permissions: c.permissions,
                            value: HexCoding.decode(c.initialValueText) ?? Data()
                        )
                    }
                )
                state.publishError = nil
                return .run { send in
                    do {
                        _ = try await client.add(mutable)
                        await send(.servicePublished(sid))
                    } catch let error as BluetoothError {
                        await send(.publishFailed(error))
                    } catch {
                        await send(.publishFailed(BluetoothError(error)))
                    }
                }

            case .servicePublished(let sid):
                state.publishedServiceIDs.insert(sid)
                return .none

            case .publishFailed(let err):
                state.publishError = errorDescription(err)
                return .none

            case .removeAllPublishedTapped:
                return .run { send in
                    await client.removeAll()
                    await send(.removeAllPublishedCompleted)
                }

            case .removeAllPublishedCompleted:
                state.publishedServiceIDs = []
                return .none
            }
        }
    }

    private func errorDescription(_ err: BluetoothError) -> String {
        switch err {
        case .poweredOff: return "poweredOff"
        case .poweredOn: return "poweredOn"
        case .unsupported: return "unsupported"
        case .unauthorized: return "unauthorized"
        case .operationCancelled: return "operationCancelled"
        default: return "\(err)"
        }
    }
}
```

Note: `BluetoothError` does not have a `.poweredOn` case. The `errorDescription` fallback covers it via `default`. Adjust the helper to omit `.poweredOn`:

```swift
private func errorDescription(_ err: BluetoothError) -> String {
    switch err {
    case .poweredOff: return "poweredOff"
    case .unsupported: return "unsupported"
    case .operationCancelled: return "operationCancelled"
    default: return "\(err)"
    }
}
```

- [ ] **Step 4: Run tests — confirm pass**

Run: `swift test --package-path Example/FCBDemoFeatures --filter GATTBuilderFeatureTests`
Expected: 5/5 pass.

- [ ] **Step 5: Mutation test**

In `addServiceTapped`, comment out `state.services.append(...)`. In `togglePropertyTapped`, change `char.properties.remove(prop)` and `char.properties.insert(prop)` to no-ops. In `servicePublished`, change `state.publishedServiceIDs.insert(sid)` to no-op.

Run: `swift test --package-path Example/FCBDemoFeatures --filter GATTBuilderFeatureTests`
Expected: `addServiceWithValidUUIDAppends`, `togglePropertyAddsOrRemovesBit`, `publishSuccessMarksPublishedID` all fail.

- [ ] **Step 6: Revert, confirm green**

Rewrite from Step 3. Run tests. Expect 5/5 pass.

- [ ] **Step 7: Commit**

Run: `git add Example/FCBDemoFeatures/Sources/FCBDemoFeatures/Peripheral/GATTBuilderFeature.swift Example/FCBDemoFeatures/Tests/FCBDemoFeaturesTests/GATTBuilderFeatureTests.swift`
Run: `git commit -m "Add GATTBuilderFeature reducer"`

---

### Task 8: `AdvertisingFeature` reducer + tests

**Files:**
- Create: `Example/FCBDemoFeatures/Sources/FCBDemoFeatures/Peripheral/AdvertisingFeature.swift`
- Create: `Example/FCBDemoFeatures/Tests/FCBDemoFeaturesTests/AdvertisingFeatureTests.swift`

- [ ] **Step 1: Write the failing tests**

```swift
import ComposableArchitecture
@preconcurrency import CoreBluetooth
import FCBComposable
import Foundation
import Testing
@testable import FCBDemoFeatures

@MainActor
struct AdvertisingFeatureTests {
    @Test func startAdvertisingSuccessSetsFlag() async {
        let store = TestStore(
            initialState: AdvertisingFeature.State(localName: "Hi")
        ) {
            AdvertisingFeature()
        } withDependencies: {
            $0.bluetoothPeripheralClient.startAdvertising = { _ in }
        }
        store.exhaustivity = .off
        await store.send(.startAdvertisingTapped)
        await store.receive(\.advertisingStarted) { $0.isAdvertising = true }
    }

    @Test func startAdvertisingFailureSetsError() async {
        let store = TestStore(initialState: AdvertisingFeature.State()) {
            AdvertisingFeature()
        } withDependencies: {
            $0.bluetoothPeripheralClient.startAdvertising = { _ in throw BluetoothError.poweredOff }
        }
        store.exhaustivity = .off
        await store.send(.startAdvertisingTapped)
        await store.receive(\.advertisingFailed) { $0.lastError = "poweredOff" }
    }

    @Test func stopAdvertisingClearsFlag() async {
        let store = TestStore(
            initialState: AdvertisingFeature.State(isAdvertising: true)
        ) {
            AdvertisingFeature()
        } withDependencies: {
            $0.bluetoothPeripheralClient.stopAdvertising = { }
        }
        store.exhaustivity = .off
        await store.send(.stopAdvertisingTapped)
        await store.receive(\.stopAdvertisingCompleted) { $0.isAdvertising = false }
    }

    @Test func localNameChangedUpdatesState() async {
        let store = TestStore(initialState: AdvertisingFeature.State()) {
            AdvertisingFeature()
        }
        await store.send(.localNameChanged("MyDevice")) { $0.localName = "MyDevice" }
    }
}
```

- [ ] **Step 2: Run tests — expect compile failure**

Run: `swift test --package-path Example/FCBDemoFeatures --filter AdvertisingFeatureTests`
Expected: cannot find `AdvertisingFeature`. Red phase.

- [ ] **Step 3: Write `AdvertisingFeature.swift`**

```swift
import ComposableArchitecture
@preconcurrency import CoreBluetooth
import FCBComposable
import Foundation

@Reducer
public struct AdvertisingFeature {
    @ObservableState
    public struct State: Equatable {
        public var isAdvertising: Bool
        public var localName: String
        public var includedServiceUUIDsText: String
        public var lastError: String?

        public init(
            isAdvertising: Bool = false,
            localName: String = "",
            includedServiceUUIDsText: String = "",
            lastError: String? = nil
        ) {
            self.isAdvertising = isAdvertising
            self.localName = localName
            self.includedServiceUUIDsText = includedServiceUUIDsText
            self.lastError = lastError
        }
    }

    public enum Action {
        case localNameChanged(String)
        case includedUUIDsChanged(String)
        case startAdvertisingTapped
        case stopAdvertisingTapped
        case advertisingStarted
        case advertisingFailed(BluetoothError)
        case stopAdvertisingCompleted
    }

    @Dependency(\.bluetoothPeripheralClient) var client

    public init() {}

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .localNameChanged(let s):
                state.localName = s
                return .none

            case .includedUUIDsChanged(let s):
                state.includedServiceUUIDsText = s
                return .none

            case .startAdvertisingTapped:
                let ad = AdvertisementData(
                    localName: state.localName.isEmpty ? nil : state.localName,
                    serviceUUIDs: CBUUIDParsing.parseList(state.includedServiceUUIDsText)
                )
                state.lastError = nil
                return .run { send in
                    do {
                        try await client.startAdvertising(ad)
                        await send(.advertisingStarted)
                    } catch let error as BluetoothError {
                        await send(.advertisingFailed(error))
                    } catch {
                        await send(.advertisingFailed(BluetoothError(error)))
                    }
                }

            case .stopAdvertisingTapped:
                return .run { send in
                    await client.stopAdvertising()
                    await send(.stopAdvertisingCompleted)
                }

            case .advertisingStarted:
                state.isAdvertising = true
                return .none

            case .advertisingFailed(let err):
                state.lastError = description(of: err)
                return .none

            case .stopAdvertisingCompleted:
                state.isAdvertising = false
                return .none
            }
        }
    }

    private func description(of err: BluetoothError) -> String {
        switch err {
        case .poweredOff: return "poweredOff"
        case .unsupported: return "unsupported"
        case .operationCancelled: return "operationCancelled"
        default: return "\(err)"
        }
    }
}
```

- [ ] **Step 4: Run tests — confirm pass**

Run: `swift test --package-path Example/FCBDemoFeatures --filter AdvertisingFeatureTests`
Expected: 4/4 pass.

- [ ] **Step 5: Mutation test**

In `advertisingStarted`, change `state.isAdvertising = true` to no-op. In `advertisingFailed`, change `state.lastError = description(of: err)` to no-op. In `stopAdvertisingCompleted`, change `state.isAdvertising = false` to no-op.

Run: `swift test --package-path Example/FCBDemoFeatures --filter AdvertisingFeatureTests`
Expected: `startAdvertisingSuccessSetsFlag`, `startAdvertisingFailureSetsError`, `stopAdvertisingClearsFlag` all fail. `localNameChangedUpdatesState` passes.

- [ ] **Step 6: Revert, confirm green**

Rewrite from Step 3. Run tests. Expect 4/4 pass.

- [ ] **Step 7: Commit**

Run: `git add Example/FCBDemoFeatures/Sources/FCBDemoFeatures/Peripheral/AdvertisingFeature.swift Example/FCBDemoFeatures/Tests/FCBDemoFeaturesTests/AdvertisingFeatureTests.swift`
Run: `git commit -m "Add AdvertisingFeature reducer"`

---

### Task 9: `RequestLogFeature` reducer + tests

**Files:**
- Create: `Example/FCBDemoFeatures/Sources/FCBDemoFeatures/Peripheral/RequestLogFeature.swift`
- Create: `Example/FCBDemoFeatures/Tests/FCBDemoFeaturesTests/RequestLogFeatureTests.swift`

- [ ] **Step 1: Write the failing tests**

```swift
import ComposableArchitecture
@preconcurrency import CoreBluetooth
import FCBComposable
import Foundation
import Testing
@testable import FCBDemoFeatures

@MainActor
struct RequestLogFeatureTests {
    private static let central = Central(id: UUID(uuidString: "00000000-0000-0000-0000-000000000003")!,
                                          maximumUpdateValueLength: 128)
    private static let serviceID = CBUUID(string: "180F")
    private static let charID = CBUUID(string: "2A19")
    private static func sampleChar() -> Characteristic {
        Characteristic(id: charID, serviceID: serviceID, peripheralID: UUID(),
                       properties: [.read], value: nil, isNotifying: false)
    }
    private static let requestID = UUID(uuidString: "00000000-0000-0000-0000-000000000004")!

    @Test func readRequestArrivalAppends() async {
        let req = ReadRequest(id: requestID, central: central, characteristic: sampleChar(), offset: 0)
        let store = TestStore(initialState: RequestLogFeature.State()) {
            RequestLogFeature()
        }
        await store.send(.readRequestReceived(req)) {
            $0.readRequests = [req]
        }
    }

    @Test func respondReadRemovesFromList() async {
        let req = ReadRequest(id: requestID, central: central, characteristic: sampleChar(), offset: 0)
        let store = TestStore(
            initialState: RequestLogFeature.State(readRequests: [req])
        ) {
            RequestLogFeature()
        } withDependencies: {
            $0.bluetoothPeripheralClient.respond = { _, _ in }
        }
        store.exhaustivity = .off
        await store.send(.respondReadTapped(requestID: requestID, code: .success))
        await store.receive(\.respondedRead) {
            $0.readRequests = []
        }
    }

    @Test func writeBatchAppendsAll() async {
        let req1 = WriteRequest(id: UUID(uuidString: "00000000-0000-0000-0000-000000000005")!,
                                 central: central, characteristic: sampleChar(), offset: 0, value: Data([0x01]))
        let req2 = WriteRequest(id: UUID(uuidString: "00000000-0000-0000-0000-000000000006")!,
                                 central: central, characteristic: sampleChar(), offset: 0, value: Data([0x02]))
        let store = TestStore(initialState: RequestLogFeature.State()) {
            RequestLogFeature()
        }
        await store.send(.writeRequestsReceived([req1, req2])) {
            $0.writeRequests = [LoggedWriteRequest(id: req1.id, request: req1),
                                LoggedWriteRequest(id: req2.id, request: req2)]
        }
    }

    @Test func defaultCodeChange() async {
        let store = TestStore(initialState: RequestLogFeature.State()) {
            RequestLogFeature()
        }
        await store.send(.defaultCodeChanged(.readNotPermitted)) {
            $0.defaultResultCode = .readNotPermitted
        }
    }

    @Test func clearLogResetsAllSections() async {
        let req = ReadRequest(id: requestID, central: central, characteristic: sampleChar(), offset: 0)
        let store = TestStore(
            initialState: RequestLogFeature.State(readRequests: [req])
        ) {
            RequestLogFeature()
        }
        await store.send(.clearLogTapped) {
            $0.readRequests = []
            $0.writeRequests = []
            $0.subscriptions = []
        }
    }
}
```

- [ ] **Step 2: Run tests — expect compile failure**

Run: `swift test --package-path Example/FCBDemoFeatures --filter RequestLogFeatureTests`
Expected: cannot find `RequestLogFeature`. Red phase.

- [ ] **Step 3: Write `RequestLogFeature.swift`**

```swift
import ComposableArchitecture
@preconcurrency import CoreBluetooth
import FCBComposable
import Foundation

public struct LoggedWriteRequest: Equatable, Identifiable {
    public var id: UUID
    public var request: WriteRequest

    public init(id: UUID, request: WriteRequest) {
        self.id = id
        self.request = request
    }
}

public struct LoggedSubscription: Equatable, Identifiable {
    public var id: UUID
    public var event: SubscriptionEvent
    public var receivedAt: Date

    public init(id: UUID = UUID(), event: SubscriptionEvent, receivedAt: Date = Date()) {
        self.id = id
        self.event = event
        self.receivedAt = receivedAt
    }
}

@Reducer
public struct RequestLogFeature {
    @ObservableState
    public struct State: Equatable {
        public var readRequests: IdentifiedArrayOf<ReadRequest>
        public var writeRequests: IdentifiedArrayOf<LoggedWriteRequest>
        public var subscriptions: [LoggedSubscription]
        public var defaultResultCode: CBATTError.Code

        public init(
            readRequests: IdentifiedArrayOf<ReadRequest> = [],
            writeRequests: IdentifiedArrayOf<LoggedWriteRequest> = [],
            subscriptions: [LoggedSubscription] = [],
            defaultResultCode: CBATTError.Code = .success
        ) {
            self.readRequests = readRequests
            self.writeRequests = writeRequests
            self.subscriptions = subscriptions
            self.defaultResultCode = defaultResultCode
        }
    }

    public enum Action {
        case onAppear
        case readRequestReceived(ReadRequest)
        case writeRequestsReceived([WriteRequest])
        case subscriptionEvent(SubscriptionEvent)
        case respondReadTapped(requestID: UUID, code: CBATTError.Code)
        case respondWriteTapped(requestID: UUID, code: CBATTError.Code)
        case respondedRead(requestID: UUID)
        case respondedWrite(requestID: UUID)
        case defaultCodeChanged(CBATTError.Code)
        case clearLogTapped
    }

    @Dependency(\.bluetoothPeripheralClient) var client

    enum CancelID: Hashable { case reads, writes, subs }

    public init() {}

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                return .merge(
                    .run { send in
                        for await req in client.readRequests() {
                            await send(.readRequestReceived(req))
                        }
                    }.cancellable(id: CancelID.reads, cancelInFlight: true),
                    .run { send in
                        for await batch in client.writeRequests() {
                            await send(.writeRequestsReceived(batch))
                        }
                    }.cancellable(id: CancelID.writes, cancelInFlight: true),
                    .run { send in
                        for await ev in client.subscriptions() {
                            await send(.subscriptionEvent(ev))
                        }
                    }.cancellable(id: CancelID.subs, cancelInFlight: true)
                )

            case .readRequestReceived(let req):
                state.readRequests[id: req.id] = req
                return .none

            case .writeRequestsReceived(let batch):
                for req in batch {
                    state.writeRequests[id: req.id] = LoggedWriteRequest(id: req.id, request: req)
                }
                return .none

            case .subscriptionEvent(let ev):
                state.subscriptions.insert(LoggedSubscription(event: ev), at: 0)
                if state.subscriptions.count > 10 {
                    state.subscriptions.removeLast(state.subscriptions.count - 10)
                }
                return .none

            case .respondReadTapped(let id, let code):
                return .run { send in
                    await client.respond(id, code)
                    await send(.respondedRead(requestID: id))
                }

            case .respondWriteTapped(let id, let code):
                return .run { send in
                    await client.respond(id, code)
                    await send(.respondedWrite(requestID: id))
                }

            case .respondedRead(let id):
                state.readRequests.remove(id: id)
                return .none

            case .respondedWrite(let id):
                state.writeRequests.remove(id: id)
                return .none

            case .defaultCodeChanged(let code):
                state.defaultResultCode = code
                return .none

            case .clearLogTapped:
                state.readRequests.removeAll()
                state.writeRequests.removeAll()
                state.subscriptions.removeAll()
                return .none
            }
        }
    }
}
```

- [ ] **Step 4: Run tests — confirm pass**

Run: `swift test --package-path Example/FCBDemoFeatures --filter RequestLogFeatureTests`
Expected: 5/5 pass.

- [ ] **Step 5: Mutation test**

In `readRequestReceived`, change `state.readRequests[id: req.id] = req` to no-op. In `respondedRead`, comment out `state.readRequests.remove(id: id)`. In `clearLogTapped`, comment out the three `removeAll()` lines.

Run: `swift test --package-path Example/FCBDemoFeatures --filter RequestLogFeatureTests`
Expected: `readRequestArrivalAppends`, `respondReadRemovesFromList`, `clearLogResetsAllSections` all fail.

- [ ] **Step 6: Revert, confirm green**

Rewrite from Step 3. Run tests. Expect 5/5 pass.

- [ ] **Step 7: Commit**

Run: `git add Example/FCBDemoFeatures/Sources/FCBDemoFeatures/Peripheral/RequestLogFeature.swift Example/FCBDemoFeatures/Tests/FCBDemoFeaturesTests/RequestLogFeatureTests.swift`
Run: `git commit -m "Add RequestLogFeature reducer"`

---

### Task 10: `PeripheralFeature` composer + Peripheral views

**Files:**
- Create: `Example/FCBDemoFeatures/Sources/FCBDemoFeatures/Peripheral/PeripheralFeature.swift`
- Create: `Example/FCBDemoFeatures/Sources/FCBDemoFeatures/Peripheral/PeripheralView.swift`
- Create: `Example/FCBDemoFeatures/Sources/FCBDemoFeatures/Peripheral/GATTBuilderView.swift`
- Create: `Example/FCBDemoFeatures/Sources/FCBDemoFeatures/Peripheral/AdvertisingView.swift`
- Create: `Example/FCBDemoFeatures/Sources/FCBDemoFeatures/Peripheral/RequestLogView.swift`

No new tests in this task — the composer is trivial; views are compile-only.

- [ ] **Step 1: Write `PeripheralFeature.swift`**

```swift
import ComposableArchitecture
@preconcurrency import CoreBluetooth
import FCBComposable
import Foundation

@Reducer
public struct PeripheralFeature {
    @ObservableState
    public struct State: Equatable {
        public var gattBuilder: GATTBuilderFeature.State
        public var advertising: AdvertisingFeature.State
        public var requestLog: RequestLogFeature.State
        public var managerState: CBManagerState

        public init(
            gattBuilder: GATTBuilderFeature.State = .init(),
            advertising: AdvertisingFeature.State = .init(),
            requestLog: RequestLogFeature.State = .init(),
            managerState: CBManagerState = .unknown
        ) {
            self.gattBuilder = gattBuilder
            self.advertising = advertising
            self.requestLog = requestLog
            self.managerState = managerState
        }
    }

    public enum Action {
        case onAppear
        case stateStreamUpdate(CBManagerState)
        case gattBuilder(GATTBuilderFeature.Action)
        case advertising(AdvertisingFeature.Action)
        case requestLog(RequestLogFeature.Action)
    }

    @Dependency(\.bluetoothPeripheralClient) var client

    enum CancelID: Hashable { case stateStream }

    public init() {}

    public var body: some ReducerOf<Self> {
        Scope(state: \.gattBuilder, action: \.gattBuilder) { GATTBuilderFeature() }
        Scope(state: \.advertising, action: \.advertising) { AdvertisingFeature() }
        Scope(state: \.requestLog, action: \.requestLog) { RequestLogFeature() }
        Reduce { state, action in
            switch action {
            case .onAppear:
                return .run { send in
                    for await s in client.state() {
                        await send(.stateStreamUpdate(s))
                    }
                }
                .cancellable(id: CancelID.stateStream, cancelInFlight: true)
            case .stateStreamUpdate(let s):
                state.managerState = s
                return .none
            default:
                return .none
            }
        }
    }
}
```

- [ ] **Step 2: Write `GATTBuilderView.swift`**

```swift
import ComposableArchitecture
@preconcurrency import CoreBluetooth
import FCBComposable
import SwiftUI

public struct GATTBuilderView: View {
    @Bindable public var store: StoreOf<GATTBuilderFeature>

    public init(store: StoreOf<GATTBuilderFeature>) {
        self.store = store
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("GATT Services").font(.headline)
            HStack {
                TextField("Service UUID (e.g. 180F)", text: $store.newServiceUUIDInput)
                    .textInputAutocapitalization(.never)
                    .textFieldStyle(.roundedBorder)
                Button("Add Service") { store.send(.addServiceTapped) }
            }
            if let err = store.publishError {
                Text(err).foregroundStyle(.red).font(.caption)
            }
            ForEach(store.services) { draft in
                serviceCard(draft)
            }
            Button("Remove All Published", role: .destructive) {
                store.send(.removeAllPublishedTapped)
            }
            .disabled(store.publishedServiceIDs.isEmpty)
        }
        .padding()
    }

    @ViewBuilder
    private func serviceCard(_ draft: DraftService) -> some View {
        let isPublished = store.publishedServiceIDs.contains(draft.id)
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(draft.id.uuidString).font(.caption.monospaced())
                Spacer()
                Button(role: .destructive) {
                    store.send(.removeServiceTapped(serviceID: draft.id))
                } label: { Image(systemName: "trash") }
            }
            Toggle("Primary",
                   isOn: Binding(
                        get: { draft.isPrimary },
                        set: { store.send(.isPrimaryToggled(serviceID: draft.id, $0)) }))
                .disabled(isPublished)
            ForEach(draft.characteristics) { char in
                charView(serviceID: draft.id, char: char, disabled: isPublished)
            }
            Button("Add Characteristic") {
                store.send(.addCharacteristicTapped(serviceID: draft.id))
            }
            .disabled(isPublished)
            Button(isPublished ? "Published ✓" : "Publish") {
                store.send(.publishServiceTapped(serviceID: draft.id))
            }
            .disabled(isPublished)
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    @ViewBuilder
    private func charView(serviceID: CBUUID, char: DraftCharacteristic, disabled: Bool) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(char.id.uuidString).font(.caption2.monospaced())
            HStack {
                propCheckbox(label: "R", value: .read, char: char, serviceID: serviceID)
                propCheckbox(label: "W", value: .write, char: char, serviceID: serviceID)
                propCheckbox(label: "Wn", value: .writeWithoutResponse, char: char, serviceID: serviceID)
                propCheckbox(label: "N", value: .notify, char: char, serviceID: serviceID)
                propCheckbox(label: "I", value: .indicate, char: char, serviceID: serviceID)
            }
            HStack {
                permCheckbox(label: "Readable", value: .readable, char: char, serviceID: serviceID)
                permCheckbox(label: "Writeable", value: .writeable, char: char, serviceID: serviceID)
            }
            TextField("Initial value (hex)",
                      text: Binding(
                        get: { char.initialValueText },
                        set: { store.send(.initialValueChanged(serviceID: serviceID, characteristicID: char.id, $0)) }))
                .textFieldStyle(.roundedBorder)
                .textInputAutocapitalization(.never)
            Button(role: .destructive) {
                store.send(.removeCharacteristicTapped(serviceID: serviceID, characteristicID: char.id))
            } label: { Image(systemName: "minus.circle") }
        }
        .padding(.vertical, 4)
        .disabled(disabled)
    }

    private func propCheckbox(label: String, value: CBCharacteristicProperties, char: DraftCharacteristic, serviceID: CBUUID) -> some View {
        Toggle(label, isOn: Binding(
            get: { char.properties.contains(value) },
            set: { _ in store.send(.togglePropertyTapped(serviceID: serviceID, characteristicID: char.id, value)) }))
            .toggleStyle(.button)
    }

    private func permCheckbox(label: String, value: CBAttributePermissions, char: DraftCharacteristic, serviceID: CBUUID) -> some View {
        Toggle(label, isOn: Binding(
            get: { char.permissions.contains(value) },
            set: { _ in store.send(.togglePermissionTapped(serviceID: serviceID, characteristicID: char.id, value)) }))
            .toggleStyle(.button)
    }
}

#Preview {
    GATTBuilderView(
        store: Store(initialState: GATTBuilderFeature.State()) {
            GATTBuilderFeature()
        } withDependencies: {
            $0.previewBluetooth()
        }
    )
}
```


- [ ] **Step 3: Write `AdvertisingView.swift`**

```swift
import ComposableArchitecture
import FCBComposable
import SwiftUI

public struct AdvertisingView: View {
    @Bindable public var store: StoreOf<AdvertisingFeature>

    public init(store: StoreOf<AdvertisingFeature>) {
        self.store = store
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Advertising").font(.headline)
            TextField("Local Name", text: $store.localName)
                .textFieldStyle(.roundedBorder)
            TextField("Included Service UUIDs (comma-separated)", text: $store.includedServiceUUIDsText)
                .textInputAutocapitalization(.never)
                .textFieldStyle(.roundedBorder)
            HStack {
                Button(store.isAdvertising ? "Stop" : "Start") {
                    store.send(store.isAdvertising ? .stopAdvertisingTapped : .startAdvertisingTapped)
                }
                Text(store.isAdvertising ? "Advertising" : "Stopped")
                    .foregroundStyle(.secondary)
            }
            if let err = store.lastError {
                Text(err).foregroundStyle(.red).font(.caption)
            }
        }
        .padding()
    }
}

#Preview {
    AdvertisingView(
        store: Store(initialState: AdvertisingFeature.State()) {
            AdvertisingFeature()
        } withDependencies: {
            $0.previewBluetooth()
        }
    )
}
```

- [ ] **Step 4: Write `RequestLogView.swift`**

```swift
import ComposableArchitecture
@preconcurrency import CoreBluetooth
import FCBComposable
import SwiftUI

public struct RequestLogView: View {
    @Bindable public var store: StoreOf<RequestLogFeature>

    public init(store: StoreOf<RequestLogFeature>) {
        self.store = store
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Request Log").font(.headline)
            Picker("Default Response", selection: Binding(
                get: { store.defaultResultCode },
                set: { store.send(.defaultCodeChanged($0)) })) {
                Text("Success").tag(CBATTError.Code.success)
                Text("Read Not Permitted").tag(CBATTError.Code.readNotPermitted)
                Text("Write Not Permitted").tag(CBATTError.Code.writeNotPermitted)
                Text("Invalid Handle").tag(CBATTError.Code.invalidHandle)
                Text("Request Not Supported").tag(CBATTError.Code.requestNotSupported)
                Text("Attribute Not Found").tag(CBATTError.Code.attributeNotFound)
            }
            Text("Read Requests (\(store.readRequests.count))").font(.subheadline)
            ForEach(store.readRequests) { req in
                HStack {
                    VStack(alignment: .leading) {
                        Text(req.characteristic.id.uuidString).font(.caption.monospaced())
                        Text("offset \(req.offset)").font(.caption2)
                    }
                    Spacer()
                    Button("Respond") {
                        store.send(.respondReadTapped(requestID: req.id, code: store.defaultResultCode))
                    }
                }
            }
            Text("Write Requests (\(store.writeRequests.count))").font(.subheadline)
            ForEach(store.writeRequests) { logged in
                HStack {
                    VStack(alignment: .leading) {
                        Text(logged.request.characteristic.id.uuidString).font(.caption.monospaced())
                        Text("hex \(HexCoding.encode(logged.request.value ?? Data()))").font(.caption2)
                    }
                    Spacer()
                    Button("Respond") {
                        store.send(.respondWriteTapped(requestID: logged.id, code: store.defaultResultCode))
                    }
                }
            }
            Text("Subscriptions (last 10)").font(.subheadline)
            ForEach(store.subscriptions) { sub in
                Text(label(for: sub)).font(.caption)
            }
            Button("Clear Log", role: .destructive) {
                store.send(.clearLogTapped)
            }
        }
        .padding()
        .onAppear { store.send(.onAppear) }
    }

    private func label(for s: LoggedSubscription) -> String {
        switch s.event {
        case .subscribed(let c, let ch):
            return "subscribed \(c.id.uuidString.prefix(8)) → \(ch.id.uuidString)"
        case .unsubscribed(let c, let ch):
            return "unsubscribed \(c.id.uuidString.prefix(8)) → \(ch.id.uuidString)"
        }
    }
}

#Preview {
    RequestLogView(
        store: Store(initialState: RequestLogFeature.State()) {
            RequestLogFeature()
        } withDependencies: {
            $0.previewBluetooth()
        }
    )
}
```

- [ ] **Step 5: Write `PeripheralView.swift`**

```swift
import ComposableArchitecture
@preconcurrency import CoreBluetooth
import FCBComposable
import SwiftUI

public struct PeripheralView: View {
    @Bindable public var store: StoreOf<PeripheralFeature>

    public init(store: StoreOf<PeripheralFeature>) {
        self.store = store
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading) {
                Text("BLE: \(label(for: store.managerState))")
                    .font(.caption)
                    .padding(.horizontal)
                Divider()
                GATTBuilderView(store: store.scope(state: \.gattBuilder, action: \.gattBuilder))
                Divider()
                AdvertisingView(store: store.scope(state: \.advertising, action: \.advertising))
                Divider()
                RequestLogView(store: store.scope(state: \.requestLog, action: \.requestLog))
            }
        }
        .onAppear { store.send(.onAppear) }
        .disabled(store.managerState != .poweredOn)
    }

    private func label(for s: CBManagerState) -> String {
        switch s {
        case .poweredOn: return "Powered On"
        case .poweredOff: return "Powered Off"
        case .resetting: return "Resetting"
        case .unauthorized: return "Unauthorized"
        case .unsupported: return "Unsupported"
        case .unknown: return "Unknown"
        @unknown default: return "Unknown"
        }
    }
}

#Preview {
    PeripheralView(
        store: Store(initialState: PeripheralFeature.State()) {
            PeripheralFeature()
        } withDependencies: {
            $0.previewBluetooth()
        }
    )
}
```

- [ ] **Step 6: Build — confirm compiles**

Run: `swift build --package-path Example/FCBDemoFeatures`
Expected: succeeds.

- [ ] **Step 7: Commit**

Run: `git add Example/FCBDemoFeatures/Sources/FCBDemoFeatures/Peripheral`
Run: `git commit -m "Add PeripheralFeature composer and Peripheral tab views"`

---

## Phase D — App composition

### Task 11: `AppFeature` + `AppView` + tests

**Files:**
- Create: `Example/FCBDemoFeatures/Sources/FCBDemoFeatures/App/AppFeature.swift`
- Create: `Example/FCBDemoFeatures/Sources/FCBDemoFeatures/App/AppView.swift`
- Create: `Example/FCBDemoFeatures/Tests/FCBDemoFeaturesTests/AppFeatureTests.swift`

- [ ] **Step 1: Write failing tests**

```swift
import ComposableArchitecture
import FCBComposable
import Foundation
import Testing
@testable import FCBDemoFeatures

@MainActor
struct AppFeatureTests {
    @Test func tabSwitch() async {
        let store = TestStore(initialState: AppFeature.State()) {
            AppFeature()
        }
        await store.send(.tabChanged(.peripheral)) { $0.tab = .peripheral }
        await store.send(.tabChanged(.central)) { $0.tab = .central }
    }
}
```

- [ ] **Step 2: Run tests — expect compile failure**

Run: `swift test --package-path Example/FCBDemoFeatures --filter AppFeatureTests`
Expected: cannot find `AppFeature`. Red phase.

- [ ] **Step 3: Write `AppFeature.swift`**

```swift
import ComposableArchitecture
import FCBComposable
import Foundation

@Reducer
public struct AppFeature {
    public enum Tab: Equatable { case central, peripheral }

    @ObservableState
    public struct State: Equatable {
        public var tab: Tab
        public var central: CentralFeature.State
        public var peripheral: PeripheralFeature.State

        public init(
            tab: Tab = .central,
            central: CentralFeature.State = .init(),
            peripheral: PeripheralFeature.State = .init()
        ) {
            self.tab = tab
            self.central = central
            self.peripheral = peripheral
        }
    }

    public enum Action {
        case tabChanged(Tab)
        case central(CentralFeature.Action)
        case peripheral(PeripheralFeature.Action)
    }

    public init() {}

    public var body: some ReducerOf<Self> {
        Scope(state: \.central, action: \.central) { CentralFeature() }
        Scope(state: \.peripheral, action: \.peripheral) { PeripheralFeature() }
        Reduce { state, action in
            switch action {
            case .tabChanged(let tab):
                state.tab = tab
                return .none
            default:
                return .none
            }
        }
    }
}
```

- [ ] **Step 4: Write `AppView.swift`**

```swift
import ComposableArchitecture
import SwiftUI

public struct AppView: View {
    @Bindable public var store: StoreOf<AppFeature>

    public init(store: StoreOf<AppFeature>) {
        self.store = store
    }

    public var body: some View {
        TabView(selection: Binding(
            get: { store.tab },
            set: { store.send(.tabChanged($0)) })) {
            CentralView(store: store.scope(state: \.central, action: \.central))
                .tabItem { Label("Central", systemImage: "antenna.radiowaves.left.and.right") }
                .tag(AppFeature.Tab.central)
            PeripheralView(store: store.scope(state: \.peripheral, action: \.peripheral))
                .tabItem { Label("Peripheral", systemImage: "dot.radiowaves.forward") }
                .tag(AppFeature.Tab.peripheral)
        }
    }
}

#Preview {
    AppView(
        store: Store(initialState: AppFeature.State()) {
            AppFeature()
        } withDependencies: {
            $0.previewBluetooth()
        }
    )
}
```

- [ ] **Step 5: Run tests — confirm pass**

Run: `swift test --package-path Example/FCBDemoFeatures`
Expected: All tests pass (1 new in AppFeatureTests + all from earlier tasks).

- [ ] **Step 6: Mutation test**

In `tabChanged` case body, change `state.tab = tab` to no-op.

Run: `swift test --package-path Example/FCBDemoFeatures --filter AppFeatureTests`
Expected: `tabSwitch` fails.

- [ ] **Step 7: Revert, confirm green**

Rewrite from Step 3. Run tests. Expect all pass.

- [ ] **Step 8: Commit**

Run: `git add Example/FCBDemoFeatures/Sources/FCBDemoFeatures/App Example/FCBDemoFeatures/Tests/FCBDemoFeaturesTests/AppFeatureTests.swift`
Run: `git commit -m "Add AppFeature reducer and AppView"`

---

## Phase E — iOS app shell

### Task 12: `Example/FCBDemo.swiftpm` Swift Playgrounds App Project

**Files:**
- Create: `Example/FCBDemo.swiftpm/Package.swift`
- Create: `Example/FCBDemo.swiftpm/FCBDemoAppEntry.swift`

This task creates the iOS app shell. The `.swiftpm` directory extension marks it as a Swift Playgrounds App Project, which Xcode 14+ can build as a fully-fledged iOS app.

- [ ] **Step 1: Create directory**

Run: `mkdir -p Example/FCBDemo.swiftpm`

- [ ] **Step 2: Write `Example/FCBDemo.swiftpm/Package.swift`**

```swift
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
```

- [ ] **Step 3: Write `Example/FCBDemo.swiftpm/FCBDemoAppEntry.swift`**

```swift
import ComposableArchitecture
import FCBDemoFeatures
import SwiftUI

@main
struct FCBDemoEntry: App {
    let store = Store(initialState: AppFeature.State()) {
        AppFeature()
    }

    var body: some Scene {
        WindowGroup {
            AppView(store: store)
        }
    }
}
```

- [ ] **Step 4: Verify build via SwiftPM**

Note: `swift build` directly on a `.swiftpm` directory may not work depending on tooling. Xcode 14+ is the supported builder. For CLI verification we just confirm `Package.swift` parses:

Run: `swift package --package-path Example/FCBDemo.swiftpm describe`
Expected: prints the package description without errors. (If `AppleProductTypes` is unavailable in the SwiftPM CLI, this will fail with "no such module 'AppleProductTypes'", which is expected — the type is only available in Xcode's build context. Verify the file compiles via Xcode in Task 13.)

If the CLI describe fails with module-not-found, this is acceptable — the .swiftpm project format is Xcode-only.

- [ ] **Step 5: Commit**

Run: `git add Example/FCBDemo.swiftpm`
Run: `git commit -m "Add FCBDemo.swiftpm iOS app shell"`

---

## Phase F — Wrap-up

### Task 13: Final smoke build + full test run + add a README

**Files:**
- Create: `Example/README.md`

- [ ] **Step 1: Write `Example/README.md`**

```markdown
# FCBDemo

A SwiftUI + TCA iOS demo app that exercises the FCBComposable client API.

## Layout

- `FCBDemoFeatures/` — SwiftPM library containing all Reducers, value types, SwiftUI views, and TestStore tests. Buildable and testable from the command line:
  ```
  swift build --package-path Example/FCBDemoFeatures
  swift test  --package-path Example/FCBDemoFeatures
  ```
- `FCBDemo.swiftpm/` — Swift Playgrounds App Project that pulls in `FCBDemoFeatures` and provides the `@main App`, Info.plist permission strings, and Bluetooth capability declaration. Open in Xcode 14+ to build and run on a device or simulator.

## Running

Open `Example/FCBDemo.swiftpm` in Xcode (`open Example/FCBDemo.swiftpm`). Build and run on a real iOS device. BLE does not work on the simulator.

## Permissions

`NSBluetoothAlwaysUsageDescription` is declared via the `.bluetoothAlways` capability in `FCBDemo.swiftpm/Package.swift`. The simulator's Bluetooth state will be `.unsupported`; deploy to a device.

## Notes

- iBeacon advertising is intentionally out of scope (the FCBComposable package does not handle iBeacon).
- No background BLE.
- No persistence; state resets on each launch.
```

- [ ] **Step 2: Run the full FCBDemoFeatures test suite**

Run: `swift test --package-path Example/FCBDemoFeatures`
Expected: all tests pass.

- [ ] **Step 3: Build the FCBDemoFeatures library**

Run: `swift build --package-path Example/FCBDemoFeatures`
Expected: succeeds.

- [ ] **Step 4: Confirm the FCB package still builds**

Run: `swift build`
Expected: succeeds (the parent package is unchanged).

- [ ] **Step 5: Confirm the FCB package's tests still pass**

Run: `swift test`
Expected: all 80 tests from the FCB package still pass with no regressions.

- [ ] **Step 6: Commit**

Run: `git add Example/README.md`
Run: `git commit -m "Add FCBDemo README"`

---

## Done

All tasks complete when:
- `swift build --package-path Example/FCBDemoFeatures` succeeds.
- `swift test --package-path Example/FCBDemoFeatures` reports all tests passing.
- `swift build` (root) succeeds.
- `swift test` (root) shows 80/80 still passing.
- `Example/FCBDemo.swiftpm/` opens in Xcode and contains the expected structure (verified by inspection, not automation).
