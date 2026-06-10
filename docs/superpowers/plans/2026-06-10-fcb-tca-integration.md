# FCB Modernization & TCA Integration — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Extract the CoreBluetooth closure-shim classes from `../fuikit/fuikit/Classes/FCB/`, modernize them for Swift 6 strict concurrency and iOS 17+, and add a TCA-integrated layer with Sendable value types and `AsyncStream`-based event observation.

**Architecture:** Two-tier Swift package. `FCB` target (no external dependencies) holds three closure-based `CB*Delegate` wrappers. `FCBComposable` target depends on `FCB` + `swift-composable-architecture` and ships role-based `@DependencyClient`s (`BluetoothCentralClient`, `BluetoothPeripheralClient`) backed by internal actors. Sendable value types wrap all non-Sendable CoreBluetooth types; a `BluetoothError` enum classifies all CoreBluetooth errors.

**Tech Stack:** Swift 6, SwiftPM (swift-tools-version 6.3), iOS 17+, CoreBluetooth, Swift Testing (`import Testing`, `@Test`, `#expect`), swift-composable-architecture 1.x (`@DependencyClient` macro, `DependencyKey`).

---

## Spec reference

This plan implements `docs/superpowers/specs/2026-06-10-fcb-tca-integration-design.md`. Sections in the spec map to phases below:

- **Layer 1** (spec §"Layer 1 — `FCB`") → Phase B, tasks 3–5.
- **Layer 2 value types & errors** (spec §"Sendable value types", §"`BluetoothError`") → Phase C, tasks 6–10.
- **Layer 2 event enums** (spec §"Event enums") → Phase D, task 11.
- **Layer 2 internal protocols** (spec §"`DependencyKey` conformance" + §"CoreBluetooth instantiation in tests") → Phase E, task 12.
- **Layer 2 clients** (spec §"`BluetoothCentralClient`", §"`BluetoothPeripheralClient`") → Phase F, tasks 13–22.

## Files to create / modify

### `FCB/` (Layer 1) — `Sources/FCB/`

| File | Responsibility |
|---|---|
| `FCBCentralManagerDelegate.swift` | `open class` wrapping `CBCentralManagerDelegate` with `@Sendable` closures. |
| `FCBPeripheralDelegate.swift` | `open class` wrapping `CBPeripheralDelegate` (new — fills the gap). |
| `FCBPeripheralManagerDelegate.swift` | `open class` wrapping `CBPeripheralManagerDelegate`. |

### `FCBComposable/` (Layer 2) — `Sources/FCBComposable/`

| File | Responsibility |
|---|---|
| `Models/Peripheral.swift` | `Peripheral` + `ConnectionState`. |
| `Models/DiscoveredPeripheral.swift` | `DiscoveredPeripheral`. |
| `Models/AdvertisementData.swift` | `AdvertisementData` + dictionary decoding. |
| `Models/Service.swift` | `Service` + `CBService → Service` conversion. |
| `Models/Characteristic.swift` | `Characteristic` + `CBCharacteristic → Characteristic` conversion. |
| `Models/Central.swift` | `Central` + `CBCentral → Central` conversion. |
| `Models/Requests.swift` | `ReadRequest`, `WriteRequest`. |
| `Models/MutableService.swift` | `MutableService`, `MutableCharacteristic` + `→ CBMutableService` conversion. |
| `Models/RestorationState.swift` | Sendable wrapper around CB restoration dictionaries. |
| `Models/SubscriptionEvent.swift` | `.subscribed` / `.unsubscribed` event for peripheral role. |
| `Models/ScanOptions.swift` | Sendable wrapper around scan options dictionary. |
| `Models/ConnectOptions.swift` | Sendable wrapper around connect options dictionary. |
| `Errors/BluetoothError.swift` | `BluetoothError` enum + `init(_ error: any Error)`. |
| `Events/CentralEvent.swift` | `CentralEvent` enum. |
| `Events/PeripheralEvent.swift` | `PeripheralEvent` enum. |
| `Events/PeripheralManagerEvent.swift` | `PeripheralManagerEvent` enum. |
| `Internal/CentralManaging.swift` | Internal protocol for actor's CB manager dependency. |
| `Internal/PeripheralManaging.swift` | Internal protocol for actor's CB peripheral-manager dependency. |
| `Internal/PeripheralConnection.swift` | Internal protocol wrapping CBPeripheral. |
| `BluetoothCentralClient.swift` | `@DependencyClient` witness struct. |
| `BluetoothCentralClient+Live.swift` | `liveValue` + private `CentralActor`. |
| `BluetoothCentralClient+Preview.swift` | `previewValue` mock. |
| `BluetoothPeripheralClient.swift` | `@DependencyClient` witness struct. |
| `BluetoothPeripheralClient+Live.swift` | `liveValue` + private `PeripheralRoleActor`. |
| `BluetoothPeripheralClient+Preview.swift` | `previewValue` mock. |

### Tests

| File | Responsibility |
|---|---|
| `Tests/FCBTests/BLETestStub.swift` | `class_createInstance` helpers for `CBPeripheral`/`CBService`/etc. |
| `Tests/FCBTests/FCBCentralManagerDelegateTests.swift` | One test per closure forward. |
| `Tests/FCBTests/FCBPeripheralDelegateTests.swift` | One test per closure forward. |
| `Tests/FCBTests/FCBPeripheralManagerDelegateTests.swift` | One test per closure forward. |
| `Tests/FCBComposableTests/BluetoothErrorTests.swift` | NSError → `BluetoothError` mapping. |
| `Tests/FCBComposableTests/AdvertisementDataTests.swift` | Dictionary decoding. |
| `Tests/FCBComposableTests/ValueTypeTests.swift` | Identity/Equatable round-trips for trivial value types. |
| `Tests/FCBComposableTests/FakeCentralManager.swift` | In-test fake conforming to `CentralManaging`. |
| `Tests/FCBComposableTests/FakePeripheralConnection.swift` | In-test fake conforming to `PeripheralConnection`. |
| `Tests/FCBComposableTests/FakePeripheralManager.swift` | In-test fake conforming to `PeripheralManaging`. |
| `Tests/FCBComposableTests/BluetoothCentralClientTests.swift` | Live actor behavior tests via fakes. |
| `Tests/FCBComposableTests/BluetoothPeripheralClientTests.swift` | Live actor behavior tests via fakes. |

### Repository root

| File | Responsibility |
|---|---|
| `Package.swift` | Two products, two targets, iOS 17 platform, TCA dependency. |
| `CLAUDE.md` | Update to reflect new architecture. |

## Task index

- **Phase A — Package skeleton** — Task 1: `Package.swift`. Task 2: directory scaffolding + delete stubs.
- **Phase B — Layer 1 closure shims** — Task 3: `FCBCentralManagerDelegate`. Task 4: `FCBPeripheralDelegate`. Task 5: `FCBPeripheralManagerDelegate`.
- **Phase C — Layer 2 value types & errors** — Task 6: `BluetoothError`. Task 7: trivial models (`Peripheral`, `ConnectionState`, `Service`, `Characteristic`, `Central`, `DiscoveredPeripheral`). Task 8: `AdvertisementData`. Task 9: `Requests`, `MutableService`, `RestorationState`, `SubscriptionEvent`, `ScanOptions`, `ConnectOptions`. Task 10: CB→value-type converters.
- **Phase D — Event enums** — Task 11: all three event enums.
- **Phase E — Internal protocols** — Task 12: `CentralManaging`, `PeripheralConnection`, `PeripheralManaging` + CB conformances.
- **Phase F — Clients** — Tasks 13–17: `BluetoothCentralClient` (struct, live scan, live connect/disconnect, live discovery, live read/write/notify + state/events, preview). Tasks 18–22: `BluetoothPeripheralClient` (struct, live services, live advertising, live requests/responses + state/events, preview).
- **Phase G — Wrap-up** — Task 23: update `CLAUDE.md`.

## Conventions used throughout the plan

- Every task that adds tests follows the mutation-testing protocol from the user-level `CLAUDE.md`: (a) tests green, (b) batch-mutate the production code, confirm targeted tests fail, (c) revert mutations, confirm green. This is explicit in each task's steps.
- One command per `bash` line — never chained with `|`/`&&`/`;`/etc.
- Each task ends with a commit step.
- Test code and implementation code is shown in full inside each task. Re-use across tasks is intentional — engineers may read tasks out of order.

---

## Phase A — Package skeleton

### Task 1: Configure `Package.swift` for two products, two targets, iOS 17, TCA dependency

**Files:**
- Modify: `Package.swift` (full rewrite)

- [ ] **Step 1: Replace the contents of `Package.swift`**

```swift
// swift-tools-version: 6.3

import PackageDescription

let package = Package(
    name: "FCB",
    platforms: [.iOS(.v17)],
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
```

- [ ] **Step 2: Resolve dependencies**

Run: `swift package resolve`
Expected: downloads `swift-composable-architecture` and its transitive deps. Exits zero.

- [ ] **Step 3: Confirm `swift build` fails because target directories don't exist yet (sanity check)**

Run: `swift build`
Expected: build fails with "Source files for target FCB should be located under 'Sources/FCB'" (or "FCBComposable"). This is expected — Task 2 creates the directories.

- [ ] **Step 4: Commit**

Run: `git add Package.swift Package.resolved`
Run: `git commit -m "Update Package.swift for two-target FCB / FCBComposable layout"`

---

### Task 2: Scaffold source directories, delete stub files

**Files:**
- Delete: `Sources/FCB/FCB.swift`
- Delete: `Tests/FCBTests/FCBTests.swift`
- Create: `Sources/FCBComposable/.gitkeep` (placeholder until Task 6 adds content)
- Create: `Tests/FCBComposableTests/.gitkeep`

- [ ] **Step 1: Remove the stub source file**

Run: `rm Sources/FCB/FCB.swift`

- [ ] **Step 2: Remove the stub test file**

Run: `rm Tests/FCBTests/FCBTests.swift`

- [ ] **Step 3: Create the FCBComposable source directory with a placeholder**

Run: `mkdir -p Sources/FCBComposable/Models`
Run: `mkdir -p Sources/FCBComposable/Errors`
Run: `mkdir -p Sources/FCBComposable/Events`
Run: `mkdir -p Sources/FCBComposable/Internal`
Run: `touch Sources/FCBComposable/.gitkeep`

- [ ] **Step 4: Create the FCBComposableTests directory with a placeholder**

Run: `mkdir -p Tests/FCBComposableTests`
Run: `touch Tests/FCBComposableTests/.gitkeep`

- [ ] **Step 5: Confirm `swift build` still fails — Sources/FCB has no files**

Run: `swift build`
Expected: build fails with "Source files for target FCB should be located under 'Sources/FCB'". This is still expected — Task 3 adds the first file.

- [ ] **Step 6: Commit**

Run: `git add Sources Tests`
Run: `git commit -m "Scaffold source/test directories for both targets"`

---

## Phase B — Layer 1: closure-shim delegates

### Task 3: `FCBCentralManagerDelegate` — tests + implementation

**Files:**
- Create: `Tests/FCBTests/BLETestStub.swift`
- Create: `Tests/FCBTests/FCBCentralManagerDelegateTests.swift`
- Create: `Sources/FCB/FCBCentralManagerDelegate.swift`

- [ ] **Step 1: Write the test stub helper**

Create `Tests/FCBTests/BLETestStub.swift`:

```swift
import CoreBluetooth
import ObjectiveC.runtime

/// Test-only helpers for minting `CB*` instances that cannot be initialized publicly.
/// These objects MUST NOT have their methods invoked — they exist only to satisfy
/// type signatures on delegate forwards.
enum BLETestStub {
    static func peripheral() -> CBPeripheral {
        unsafeBitCast(class_createInstance(CBPeripheral.self, 0)!, to: CBPeripheral.self)
    }
    static func service() -> CBService {
        unsafeBitCast(class_createInstance(CBService.self, 0)!, to: CBService.self)
    }
    static func characteristic() -> CBCharacteristic {
        unsafeBitCast(class_createInstance(CBCharacteristic.self, 0)!, to: CBCharacteristic.self)
    }
    static func central() -> CBCentral {
        unsafeBitCast(class_createInstance(CBCentral.self, 0)!, to: CBCentral.self)
    }
    static func attRequest() -> CBATTRequest {
        unsafeBitCast(class_createInstance(CBATTRequest.self, 0)!, to: CBATTRequest.self)
    }
    static func centralManager() -> CBCentralManager {
        CBCentralManager(delegate: nil, queue: nil)
    }
    static func peripheralManager() -> CBPeripheralManager {
        CBPeripheralManager(delegate: nil, queue: nil)
    }
}
```

- [ ] **Step 2: Write the failing tests**

Create `Tests/FCBTests/FCBCentralManagerDelegateTests.swift`:

```swift
import CoreBluetooth
import Testing
@testable import FCB

struct FCBCentralManagerDelegateTests {
    @Test func forwardsDidUpdateState() {
        let sut = FCBCentralManagerDelegate()
        var fired = false
        sut.onDidUpdateState = { _ in fired = true }
        sut.centralManagerDidUpdateState(BLETestStub.centralManager())
        #expect(fired)
    }

    @Test func forwardsWillRestoreState() {
        let sut = FCBCentralManagerDelegate()
        var capturedKeys: [String]?
        sut.onWillRestoreState = { _, dict in capturedKeys = Array(dict.keys) }
        sut.centralManager(BLETestStub.centralManager(), willRestoreState: ["k": 1])
        #expect(capturedKeys == ["k"])
    }

    @Test func forwardsDidDiscover() {
        let sut = FCBCentralManagerDelegate()
        var capturedRSSI: NSNumber?
        sut.onDidDiscover = { _, _, _, rssi in capturedRSSI = rssi }
        sut.centralManager(BLETestStub.centralManager(),
                           didDiscover: BLETestStub.peripheral(),
                           advertisementData: [:],
                           rssi: NSNumber(value: -42))
        #expect(capturedRSSI?.intValue == -42)
    }

    @Test func forwardsDidConnect() {
        let sut = FCBCentralManagerDelegate()
        var fired = false
        sut.onDidConnect = { _, _ in fired = true }
        sut.centralManager(BLETestStub.centralManager(), didConnect: BLETestStub.peripheral())
        #expect(fired)
    }

    @Test func forwardsDidFailToConnect() {
        let sut = FCBCentralManagerDelegate()
        var capturedError: (any Error)?
        sut.onDidFailToConnect = { _, _, err in capturedError = err }
        let nsError = NSError(domain: "x", code: 1)
        sut.centralManager(BLETestStub.centralManager(),
                           didFailToConnect: BLETestStub.peripheral(),
                           error: nsError)
        #expect((capturedError as? NSError)?.code == 1)
    }

    @Test func forwardsDidDisconnect() {
        let sut = FCBCentralManagerDelegate()
        var fired = false
        sut.onDidDisconnect = { _, _, _ in fired = true }
        sut.centralManager(BLETestStub.centralManager(),
                           didDisconnectPeripheral: BLETestStub.peripheral(),
                           error: nil)
        #expect(fired)
    }

    @Test func forwardsDidDisconnectWithTimestamp() {
        let sut = FCBCentralManagerDelegate()
        var capturedReconnecting: Bool?
        sut.onDidDisconnectWithTimestamp = { _, _, _, isReconnecting, _ in
            capturedReconnecting = isReconnecting
        }
        sut.centralManager(BLETestStub.centralManager(),
                           didDisconnectPeripheral: BLETestStub.peripheral(),
                           timestamp: 0,
                           isReconnecting: true,
                           error: nil)
        #expect(capturedReconnecting == true)
    }

    @Test func forwardsConnectionEventDidOccur() {
        let sut = FCBCentralManagerDelegate()
        var fired = false
        sut.onConnectionEventDidOccur = { _, _, _ in fired = true }
        sut.centralManager(BLETestStub.centralManager(),
                           connectionEventDidOccur: .peerConnected,
                           for: BLETestStub.peripheral())
        #expect(fired)
    }

    @Test func forwardsDidUpdateANCSAuthorization() {
        let sut = FCBCentralManagerDelegate()
        var fired = false
        sut.onDidUpdateANCSAuthorization = { _, _ in fired = true }
        sut.centralManager(BLETestStub.centralManager(),
                           didUpdateANCSAuthorizationFor: BLETestStub.peripheral())
        #expect(fired)
    }
}
```

- [ ] **Step 3: Run tests — confirm they fail to compile (no `FCBCentralManagerDelegate` symbol yet)**

Run: `swift test --filter FCBCentralManagerDelegateTests`
Expected: build fails with "cannot find 'FCBCentralManagerDelegate' in scope" (or similar). This is the red phase.

- [ ] **Step 4: Write the implementation**

Create `Sources/FCB/FCBCentralManagerDelegate.swift`:

```swift
import CoreBluetooth
import Foundation

open class FCBCentralManagerDelegate: NSObject, CBCentralManagerDelegate {
    public var onDidUpdateState: (@Sendable (CBCentralManager) -> Void)?
    public var onWillRestoreState: (@Sendable (CBCentralManager, [String: Any]) -> Void)?
    public var onDidDiscover: (@Sendable (CBCentralManager, CBPeripheral, [String: Any], NSNumber) -> Void)?
    public var onDidConnect: (@Sendable (CBCentralManager, CBPeripheral) -> Void)?
    public var onDidFailToConnect: (@Sendable (CBCentralManager, CBPeripheral, (any Error)?) -> Void)?
    public var onDidDisconnect: (@Sendable (CBCentralManager, CBPeripheral, (any Error)?) -> Void)?
    public var onDidDisconnectWithTimestamp: (@Sendable (CBCentralManager, CBPeripheral, CFAbsoluteTime, Bool, (any Error)?) -> Void)?
    public var onConnectionEventDidOccur: (@Sendable (CBCentralManager, CBConnectionEvent, CBPeripheral) -> Void)?
    public var onDidUpdateANCSAuthorization: (@Sendable (CBCentralManager, CBPeripheral) -> Void)?

    public override init() { super.init() }

    open func centralManagerDidUpdateState(_ central: CBCentralManager) {
        onDidUpdateState?(central)
    }
    open func centralManager(_ central: CBCentralManager, willRestoreState dict: [String: Any]) {
        onWillRestoreState?(central, dict)
    }
    open func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String: Any], rssi RSSI: NSNumber) {
        onDidDiscover?(central, peripheral, advertisementData, RSSI)
    }
    open func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        onDidConnect?(central, peripheral)
    }
    open func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: (any Error)?) {
        onDidFailToConnect?(central, peripheral, error)
    }
    open func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: (any Error)?) {
        onDidDisconnect?(central, peripheral, error)
    }
    open func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, timestamp: CFAbsoluteTime, isReconnecting: Bool, error: (any Error)?) {
        onDidDisconnectWithTimestamp?(central, peripheral, timestamp, isReconnecting, error)
    }
    open func centralManager(_ central: CBCentralManager, connectionEventDidOccur event: CBConnectionEvent, for peripheral: CBPeripheral) {
        onConnectionEventDidOccur?(central, event, peripheral)
    }
    open func centralManager(_ central: CBCentralManager, didUpdateANCSAuthorizationFor peripheral: CBPeripheral) {
        onDidUpdateANCSAuthorization?(central, peripheral)
    }
}
```

- [ ] **Step 5: Run tests — confirm they pass**

Run: `swift test --filter FCBCentralManagerDelegateTests`
Expected: 9/9 tests pass.

- [ ] **Step 6: Mutation test — verify the tests actually exercise the forwards**

Apply this batch mutation to `Sources/FCB/FCBCentralManagerDelegate.swift`: comment out every `on…?(...)` invocation in every `open func` body (so the delegate methods become empty).

Run: `swift test --filter FCBCentralManagerDelegateTests`
Expected: all 9 tests fail (none of the closures fire).

- [ ] **Step 7: Revert mutation — confirm green again**

Restore the file (`git checkout -- Sources/FCB/FCBCentralManagerDelegate.swift`).
Run: `swift test --filter FCBCentralManagerDelegateTests`
Expected: 9/9 tests pass.

- [ ] **Step 8: Commit**

Run: `git add Sources/FCB/FCBCentralManagerDelegate.swift Tests/FCBTests/BLETestStub.swift Tests/FCBTests/FCBCentralManagerDelegateTests.swift`
Run: `git commit -m "Add FCBCentralManagerDelegate closure-shim wrapper"`

---

### Task 4: `FCBPeripheralDelegate` — tests + implementation

**Files:**
- Create: `Tests/FCBTests/FCBPeripheralDelegateTests.swift`
- Create: `Sources/FCB/FCBPeripheralDelegate.swift`

- [ ] **Step 1: Write the failing tests**

Create `Tests/FCBTests/FCBPeripheralDelegateTests.swift`:

```swift
import CoreBluetooth
import Testing
@testable import FCB

struct FCBPeripheralDelegateTests {
    @Test func forwardsDidUpdateName() {
        let sut = FCBPeripheralDelegate()
        var fired = false
        sut.onDidUpdateName = { _ in fired = true }
        sut.peripheralDidUpdateName(BLETestStub.peripheral())
        #expect(fired)
    }

    @Test func forwardsDidModifyServices() {
        let sut = FCBPeripheralDelegate()
        var count: Int?
        sut.onDidModifyServices = { _, services in count = services.count }
        sut.peripheral(BLETestStub.peripheral(), didModifyServices: [BLETestStub.service()])
        #expect(count == 1)
    }

    @Test func forwardsDidReadRSSI() {
        let sut = FCBPeripheralDelegate()
        var capturedRSSI: NSNumber?
        sut.onDidReadRSSI = { _, rssi, _ in capturedRSSI = rssi }
        sut.peripheral(BLETestStub.peripheral(), didReadRSSI: NSNumber(value: -55), error: nil)
        #expect(capturedRSSI?.intValue == -55)
    }

    @Test func forwardsDidDiscoverServices() {
        let sut = FCBPeripheralDelegate()
        var fired = false
        sut.onDidDiscoverServices = { _, _ in fired = true }
        sut.peripheral(BLETestStub.peripheral(), didDiscoverServices: nil)
        #expect(fired)
    }

    @Test func forwardsDidDiscoverIncludedServices() {
        let sut = FCBPeripheralDelegate()
        var fired = false
        sut.onDidDiscoverIncludedServices = { _, _, _ in fired = true }
        sut.peripheral(BLETestStub.peripheral(),
                       didDiscoverIncludedServicesFor: BLETestStub.service(),
                       error: nil)
        #expect(fired)
    }

    @Test func forwardsDidDiscoverCharacteristics() {
        let sut = FCBPeripheralDelegate()
        var fired = false
        sut.onDidDiscoverCharacteristics = { _, _, _ in fired = true }
        sut.peripheral(BLETestStub.peripheral(),
                       didDiscoverCharacteristicsFor: BLETestStub.service(),
                       error: nil)
        #expect(fired)
    }

    @Test func forwardsDidDiscoverDescriptors() {
        let sut = FCBPeripheralDelegate()
        var fired = false
        sut.onDidDiscoverDescriptors = { _, _, _ in fired = true }
        sut.peripheral(BLETestStub.peripheral(),
                       didDiscoverDescriptorsFor: BLETestStub.characteristic(),
                       error: nil)
        #expect(fired)
    }

    @Test func forwardsDidUpdateValueForCharacteristic() {
        let sut = FCBPeripheralDelegate()
        var fired = false
        sut.onDidUpdateValueForCharacteristic = { _, _, _ in fired = true }
        sut.peripheral(BLETestStub.peripheral(),
                       didUpdateValueFor: BLETestStub.characteristic(),
                       error: nil)
        #expect(fired)
    }

    @Test func forwardsDidWriteValueForCharacteristic() {
        let sut = FCBPeripheralDelegate()
        var fired = false
        sut.onDidWriteValueForCharacteristic = { _, _, _ in fired = true }
        sut.peripheral(BLETestStub.peripheral(),
                       didWriteValueFor: BLETestStub.characteristic(),
                       error: nil)
        #expect(fired)
    }

    @Test func forwardsDidUpdateNotificationState() {
        let sut = FCBPeripheralDelegate()
        var fired = false
        sut.onDidUpdateNotificationState = { _, _, _ in fired = true }
        sut.peripheral(BLETestStub.peripheral(),
                       didUpdateNotificationStateFor: BLETestStub.characteristic(),
                       error: nil)
        #expect(fired)
    }

    @Test func forwardsIsReadyToSendWriteWithoutResponse() {
        let sut = FCBPeripheralDelegate()
        var fired = false
        sut.onIsReadyToSendWriteWithoutResponse = { _ in fired = true }
        sut.peripheralIsReady(toSendWriteWithoutResponse: BLETestStub.peripheral())
        #expect(fired)
    }
}
```

- [ ] **Step 2: Run tests — expect compile failure**

Run: `swift test --filter FCBPeripheralDelegateTests`
Expected: "cannot find 'FCBPeripheralDelegate' in scope". Red phase.

- [ ] **Step 3: Write the implementation**

Create `Sources/FCB/FCBPeripheralDelegate.swift`:

```swift
import CoreBluetooth
import Foundation

open class FCBPeripheralDelegate: NSObject, CBPeripheralDelegate {
    public var onDidUpdateName: (@Sendable (CBPeripheral) -> Void)?
    public var onDidModifyServices: (@Sendable (CBPeripheral, [CBService]) -> Void)?
    public var onDidReadRSSI: (@Sendable (CBPeripheral, NSNumber, (any Error)?) -> Void)?
    public var onDidDiscoverServices: (@Sendable (CBPeripheral, (any Error)?) -> Void)?
    public var onDidDiscoverIncludedServices: (@Sendable (CBPeripheral, CBService, (any Error)?) -> Void)?
    public var onDidDiscoverCharacteristics: (@Sendable (CBPeripheral, CBService, (any Error)?) -> Void)?
    public var onDidDiscoverDescriptors: (@Sendable (CBPeripheral, CBCharacteristic, (any Error)?) -> Void)?
    public var onDidUpdateValueForCharacteristic: (@Sendable (CBPeripheral, CBCharacteristic, (any Error)?) -> Void)?
    public var onDidUpdateValueForDescriptor: (@Sendable (CBPeripheral, CBDescriptor, (any Error)?) -> Void)?
    public var onDidWriteValueForCharacteristic: (@Sendable (CBPeripheral, CBCharacteristic, (any Error)?) -> Void)?
    public var onDidWriteValueForDescriptor: (@Sendable (CBPeripheral, CBDescriptor, (any Error)?) -> Void)?
    public var onDidUpdateNotificationState: (@Sendable (CBPeripheral, CBCharacteristic, (any Error)?) -> Void)?
    public var onIsReadyToSendWriteWithoutResponse: (@Sendable (CBPeripheral) -> Void)?
    public var onDidOpenL2CAPChannel: (@Sendable (CBPeripheral, CBL2CAPChannel?, (any Error)?) -> Void)?

    public override init() { super.init() }

    open func peripheralDidUpdateName(_ peripheral: CBPeripheral) {
        onDidUpdateName?(peripheral)
    }
    open func peripheral(_ peripheral: CBPeripheral, didModifyServices invalidatedServices: [CBService]) {
        onDidModifyServices?(peripheral, invalidatedServices)
    }
    open func peripheral(_ peripheral: CBPeripheral, didReadRSSI RSSI: NSNumber, error: (any Error)?) {
        onDidReadRSSI?(peripheral, RSSI, error)
    }
    open func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: (any Error)?) {
        onDidDiscoverServices?(peripheral, error)
    }
    open func peripheral(_ peripheral: CBPeripheral, didDiscoverIncludedServicesFor service: CBService, error: (any Error)?) {
        onDidDiscoverIncludedServices?(peripheral, service, error)
    }
    open func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: (any Error)?) {
        onDidDiscoverCharacteristics?(peripheral, service, error)
    }
    open func peripheral(_ peripheral: CBPeripheral, didDiscoverDescriptorsFor characteristic: CBCharacteristic, error: (any Error)?) {
        onDidDiscoverDescriptors?(peripheral, characteristic, error)
    }
    open func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: (any Error)?) {
        onDidUpdateValueForCharacteristic?(peripheral, characteristic, error)
    }
    open func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor descriptor: CBDescriptor, error: (any Error)?) {
        onDidUpdateValueForDescriptor?(peripheral, descriptor, error)
    }
    open func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: (any Error)?) {
        onDidWriteValueForCharacteristic?(peripheral, characteristic, error)
    }
    open func peripheral(_ peripheral: CBPeripheral, didWriteValueFor descriptor: CBDescriptor, error: (any Error)?) {
        onDidWriteValueForDescriptor?(peripheral, descriptor, error)
    }
    open func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: (any Error)?) {
        onDidUpdateNotificationState?(peripheral, characteristic, error)
    }
    open func peripheralIsReady(toSendWriteWithoutResponse peripheral: CBPeripheral) {
        onIsReadyToSendWriteWithoutResponse?(peripheral)
    }
    open func peripheral(_ peripheral: CBPeripheral, didOpen channel: CBL2CAPChannel?, error: (any Error)?) {
        onDidOpenL2CAPChannel?(peripheral, channel, error)
    }
}
```

- [ ] **Step 4: Run tests — confirm they pass**

Run: `swift test --filter FCBPeripheralDelegateTests`
Expected: 11/11 tests pass.

- [ ] **Step 5: Mutation test**

Apply this batch mutation: comment out every `on…?(...)` invocation in every `open func` body.
Run: `swift test --filter FCBPeripheralDelegateTests`
Expected: all 11 tests fail.

- [ ] **Step 6: Revert mutation, confirm green**

Run: `git checkout -- Sources/FCB/FCBPeripheralDelegate.swift`
Run: `swift test --filter FCBPeripheralDelegateTests`
Expected: 11/11 pass.

- [ ] **Step 7: Commit**

Run: `git add Sources/FCB/FCBPeripheralDelegate.swift Tests/FCBTests/FCBPeripheralDelegateTests.swift`
Run: `git commit -m "Add FCBPeripheralDelegate closure-shim wrapper"`

---

### Task 5: `FCBPeripheralManagerDelegate` — tests + implementation

**Files:**
- Create: `Tests/FCBTests/FCBPeripheralManagerDelegateTests.swift`
- Create: `Sources/FCB/FCBPeripheralManagerDelegate.swift`

- [ ] **Step 1: Write the failing tests**

Create `Tests/FCBTests/FCBPeripheralManagerDelegateTests.swift`:

```swift
import CoreBluetooth
import Testing
@testable import FCB

struct FCBPeripheralManagerDelegateTests {
    @Test func forwardsDidUpdateState() {
        let sut = FCBPeripheralManagerDelegate()
        var fired = false
        sut.onDidUpdateState = { _ in fired = true }
        sut.peripheralManagerDidUpdateState(BLETestStub.peripheralManager())
        #expect(fired)
    }

    @Test func forwardsWillRestoreState() {
        let sut = FCBPeripheralManagerDelegate()
        var capturedKeys: [String]?
        sut.onWillRestoreState = { _, dict in capturedKeys = Array(dict.keys) }
        sut.peripheralManager(BLETestStub.peripheralManager(), willRestoreState: ["k": 1])
        #expect(capturedKeys == ["k"])
    }

    @Test func forwardsDidStartAdvertising() {
        let sut = FCBPeripheralManagerDelegate()
        var fired = false
        sut.onDidStartAdvertising = { _, _ in fired = true }
        sut.peripheralManagerDidStartAdvertising(BLETestStub.peripheralManager(), error: nil)
        #expect(fired)
    }

    @Test func forwardsDidAddService() {
        let sut = FCBPeripheralManagerDelegate()
        var fired = false
        sut.onDidAddService = { _, _, _ in fired = true }
        sut.peripheralManager(BLETestStub.peripheralManager(),
                              didAdd: BLETestStub.service(),
                              error: nil)
        #expect(fired)
    }

    @Test func forwardsDidSubscribeToCharacteristic() {
        let sut = FCBPeripheralManagerDelegate()
        var fired = false
        sut.onDidSubscribeToCharacteristic = { _, _, _ in fired = true }
        sut.peripheralManager(BLETestStub.peripheralManager(),
                              central: BLETestStub.central(),
                              didSubscribeTo: BLETestStub.characteristic())
        #expect(fired)
    }

    @Test func forwardsDidUnsubscribeFromCharacteristic() {
        let sut = FCBPeripheralManagerDelegate()
        var fired = false
        sut.onDidUnsubscribeFromCharacteristic = { _, _, _ in fired = true }
        sut.peripheralManager(BLETestStub.peripheralManager(),
                              central: BLETestStub.central(),
                              didUnsubscribeFrom: BLETestStub.characteristic())
        #expect(fired)
    }

    @Test func forwardsDidReceiveRead() {
        let sut = FCBPeripheralManagerDelegate()
        var fired = false
        sut.onDidReceiveRead = { _, _ in fired = true }
        sut.peripheralManager(BLETestStub.peripheralManager(),
                              didReceiveRead: BLETestStub.attRequest())
        #expect(fired)
    }

    @Test func forwardsDidReceiveWrite() {
        let sut = FCBPeripheralManagerDelegate()
        var count: Int?
        sut.onDidReceiveWrite = { _, requests in count = requests.count }
        sut.peripheralManager(BLETestStub.peripheralManager(),
                              didReceiveWrite: [BLETestStub.attRequest(), BLETestStub.attRequest()])
        #expect(count == 2)
    }

    @Test func forwardsIsReadyToUpdateSubscribers() {
        let sut = FCBPeripheralManagerDelegate()
        var fired = false
        sut.onIsReadyToUpdateSubscribers = { _ in fired = true }
        sut.peripheralManagerIsReady(toUpdateSubscribers: BLETestStub.peripheralManager())
        #expect(fired)
    }

    @Test func forwardsDidPublishL2CAPChannel() {
        let sut = FCBPeripheralManagerDelegate()
        var fired = false
        sut.onDidPublishL2CAPChannel = { _, _, _ in fired = true }
        sut.peripheralManager(BLETestStub.peripheralManager(),
                              didPublishL2CAPChannel: 1,
                              error: nil)
        #expect(fired)
    }

    @Test func forwardsDidUnpublishL2CAPChannel() {
        let sut = FCBPeripheralManagerDelegate()
        var fired = false
        sut.onDidUnpublishL2CAPChannel = { _, _, _ in fired = true }
        sut.peripheralManager(BLETestStub.peripheralManager(),
                              didUnpublishL2CAPChannel: 1,
                              error: nil)
        #expect(fired)
    }

    @Test func forwardsDidOpenL2CAPChannel() {
        let sut = FCBPeripheralManagerDelegate()
        var fired = false
        sut.onDidOpenL2CAPChannel = { _, _, _ in fired = true }
        sut.peripheralManager(BLETestStub.peripheralManager(),
                              didOpen: nil,
                              error: nil)
        #expect(fired)
    }
}
```

- [ ] **Step 2: Run tests — expect compile failure**

Run: `swift test --filter FCBPeripheralManagerDelegateTests`
Expected: "cannot find 'FCBPeripheralManagerDelegate'". Red phase.

- [ ] **Step 3: Write the implementation**

Create `Sources/FCB/FCBPeripheralManagerDelegate.swift`:

```swift
import CoreBluetooth
import Foundation

open class FCBPeripheralManagerDelegate: NSObject, CBPeripheralManagerDelegate {
    public var onDidUpdateState: (@Sendable (CBPeripheralManager) -> Void)?
    public var onWillRestoreState: (@Sendable (CBPeripheralManager, [String: Any]) -> Void)?
    public var onDidStartAdvertising: (@Sendable (CBPeripheralManager, (any Error)?) -> Void)?
    public var onDidAddService: (@Sendable (CBPeripheralManager, CBService, (any Error)?) -> Void)?
    public var onDidSubscribeToCharacteristic: (@Sendable (CBPeripheralManager, CBCentral, CBCharacteristic) -> Void)?
    public var onDidUnsubscribeFromCharacteristic: (@Sendable (CBPeripheralManager, CBCentral, CBCharacteristic) -> Void)?
    public var onDidReceiveRead: (@Sendable (CBPeripheralManager, CBATTRequest) -> Void)?
    public var onDidReceiveWrite: (@Sendable (CBPeripheralManager, [CBATTRequest]) -> Void)?
    public var onIsReadyToUpdateSubscribers: (@Sendable (CBPeripheralManager) -> Void)?
    public var onDidPublishL2CAPChannel: (@Sendable (CBPeripheralManager, CBL2CAPPSM, (any Error)?) -> Void)?
    public var onDidUnpublishL2CAPChannel: (@Sendable (CBPeripheralManager, CBL2CAPPSM, (any Error)?) -> Void)?
    public var onDidOpenL2CAPChannel: (@Sendable (CBPeripheralManager, CBL2CAPChannel?, (any Error)?) -> Void)?

    public override init() { super.init() }

    open func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        onDidUpdateState?(peripheral)
    }
    open func peripheralManager(_ peripheral: CBPeripheralManager, willRestoreState dict: [String: Any]) {
        onWillRestoreState?(peripheral, dict)
    }
    open func peripheralManagerDidStartAdvertising(_ peripheral: CBPeripheralManager, error: (any Error)?) {
        onDidStartAdvertising?(peripheral, error)
    }
    open func peripheralManager(_ peripheral: CBPeripheralManager, didAdd service: CBService, error: (any Error)?) {
        onDidAddService?(peripheral, service, error)
    }
    open func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral, didSubscribeTo characteristic: CBCharacteristic) {
        onDidSubscribeToCharacteristic?(peripheral, central, characteristic)
    }
    open func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral, didUnsubscribeFrom characteristic: CBCharacteristic) {
        onDidUnsubscribeFromCharacteristic?(peripheral, central, characteristic)
    }
    open func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveRead request: CBATTRequest) {
        onDidReceiveRead?(peripheral, request)
    }
    open func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveWrite requests: [CBATTRequest]) {
        onDidReceiveWrite?(peripheral, requests)
    }
    open func peripheralManagerIsReady(toUpdateSubscribers peripheral: CBPeripheralManager) {
        onIsReadyToUpdateSubscribers?(peripheral)
    }
    open func peripheralManager(_ peripheral: CBPeripheralManager, didPublishL2CAPChannel PSM: CBL2CAPPSM, error: (any Error)?) {
        onDidPublishL2CAPChannel?(peripheral, PSM, error)
    }
    open func peripheralManager(_ peripheral: CBPeripheralManager, didUnpublishL2CAPChannel PSM: CBL2CAPPSM, error: (any Error)?) {
        onDidUnpublishL2CAPChannel?(peripheral, PSM, error)
    }
    open func peripheralManager(_ peripheral: CBPeripheralManager, didOpen channel: CBL2CAPChannel?, error: (any Error)?) {
        onDidOpenL2CAPChannel?(peripheral, channel, error)
    }
}
```

- [ ] **Step 4: Run tests — confirm pass**

Run: `swift test --filter FCBPeripheralManagerDelegateTests`
Expected: 12/12 tests pass.

- [ ] **Step 5: Mutation test**

Comment out every `on…?(...)` invocation in every `open func` body.
Run: `swift test --filter FCBPeripheralManagerDelegateTests`
Expected: all 12 tests fail.

- [ ] **Step 6: Revert, confirm green**

Run: `git checkout -- Sources/FCB/FCBPeripheralManagerDelegate.swift`
Run: `swift test --filter FCBPeripheralManagerDelegateTests`
Expected: 12/12 pass.

- [ ] **Step 7: Commit**

Run: `git add Sources/FCB/FCBPeripheralManagerDelegate.swift Tests/FCBTests/FCBPeripheralManagerDelegateTests.swift`
Run: `git commit -m "Add FCBPeripheralManagerDelegate closure-shim wrapper"`

---

## Phase C — Layer 2 value types & errors

### Task 6: `BluetoothError` enum + NSError mapping

**Files:**
- Create: `Tests/FCBComposableTests/BluetoothErrorTests.swift`
- Create: `Sources/FCBComposable/Errors/BluetoothError.swift`
- Delete: `Sources/FCBComposable/.gitkeep`
- Delete: `Tests/FCBComposableTests/.gitkeep`

- [ ] **Step 1: Write the failing tests**

Create `Tests/FCBComposableTests/BluetoothErrorTests.swift`:

```swift
import CoreBluetooth
import Foundation
import Testing
@testable import FCBComposable

struct BluetoothErrorTests {
    @Test func mapsCBErrorOperationCancelled() {
        let nsError = NSError(domain: CBErrorDomain, code: CBError.operationCancelled.rawValue)
        let mapped = BluetoothError(nsError)
        #expect(mapped == .operationCancelled)
    }

    @Test func mapsCBATTErrorToATTCase() {
        let nsError = NSError(domain: CBATTErrorDomain, code: CBATTError.readNotPermitted.rawValue)
        let mapped = BluetoothError(nsError)
        #expect(mapped == .att(.readNotPermitted))
    }

    @Test func mapsUnknownDomainToUnderlying() {
        let nsError = NSError(domain: "com.example.weird", code: 42)
        let mapped = BluetoothError(nsError)
        if case .underlying(let underlying) = mapped {
            #expect(underlying.domain == "com.example.weird")
            #expect(underlying.code == 42)
        } else {
            Issue.record("expected .underlying, got \(mapped)")
        }
    }

    @Test func equatability() {
        #expect(BluetoothError.poweredOff == BluetoothError.poweredOff)
        #expect(BluetoothError.unknownPeripheral(UUID()) != BluetoothError.unknownPeripheral(UUID()))
    }
}
```

- [ ] **Step 2: Remove the placeholder gitkeeps so the target has real files**

Run: `rm Sources/FCBComposable/.gitkeep`
Run: `rm Tests/FCBComposableTests/.gitkeep`

- [ ] **Step 3: Run tests — expect compile failure**

Run: `swift test --filter BluetoothErrorTests`
Expected: "cannot find 'BluetoothError'". Red phase.

- [ ] **Step 4: Write the implementation**

Create `Sources/FCBComposable/Errors/BluetoothError.swift`:

```swift
import CoreBluetooth
import Foundation

public enum BluetoothError: Error, Sendable, Equatable {
    case unauthorized(CBManagerAuthorization)
    case poweredOff
    case unsupported
    case unknownPeripheral(UUID)
    case unknownService(CBUUID, peripheralID: UUID)
    case unknownCharacteristic(CBUUID, serviceID: CBUUID)
    case connectionFailed(peripheralID: UUID, underlying: NSError?)
    case disconnected(peripheralID: UUID, underlying: NSError?)
    case att(CBATTError.Code)
    case operationCancelled
    case underlying(NSError)
}

extension BluetoothError {
    public init(_ error: any Error) {
        let nsError = error as NSError
        switch nsError.domain {
        case CBErrorDomain:
            if let code = CBError.Code(rawValue: nsError.code), code == .operationCancelled {
                self = .operationCancelled
            } else {
                self = .underlying(nsError)
            }
        case CBATTErrorDomain:
            if let code = CBATTError.Code(rawValue: nsError.code) {
                self = .att(code)
            } else {
                self = .underlying(nsError)
            }
        default:
            self = .underlying(nsError)
        }
    }
}
```

- [ ] **Step 5: Run tests — confirm pass**

Run: `swift test --filter BluetoothErrorTests`
Expected: 4/4 pass.

- [ ] **Step 6: Mutation test**

Apply this batch mutation to `Sources/FCBComposable/Errors/BluetoothError.swift`: replace the body of `init(_ error: any Error)` with a single line `self = .underlying(error as NSError)`.

Run: `swift test --filter BluetoothErrorTests`
Expected: `mapsCBErrorOperationCancelled` and `mapsCBATTErrorToATTCase` fail; `mapsUnknownDomainToUnderlying` and `equatability` still pass.

- [ ] **Step 7: Revert, confirm green**

Run: `git checkout -- Sources/FCBComposable/Errors/BluetoothError.swift`
Run: `swift test --filter BluetoothErrorTests`
Expected: 4/4 pass.

- [ ] **Step 8: Commit**

Run: `git add Sources/FCBComposable/Errors/BluetoothError.swift Tests/FCBComposableTests/BluetoothErrorTests.swift Sources/FCBComposable/.gitkeep Tests/FCBComposableTests/.gitkeep`
Run: `git commit -m "Add BluetoothError enum with NSError classification"`

---

### Task 7: Trivial Sendable value types (`Peripheral`, `Service`, `Characteristic`, `Central`)

**Files:**
- Create: `Tests/FCBComposableTests/ValueTypeTests.swift`
- Create: `Sources/FCBComposable/Models/Peripheral.swift`
- Create: `Sources/FCBComposable/Models/Service.swift`
- Create: `Sources/FCBComposable/Models/Characteristic.swift`
- Create: `Sources/FCBComposable/Models/Central.swift`

- [ ] **Step 1: Write the failing tests**

Create `Tests/FCBComposableTests/ValueTypeTests.swift`:

```swift
import CoreBluetooth
import Foundation
import Testing
@testable import FCBComposable

struct ValueTypeTests {
    @Test func peripheralIdentityAndEquality() {
        let id = UUID()
        let a = Peripheral(id: id, name: "X", state: .connected)
        let b = Peripheral(id: id, name: "X", state: .connected)
        #expect(a == b)
        #expect(a.id == id)
    }

    @Test func connectionStateIsExhaustive() {
        let allCases: [ConnectionState] = [.disconnected, .connecting, .connected, .disconnecting]
        #expect(Set(allCases).count == 4)
    }

    @Test func serviceUsesCBUUIDAsID() {
        let uuid = CBUUID(string: "180F")
        let pid = UUID()
        let svc = Service(id: uuid, peripheralID: pid, isPrimary: true)
        #expect(svc.id == uuid)
        #expect(svc.peripheralID == pid)
    }

    @Test func characteristicCarriesProperties() {
        let charUUID = CBUUID(string: "2A19")
        let svcUUID = CBUUID(string: "180F")
        let pid = UUID()
        let char = Characteristic(id: charUUID, serviceID: svcUUID, peripheralID: pid,
                                  properties: [.read, .notify], value: Data([0x01]), isNotifying: true)
        #expect(char.properties.contains(.read))
        #expect(char.properties.contains(.notify))
        #expect(char.value == Data([0x01]))
        #expect(char.isNotifying)
    }

    @Test func centralCarriesMaxUpdateLength() {
        let id = UUID()
        let central = Central(id: id, maximumUpdateValueLength: 512)
        #expect(central.id == id)
        #expect(central.maximumUpdateValueLength == 512)
    }
}
```

- [ ] **Step 2: Run tests — expect compile failure**

Run: `swift test --filter ValueTypeTests`
Expected: cannot find `Peripheral`/`Service`/`Characteristic`/`Central`. Red phase.

- [ ] **Step 3: Write `Peripheral.swift`**

Create `Sources/FCBComposable/Models/Peripheral.swift`:

```swift
import Foundation

public enum ConnectionState: Sendable, Hashable {
    case disconnected
    case connecting
    case connected
    case disconnecting
}

public struct Peripheral: Sendable, Identifiable, Hashable {
    public let id: UUID
    public let name: String?
    public let state: ConnectionState

    public init(id: UUID, name: String?, state: ConnectionState) {
        self.id = id
        self.name = name
        self.state = state
    }
}
```

- [ ] **Step 4: Write `Service.swift`**

Create `Sources/FCBComposable/Models/Service.swift`:

```swift
import CoreBluetooth
import Foundation

public struct Service: Sendable, Identifiable, Hashable {
    public let id: CBUUID
    public let peripheralID: UUID
    public let isPrimary: Bool

    public init(id: CBUUID, peripheralID: UUID, isPrimary: Bool) {
        self.id = id
        self.peripheralID = peripheralID
        self.isPrimary = isPrimary
    }
}
```

- [ ] **Step 5: Write `Characteristic.swift`**

Create `Sources/FCBComposable/Models/Characteristic.swift`:

```swift
import CoreBluetooth
import Foundation

public struct Characteristic: Sendable, Identifiable, Hashable {
    public let id: CBUUID
    public let serviceID: CBUUID
    public let peripheralID: UUID
    public let properties: CBCharacteristicProperties
    public let value: Data?
    public let isNotifying: Bool

    public init(id: CBUUID, serviceID: CBUUID, peripheralID: UUID,
                properties: CBCharacteristicProperties, value: Data?, isNotifying: Bool) {
        self.id = id
        self.serviceID = serviceID
        self.peripheralID = peripheralID
        self.properties = properties
        self.value = value
        self.isNotifying = isNotifying
    }
}
```

- [ ] **Step 6: Write `Central.swift`**

Create `Sources/FCBComposable/Models/Central.swift`:

```swift
import Foundation

public struct Central: Sendable, Identifiable, Hashable {
    public let id: UUID
    public let maximumUpdateValueLength: Int

    public init(id: UUID, maximumUpdateValueLength: Int) {
        self.id = id
        self.maximumUpdateValueLength = maximumUpdateValueLength
    }
}
```

- [ ] **Step 7: Run tests — confirm pass**

Run: `swift test --filter ValueTypeTests`
Expected: 5/5 pass.

- [ ] **Step 8: Mutation test**

Apply this batch mutation: in `Peripheral.init`, swap `self.id = id` with `self.id = UUID()`. In `Service.init`, swap `self.isPrimary = isPrimary` with `self.isPrimary = false`. In `Characteristic.init`, swap `self.isNotifying = isNotifying` with `self.isNotifying = false`. In `Central.init`, swap `self.maximumUpdateValueLength = maximumUpdateValueLength` with `self.maximumUpdateValueLength = 0`.

Run: `swift test --filter ValueTypeTests`
Expected: `peripheralIdentityAndEquality`, `serviceUsesCBUUIDAsID` (`isPrimary` not asserted — may still pass), `characteristicCarriesProperties`, `centralCarriesMaxUpdateLength` fail.

Note: this mutation may not break every test (e.g. `serviceUsesCBUUIDAsID` doesn't assert `isPrimary`). If a test does not fail under the mutation, that test is incomplete — extend it to assert the mutated field, then re-run from Step 7.

- [ ] **Step 9: Revert, confirm green**

Run: `git checkout -- Sources/FCBComposable/Models`
Run: `swift test --filter ValueTypeTests`
Expected: 5/5 pass.

- [ ] **Step 10: Commit**

Run: `git add Sources/FCBComposable/Models/Peripheral.swift Sources/FCBComposable/Models/Service.swift Sources/FCBComposable/Models/Characteristic.swift Sources/FCBComposable/Models/Central.swift Tests/FCBComposableTests/ValueTypeTests.swift`
Run: `git commit -m "Add Peripheral, Service, Characteristic, Central value types"`

---

### Task 8: `AdvertisementData` with dictionary decoding

**Files:**
- Create: `Tests/FCBComposableTests/AdvertisementDataTests.swift`
- Create: `Sources/FCBComposable/Models/AdvertisementData.swift`

- [ ] **Step 1: Write the failing tests**

Create `Tests/FCBComposableTests/AdvertisementDataTests.swift`:

```swift
import CoreBluetooth
import Foundation
import Testing
@testable import FCBComposable

struct AdvertisementDataTests {
    @Test func decodesLocalName() {
        let dict: [String: Any] = [CBAdvertisementDataLocalNameKey: "MyDevice"]
        let ad = AdvertisementData(dictionary: dict)
        #expect(ad.localName == "MyDevice")
    }

    @Test func decodesServiceUUIDs() {
        let uuid = CBUUID(string: "180F")
        let dict: [String: Any] = [CBAdvertisementDataServiceUUIDsKey: [uuid]]
        let ad = AdvertisementData(dictionary: dict)
        #expect(ad.serviceUUIDs == [uuid])
    }

    @Test func decodesManufacturerData() {
        let data = Data([0xDE, 0xAD, 0xBE, 0xEF])
        let dict: [String: Any] = [CBAdvertisementDataManufacturerDataKey: data]
        let ad = AdvertisementData(dictionary: dict)
        #expect(ad.manufacturerData == data)
    }

    @Test func decodesTxPowerLevel() {
        let dict: [String: Any] = [CBAdvertisementDataTxPowerLevelKey: NSNumber(value: -12)]
        let ad = AdvertisementData(dictionary: dict)
        #expect(ad.txPowerLevel == -12)
    }

    @Test func decodesIsConnectable() {
        let dict: [String: Any] = [CBAdvertisementDataIsConnectable: NSNumber(value: true)]
        let ad = AdvertisementData(dictionary: dict)
        #expect(ad.isConnectable == true)
    }

    @Test func decodesServiceData() {
        let uuid = CBUUID(string: "180F")
        let payload = Data([0xAB])
        let dict: [String: Any] = [CBAdvertisementDataServiceDataKey: [uuid: payload]]
        let ad = AdvertisementData(dictionary: dict)
        #expect(ad.serviceData[uuid] == payload)
    }

    @Test func emptyDictionaryProducesEmptyAdvertisementData() {
        let ad = AdvertisementData(dictionary: [:])
        #expect(ad.localName == nil)
        #expect(ad.serviceUUIDs.isEmpty)
        #expect(ad.manufacturerData == nil)
        #expect(ad.txPowerLevel == nil)
        #expect(ad.isConnectable == nil)
        #expect(ad.solicitedServiceUUIDs.isEmpty)
        #expect(ad.overflowServiceUUIDs.isEmpty)
        #expect(ad.serviceData.isEmpty)
    }
}
```

- [ ] **Step 2: Run tests — expect compile failure**

Run: `swift test --filter AdvertisementDataTests`
Expected: cannot find `AdvertisementData`. Red phase.

- [ ] **Step 3: Write the implementation**

Create `Sources/FCBComposable/Models/AdvertisementData.swift`:

```swift
import CoreBluetooth
import Foundation

public struct AdvertisementData: Sendable, Hashable {
    public let localName: String?
    public let serviceUUIDs: [CBUUID]
    public let manufacturerData: Data?
    public let txPowerLevel: Int?
    public let isConnectable: Bool?
    public let solicitedServiceUUIDs: [CBUUID]
    public let overflowServiceUUIDs: [CBUUID]
    public let serviceData: [CBUUID: Data]

    public init(
        localName: String? = nil,
        serviceUUIDs: [CBUUID] = [],
        manufacturerData: Data? = nil,
        txPowerLevel: Int? = nil,
        isConnectable: Bool? = nil,
        solicitedServiceUUIDs: [CBUUID] = [],
        overflowServiceUUIDs: [CBUUID] = [],
        serviceData: [CBUUID: Data] = [:]
    ) {
        self.localName = localName
        self.serviceUUIDs = serviceUUIDs
        self.manufacturerData = manufacturerData
        self.txPowerLevel = txPowerLevel
        self.isConnectable = isConnectable
        self.solicitedServiceUUIDs = solicitedServiceUUIDs
        self.overflowServiceUUIDs = overflowServiceUUIDs
        self.serviceData = serviceData
    }

    public init(dictionary: [String: Any]) {
        self.init(
            localName: dictionary[CBAdvertisementDataLocalNameKey] as? String,
            serviceUUIDs: dictionary[CBAdvertisementDataServiceUUIDsKey] as? [CBUUID] ?? [],
            manufacturerData: dictionary[CBAdvertisementDataManufacturerDataKey] as? Data,
            txPowerLevel: (dictionary[CBAdvertisementDataTxPowerLevelKey] as? NSNumber)?.intValue,
            isConnectable: (dictionary[CBAdvertisementDataIsConnectable] as? NSNumber)?.boolValue,
            solicitedServiceUUIDs: dictionary[CBAdvertisementDataSolicitedServiceUUIDsKey] as? [CBUUID] ?? [],
            overflowServiceUUIDs: dictionary[CBAdvertisementDataOverflowServiceUUIDsKey] as? [CBUUID] ?? [],
            serviceData: dictionary[CBAdvertisementDataServiceDataKey] as? [CBUUID: Data] ?? [:]
        )
    }
}
```

- [ ] **Step 4: Run tests — confirm pass**

Run: `swift test --filter AdvertisementDataTests`
Expected: 7/7 pass.

- [ ] **Step 5: Mutation test**

Apply this batch mutation: change `init(dictionary:)` to a single line that delegates to the memberwise init with all defaults, ignoring the dictionary entirely.

Run: `swift test --filter AdvertisementDataTests`
Expected: every test except `emptyDictionaryProducesEmptyAdvertisementData` fails.

- [ ] **Step 6: Revert, confirm green**

Run: `git checkout -- Sources/FCBComposable/Models/AdvertisementData.swift`
Run: `swift test --filter AdvertisementDataTests`
Expected: 7/7 pass.

- [ ] **Step 7: Commit**

Run: `git add Sources/FCBComposable/Models/AdvertisementData.swift Tests/FCBComposableTests/AdvertisementDataTests.swift`
Run: `git commit -m "Add AdvertisementData value type with dictionary decoding"`

---

### Task 9: Remaining value types (`DiscoveredPeripheral`, `Requests`, `MutableService`, `RestorationState`, `SubscriptionEvent`, `ScanOptions`, `ConnectOptions`)

**Files:**
- Create: `Sources/FCBComposable/Models/DiscoveredPeripheral.swift`
- Create: `Sources/FCBComposable/Models/Requests.swift`
- Create: `Sources/FCBComposable/Models/MutableService.swift`
- Create: `Sources/FCBComposable/Models/RestorationState.swift`
- Create: `Sources/FCBComposable/Models/SubscriptionEvent.swift`
- Create: `Sources/FCBComposable/Models/ScanOptions.swift`
- Create: `Sources/FCBComposable/Models/ConnectOptions.swift`
- Modify: `Tests/FCBComposableTests/ValueTypeTests.swift` (append tests)

- [ ] **Step 1: Append tests to `ValueTypeTests.swift`**

Insert these test methods inside the existing `struct ValueTypeTests { … }`:

```swift
    @Test func discoveredPeripheralBundlesAdAndRSSI() {
        let p = Peripheral(id: UUID(), name: "X", state: .disconnected)
        let ad = AdvertisementData(localName: "X")
        let d = DiscoveredPeripheral(peripheral: p, advertisementData: ad, rssi: -60)
        #expect(d.peripheral == p)
        #expect(d.rssi == -60)
    }

    @Test func readRequestExposesCentralAndCharacteristic() {
        let req = ReadRequest(
            id: UUID(),
            central: Central(id: UUID(), maximumUpdateValueLength: 256),
            characteristic: Characteristic(id: CBUUID(string: "2A19"), serviceID: CBUUID(string: "180F"),
                                           peripheralID: UUID(), properties: [.read], value: nil, isNotifying: false),
            offset: 4
        )
        #expect(req.offset == 4)
    }

    @Test func writeRequestExposesValue() {
        let req = WriteRequest(
            id: UUID(),
            central: Central(id: UUID(), maximumUpdateValueLength: 256),
            characteristic: Characteristic(id: CBUUID(string: "2A19"), serviceID: CBUUID(string: "180F"),
                                           peripheralID: UUID(), properties: [.write], value: nil, isNotifying: false),
            offset: 0,
            value: Data([0xFF])
        )
        #expect(req.value == Data([0xFF]))
    }

    @Test func mutableServiceCarriesCharacteristics() {
        let svc = MutableService(
            id: CBUUID(string: "180F"),
            isPrimary: true,
            characteristics: [MutableCharacteristic(id: CBUUID(string: "2A19"),
                                                    properties: [.read],
                                                    permissions: [.readable],
                                                    value: nil)]
        )
        #expect(svc.characteristics.count == 1)
    }

    @Test func subscriptionEventDistinguishesSubscribeAndUnsubscribe() {
        let central = Central(id: UUID(), maximumUpdateValueLength: 128)
        let char = Characteristic(id: CBUUID(string: "2A19"), serviceID: CBUUID(string: "180F"),
                                  peripheralID: UUID(), properties: [.notify], value: nil, isNotifying: true)
        let a = SubscriptionEvent.subscribed(central: central, characteristic: char)
        let b = SubscriptionEvent.unsubscribed(central: central, characteristic: char)
        #expect(a != b)
    }

    @Test func scanOptionsAllowsDuplicates() {
        let opts = ScanOptions(allowDuplicates: true, solicitedServiceUUIDs: nil)
        #expect(opts.allowDuplicates == true)
    }

    @Test func connectOptionsNotifyOnConnection() {
        let opts = ConnectOptions(notifyOnConnection: true, notifyOnDisconnection: false, notifyOnNotification: false)
        #expect(opts.notifyOnConnection == true)
    }
}
```

(Note: paste these methods inside the existing struct's braces. Do not duplicate the `struct ValueTypeTests {` declaration.)

- [ ] **Step 2: Run tests — expect compile failure**

Run: `swift test --filter ValueTypeTests`
Expected: cannot find `DiscoveredPeripheral` / `ReadRequest` / etc. Red phase.

- [ ] **Step 3: Write `DiscoveredPeripheral.swift`**

```swift
import Foundation

public struct DiscoveredPeripheral: Sendable, Hashable {
    public let peripheral: Peripheral
    public let advertisementData: AdvertisementData
    public let rssi: Int

    public init(peripheral: Peripheral, advertisementData: AdvertisementData, rssi: Int) {
        self.peripheral = peripheral
        self.advertisementData = advertisementData
        self.rssi = rssi
    }
}
```

- [ ] **Step 4: Write `Requests.swift`**

```swift
import Foundation

public struct ReadRequest: Sendable, Identifiable, Hashable {
    public let id: UUID
    public let central: Central
    public let characteristic: Characteristic
    public let offset: Int

    public init(id: UUID, central: Central, characteristic: Characteristic, offset: Int) {
        self.id = id
        self.central = central
        self.characteristic = characteristic
        self.offset = offset
    }
}

public struct WriteRequest: Sendable, Identifiable, Hashable {
    public let id: UUID
    public let central: Central
    public let characteristic: Characteristic
    public let offset: Int
    public let value: Data?

    public init(id: UUID, central: Central, characteristic: Characteristic, offset: Int, value: Data?) {
        self.id = id
        self.central = central
        self.characteristic = characteristic
        self.offset = offset
        self.value = value
    }
}
```

- [ ] **Step 5: Write `MutableService.swift`**

```swift
import CoreBluetooth
import Foundation

public struct MutableCharacteristic: Sendable, Hashable {
    public let id: CBUUID
    public let properties: CBCharacteristicProperties
    public let permissions: CBAttributePermissions
    public let value: Data?

    public init(id: CBUUID, properties: CBCharacteristicProperties, permissions: CBAttributePermissions, value: Data?) {
        self.id = id
        self.properties = properties
        self.permissions = permissions
        self.value = value
    }
}

public struct MutableService: Sendable, Hashable {
    public let id: CBUUID
    public let isPrimary: Bool
    public let characteristics: [MutableCharacteristic]

    public init(id: CBUUID, isPrimary: Bool, characteristics: [MutableCharacteristic]) {
        self.id = id
        self.isPrimary = isPrimary
        self.characteristics = characteristics
    }
}
```

- [ ] **Step 6: Write `RestorationState.swift`**

```swift
import Foundation

public struct RestorationState: Sendable, Hashable {
    public let peripherals: [Peripheral]
    public let scanServiceUUIDs: [String]
    public let scanOptions: ScanOptions?

    public init(peripherals: [Peripheral] = [], scanServiceUUIDs: [String] = [], scanOptions: ScanOptions? = nil) {
        self.peripherals = peripherals
        self.scanServiceUUIDs = scanServiceUUIDs
        self.scanOptions = scanOptions
    }
}
```

- [ ] **Step 7: Write `SubscriptionEvent.swift`**

```swift
public enum SubscriptionEvent: Sendable, Hashable {
    case subscribed(central: Central, characteristic: Characteristic)
    case unsubscribed(central: Central, characteristic: Characteristic)
}
```

- [ ] **Step 8: Write `ScanOptions.swift`**

```swift
import CoreBluetooth
import Foundation

public struct ScanOptions: Sendable, Hashable {
    public let allowDuplicates: Bool
    public let solicitedServiceUUIDs: [CBUUID]?

    public init(allowDuplicates: Bool = false, solicitedServiceUUIDs: [CBUUID]? = nil) {
        self.allowDuplicates = allowDuplicates
        self.solicitedServiceUUIDs = solicitedServiceUUIDs
    }

    public var dictionary: [String: Any] {
        var d: [String: Any] = [
            CBCentralManagerScanOptionAllowDuplicatesKey: NSNumber(value: allowDuplicates)
        ]
        if let solicitedServiceUUIDs {
            d[CBCentralManagerScanOptionSolicitedServiceUUIDsKey] = solicitedServiceUUIDs
        }
        return d
    }
}
```

- [ ] **Step 9: Write `ConnectOptions.swift`**

```swift
import CoreBluetooth
import Foundation

public struct ConnectOptions: Sendable, Hashable {
    public let notifyOnConnection: Bool
    public let notifyOnDisconnection: Bool
    public let notifyOnNotification: Bool

    public init(notifyOnConnection: Bool = false,
                notifyOnDisconnection: Bool = false,
                notifyOnNotification: Bool = false) {
        self.notifyOnConnection = notifyOnConnection
        self.notifyOnDisconnection = notifyOnDisconnection
        self.notifyOnNotification = notifyOnNotification
    }

    public var dictionary: [String: Any] {
        [
            CBConnectPeripheralOptionNotifyOnConnectionKey: NSNumber(value: notifyOnConnection),
            CBConnectPeripheralOptionNotifyOnDisconnectionKey: NSNumber(value: notifyOnDisconnection),
            CBConnectPeripheralOptionNotifyOnNotificationKey: NSNumber(value: notifyOnNotification)
        ]
    }
}
```

- [ ] **Step 10: Run tests — confirm pass**

Run: `swift test --filter ValueTypeTests`
Expected: 12/12 pass (5 from Task 7 + 7 from this task).

- [ ] **Step 11: Mutation test**

Apply this batch mutation: in `DiscoveredPeripheral.init`, swap `self.rssi = rssi` with `self.rssi = 0`. In `ReadRequest.init`, swap `self.offset = offset` with `self.offset = 0`. In `WriteRequest.init`, swap `self.value = value` with `self.value = nil`. In `MutableService.init`, swap `self.characteristics = characteristics` with `self.characteristics = []`. In `ScanOptions.init`, swap `self.allowDuplicates = allowDuplicates` with `self.allowDuplicates = false`. In `ConnectOptions.init`, swap `self.notifyOnConnection = notifyOnConnection` with `self.notifyOnConnection = false`.

Run: `swift test --filter ValueTypeTests`
Expected: all 7 tests added in this task fail; the original 5 from Task 7 still pass.

- [ ] **Step 12: Revert, confirm green**

Run: `git checkout -- Sources/FCBComposable/Models`
Run: `swift test --filter ValueTypeTests`
Expected: 12/12 pass.

- [ ] **Step 13: Commit**

Run: `git add Sources/FCBComposable/Models/DiscoveredPeripheral.swift Sources/FCBComposable/Models/Requests.swift Sources/FCBComposable/Models/MutableService.swift Sources/FCBComposable/Models/RestorationState.swift Sources/FCBComposable/Models/SubscriptionEvent.swift Sources/FCBComposable/Models/ScanOptions.swift Sources/FCBComposable/Models/ConnectOptions.swift Tests/FCBComposableTests/ValueTypeTests.swift`
Run: `git commit -m "Add remaining FCBComposable value types"`

---

### Task 10: CB → value-type converters

**Files:**
- Create: `Sources/FCBComposable/Models/Peripheral+CB.swift`
- Create: `Sources/FCBComposable/Models/Service+CB.swift`
- Create: `Sources/FCBComposable/Models/Characteristic+CB.swift`
- Create: `Sources/FCBComposable/Models/Central+CB.swift`
- Create: `Sources/FCBComposable/Models/MutableService+CB.swift`

Note: these inits are internal because they consume non-Sendable CB types. The clients call them on whatever isolation domain owns the CB object (typically the actor that owns the CB manager).

- [ ] **Step 1: Create the converter files**

`Peripheral+CB.swift`:

```swift
import CoreBluetooth
import Foundation

extension Peripheral {
    init(_ cb: CBPeripheral) {
        self.init(id: cb.identifier, name: cb.name, state: ConnectionState(cb.state))
    }
}

extension ConnectionState {
    init(_ cb: CBPeripheralState) {
        switch cb {
        case .disconnected: self = .disconnected
        case .connecting: self = .connecting
        case .connected: self = .connected
        case .disconnecting: self = .disconnecting
        @unknown default: self = .disconnected
        }
    }
}
```

`Service+CB.swift`:

```swift
import CoreBluetooth
import Foundation

extension Service {
    init(_ cb: CBService) {
        self.init(id: cb.uuid, peripheralID: cb.peripheral?.identifier ?? UUID(), isPrimary: cb.isPrimary)
    }
}
```

`Characteristic+CB.swift`:

```swift
import CoreBluetooth
import Foundation

extension Characteristic {
    init(_ cb: CBCharacteristic) {
        self.init(
            id: cb.uuid,
            serviceID: cb.service?.uuid ?? CBUUID(),
            peripheralID: cb.service?.peripheral?.identifier ?? UUID(),
            properties: cb.properties,
            value: cb.value,
            isNotifying: cb.isNotifying
        )
    }
}
```

`Central+CB.swift`:

```swift
import CoreBluetooth
import Foundation

extension Central {
    init(_ cb: CBCentral) {
        self.init(id: cb.identifier, maximumUpdateValueLength: cb.maximumUpdateValueLength)
    }
}
```

`MutableService+CB.swift`:

```swift
import CoreBluetooth
import Foundation

extension MutableService {
    func toCB() -> CBMutableService {
        let svc = CBMutableService(type: id, primary: isPrimary)
        svc.characteristics = characteristics.map { c in
            CBMutableCharacteristic(type: c.id, properties: c.properties, value: c.value, permissions: c.permissions)
        }
        return svc
    }
}
```

- [ ] **Step 2: Build — confirm compiles**

Run: `swift build`
Expected: succeeds. (No tests for these converters at this stage — they require non-Sendable CB instances which are exercised in the live-actor tests in Phase F.)

- [ ] **Step 3: Commit**

Run: `git add Sources/FCBComposable/Models/Peripheral+CB.swift Sources/FCBComposable/Models/Service+CB.swift Sources/FCBComposable/Models/Characteristic+CB.swift Sources/FCBComposable/Models/Central+CB.swift Sources/FCBComposable/Models/MutableService+CB.swift`
Run: `git commit -m "Add CB-to-value-type converters for FCBComposable models"`

---

## Phase D — Event enums

### Task 11: `CentralEvent`, `PeripheralEvent`, `PeripheralManagerEvent`

**Files:**
- Create: `Sources/FCBComposable/Events/CentralEvent.swift`
- Create: `Sources/FCBComposable/Events/PeripheralEvent.swift`
- Create: `Sources/FCBComposable/Events/PeripheralManagerEvent.swift`

No tests for this task — these are data-only enums with no logic. They are exercised indirectly by the live-actor tests in Phase F.

- [ ] **Step 1: Write `CentralEvent.swift`**

```swift
import CoreBluetooth
import Foundation

public enum CentralEvent: Sendable, Hashable {
    case didUpdateState(CBManagerState)
    case willRestoreState(RestorationState)
    case didDiscover(DiscoveredPeripheral)
    case didConnect(Peripheral)
    case didFailToConnect(Peripheral, BluetoothError)
    case didDisconnect(Peripheral, BluetoothError?)
    case didDisconnectWithTimestamp(Peripheral, timestamp: Date, isReconnecting: Bool, BluetoothError?)
    case connectionEventDidOccur(CBConnectionEvent, Peripheral)
    case didUpdateANCSAuthorization(Peripheral)
}
```

Note: `BluetoothError` is `Equatable`/`Hashable` only when its associated `NSError` is `Hashable` — `NSError` conforms to `Hashable` via `NSObject`. The synthesized conformance is correct.

- [ ] **Step 2: Write `PeripheralEvent.swift`**

```swift
import CoreBluetooth
import Foundation

public enum PeripheralEvent: Sendable, Hashable {
    case didUpdateName(Peripheral)
    case didModifyServices(Peripheral, invalidatedServices: [Service])
    case didReadRSSI(Peripheral, rssi: Int, error: BluetoothError?)
    case didDiscoverServices(Peripheral, error: BluetoothError?)
    case didDiscoverIncludedServices(Peripheral, service: Service, error: BluetoothError?)
    case didDiscoverCharacteristics(Peripheral, service: Service, error: BluetoothError?)
    case didDiscoverDescriptors(Peripheral, characteristic: Characteristic, error: BluetoothError?)
    case didUpdateValue(Peripheral, characteristic: Characteristic, error: BluetoothError?)
    case didWriteValue(Peripheral, characteristic: Characteristic, error: BluetoothError?)
    case didUpdateNotificationState(Peripheral, characteristic: Characteristic, error: BluetoothError?)
    case isReadyToSendWriteWithoutResponse(Peripheral)
}
```

- [ ] **Step 3: Write `PeripheralManagerEvent.swift`**

```swift
import CoreBluetooth
import Foundation

public enum PeripheralManagerEvent: Sendable, Hashable {
    case didUpdateState(CBManagerState)
    case willRestoreState(RestorationState)
    case didStartAdvertising(error: BluetoothError?)
    case didAddService(Service, error: BluetoothError?)
    case didSubscribeToCharacteristic(Central, characteristic: Characteristic)
    case didUnsubscribeFromCharacteristic(Central, characteristic: Characteristic)
    case didReceiveRead(ReadRequest)
    case didReceiveWrite([WriteRequest])
    case isReadyToUpdateSubscribers
}
```

- [ ] **Step 4: Build — confirm compiles**

Run: `swift build`
Expected: succeeds.

- [ ] **Step 5: Commit**

Run: `git add Sources/FCBComposable/Events`
Run: `git commit -m "Add CentralEvent, PeripheralEvent, PeripheralManagerEvent enums"`

---

## Phase E — Internal protocols for testability

### Task 12: `CentralManaging`, `PeripheralConnection`, `PeripheralManaging`

**Files:**
- Create: `Sources/FCBComposable/Internal/CentralManaging.swift`
- Create: `Sources/FCBComposable/Internal/PeripheralConnection.swift`
- Create: `Sources/FCBComposable/Internal/PeripheralManaging.swift`

These are internal protocols that abstract the CB managers and peripherals so the live actor can be tested with hand-rolled fakes. Production conformances live in the same files.

- [ ] **Step 1: Write `CentralManaging.swift`**

```swift
import CoreBluetooth
import Foundation

protocol CentralManaging: AnyObject {
    var state: CBManagerState { get }
    var delegate: CBCentralManagerDelegate? { get set }

    func scanForPeripherals(withServices serviceUUIDs: [CBUUID]?, options: [String: Any]?)
    func stopScan()
    func connect(_ peripheral: CBPeripheral, options: [String: Any]?)
    func cancelPeripheralConnection(_ peripheral: CBPeripheral)
    func retrievePeripherals(withIdentifiers identifiers: [UUID]) -> [CBPeripheral]
    func retrieveConnectedPeripherals(withServices serviceUUIDs: [CBUUID]) -> [CBPeripheral]
}

extension CBCentralManager: CentralManaging {}
```

- [ ] **Step 2: Write `PeripheralConnection.swift`**

```swift
import CoreBluetooth
import Foundation

protocol PeripheralConnection: AnyObject {
    var identifier: UUID { get }
    var name: String? { get }
    var state: CBPeripheralState { get }
    var services: [CBService]? { get }
    var delegate: CBPeripheralDelegate? { get set }

    func discoverServices(_ serviceUUIDs: [CBUUID]?)
    func discoverCharacteristics(_ characteristicUUIDs: [CBUUID]?, for service: CBService)
    func readValue(for characteristic: CBCharacteristic)
    func writeValue(_ data: Data, for characteristic: CBCharacteristic, type: CBCharacteristicWriteType)
    func setNotifyValue(_ enabled: Bool, for characteristic: CBCharacteristic)
}

extension CBPeripheral: PeripheralConnection {}
```

- [ ] **Step 3: Write `PeripheralManaging.swift`**

```swift
import CoreBluetooth
import Foundation

protocol PeripheralManaging: AnyObject {
    var state: CBManagerState { get }
    var isAdvertising: Bool { get }
    var delegate: CBPeripheralManagerDelegate? { get set }

    func add(_ service: CBMutableService)
    func remove(_ service: CBMutableService)
    func removeAllServices()
    func startAdvertising(_ advertisementData: [String: Any]?)
    func stopAdvertising()
    func respond(to request: CBATTRequest, withResult result: CBATTError.Code)
    func updateValue(_ value: Data, for characteristic: CBMutableCharacteristic, onSubscribedCentrals centrals: [CBCentral]?) -> Bool
}

extension CBPeripheralManager: PeripheralManaging {}
```

- [ ] **Step 4: Build — confirm compiles**

Run: `swift build`
Expected: succeeds.

- [ ] **Step 5: Commit**

Run: `git add Sources/FCBComposable/Internal`
Run: `git commit -m "Add CentralManaging, PeripheralConnection, PeripheralManaging internal protocols"`

---

## Phase F — `BluetoothCentralClient`

### Task 13: `BluetoothCentralClient` witness struct

**Files:**
- Create: `Sources/FCBComposable/BluetoothCentralClient.swift`

- [ ] **Step 1: Write the witness struct**

```swift
import ComposableArchitecture
import CoreBluetooth
import Foundation

@DependencyClient
public struct BluetoothCentralClient: Sendable {
    public var state: @Sendable () -> AsyncStream<CBManagerState> = { .never }
    public var authorization: @Sendable () -> CBManagerAuthorization = { .notDetermined }

    public var scan: @Sendable (_ services: [CBUUID]?, _ options: ScanOptions?) -> AsyncStream<DiscoveredPeripheral> = { _, _ in .never }
    public var stopScan: @Sendable () async -> Void

    public var connect: @Sendable (_ id: UUID, _ options: ConnectOptions?) async throws -> Peripheral
    public var disconnect: @Sendable (_ id: UUID) async throws -> Void
    public var retrievePeripherals: @Sendable (_ ids: [UUID]) async -> [Peripheral] = { _ in [] }
    public var retrieveConnected: @Sendable (_ services: [CBUUID]) async -> [Peripheral] = { _ in [] }

    public var discoverServices: @Sendable (_ peripheralID: UUID, _ serviceIDs: [CBUUID]?) async throws -> [Service]
    public var discoverCharacteristics: @Sendable (_ peripheralID: UUID, _ serviceID: CBUUID, _ characteristicIDs: [CBUUID]?) async throws -> [Characteristic]

    public var readValue: @Sendable (_ peripheralID: UUID, _ characteristicID: CBUUID) async throws -> Data
    public var writeValue: @Sendable (_ data: Data, _ peripheralID: UUID, _ characteristicID: CBUUID, _ type: CBCharacteristicWriteType) async throws -> Void
    public var setNotify: @Sendable (_ enabled: Bool, _ peripheralID: UUID, _ characteristicID: CBUUID) async throws -> Void
    public var notifications: @Sendable (_ peripheralID: UUID, _ characteristicID: CBUUID) -> AsyncThrowingStream<Data, any Error> = { _, _ in .finished() }

    public var events: @Sendable () -> AsyncStream<CentralEvent> = { .never }
}

extension BluetoothCentralClient: TestDependencyKey {
    public static let testValue = BluetoothCentralClient()
}

extension DependencyValues {
    public var bluetoothCentralClient: BluetoothCentralClient {
        get { self[BluetoothCentralClient.self] }
        set { self[BluetoothCentralClient.self] = newValue }
    }
}
```

- [ ] **Step 2: Build — confirm compiles**

Run: `swift build`
Expected: succeeds. The `@DependencyClient` macro expands and generates initializers with `unimplemented`-style defaults.

- [ ] **Step 3: Verify `testValue` fails calls to unset closures**

Create `Tests/FCBComposableTests/BluetoothCentralClientTests.swift`:

```swift
import ComposableArchitecture
import CoreBluetooth
import Foundation
import Testing
@testable import FCBComposable

@MainActor
struct BluetoothCentralClientContractTests {
    @Test func testValueDisconnectThrowsUnimplemented() async {
        let client = BluetoothCentralClient.testValue
        await #expect(throws: Error.self) {
            _ = try await client.disconnect(UUID())
        }
    }
}
```

- [ ] **Step 4: Run test — confirm pass**

Run: `swift test --filter BluetoothCentralClientContractTests`
Expected: 1/1 pass. (The test asserts that an unset closure throws when called — TCA's `@DependencyClient` generates `unimplemented` defaults that throw.)

- [ ] **Step 5: Commit**

Run: `git add Sources/FCBComposable/BluetoothCentralClient.swift Tests/FCBComposableTests/BluetoothCentralClientTests.swift`
Run: `git commit -m "Add BluetoothCentralClient witness struct with DependencyKey"`

---

### Task 14: Live actor scaffolding + test fakes

**Files:**
- Create: `Sources/FCBComposable/BluetoothCentralClient+Live.swift`
- Create: `Tests/FCBComposableTests/FakeCentralManager.swift`
- Create: `Tests/FCBComposableTests/FakePeripheralConnection.swift`

This task lays down the actor structure with all methods stubbed (throwing `.poweredOff` so any premature invocation is loud). Subsequent tasks fill in real behavior with tests. No new behavioral tests in this task.

- [ ] **Step 1: Write the live actor scaffold**

Create `Sources/FCBComposable/BluetoothCentralClient+Live.swift`:

```swift
import ComposableArchitecture
import CoreBluetooth
import FCB
import Foundation

extension BluetoothCentralClient: DependencyKey {
    public static let liveValue: BluetoothCentralClient = {
        let actor = CentralActor(manager: CBCentralManager(delegate: nil, queue: nil))
        return makeClient(actor: actor)
    }()

    static func makeClient(actor: CentralActor) -> BluetoothCentralClient {
        BluetoothCentralClient(
            state: { actor.stateStream() },
            authorization: { CBManager.authorization },
            scan: { services, options in actor.scan(services: services, options: options) },
            stopScan: { await actor.stopScan() },
            connect: { id, options in try await actor.connect(id: id, options: options) },
            disconnect: { id in try await actor.disconnect(id: id) },
            retrievePeripherals: { ids in await actor.retrievePeripherals(ids: ids) },
            retrieveConnected: { services in await actor.retrieveConnected(services: services) },
            discoverServices: { pid, sids in try await actor.discoverServices(peripheralID: pid, serviceIDs: sids) },
            discoverCharacteristics: { pid, sid, cids in try await actor.discoverCharacteristics(peripheralID: pid, serviceID: sid, characteristicIDs: cids) },
            readValue: { pid, cid in try await actor.readValue(peripheralID: pid, characteristicID: cid) },
            writeValue: { data, pid, cid, type in try await actor.writeValue(data: data, peripheralID: pid, characteristicID: cid, type: type) },
            setNotify: { enabled, pid, cid in try await actor.setNotify(enabled: enabled, peripheralID: pid, characteristicID: cid) },
            notifications: { pid, cid in actor.notifications(peripheralID: pid, characteristicID: cid) },
            events: { actor.eventStream() }
        )
    }
}

final actor CentralActor {
    private let manager: any CentralManaging
    private let delegate = FCBCentralManagerDelegate()
    private var peripheralDelegate = FCBPeripheralDelegate()

    private var peripherals: [UUID: any PeripheralConnection] = [:]

    // Stream continuations
    private var stateContinuations: [UUID: AsyncStream<CBManagerState>.Continuation] = [:]
    private var eventContinuations: [UUID: AsyncStream<CentralEvent>.Continuation] = [:]
    private var scanContinuation: AsyncStream<DiscoveredPeripheral>.Continuation?
    private var notificationContinuations: [String: AsyncThrowingStream<Data, any Error>.Continuation] = [:]

    // Pending operation continuations
    private var pendingConnect: [UUID: CheckedContinuation<Peripheral, any Error>] = [:]
    private var pendingDisconnect: [UUID: CheckedContinuation<Void, any Error>] = [:]
    private var pendingDiscoverServices: [UUID: CheckedContinuation<[Service], any Error>] = [:]
    private var pendingDiscoverCharacteristics: [String: CheckedContinuation<[Characteristic], any Error>] = [:]
    private var pendingReads: [String: CheckedContinuation<Data, any Error>] = [:]
    private var pendingWrites: [String: CheckedContinuation<Void, any Error>] = [:]
    private var pendingNotify: [String: CheckedContinuation<Void, any Error>] = [:]

    init(manager: any CentralManaging) {
        self.manager = manager
        Task { await self.wireDelegates() }
    }

    private func wireDelegates() {
        manager.delegate = delegate
        delegate.onDidUpdateState = { [weak self] m in
            Task { await self?.handleDidUpdateState(m.state) }
        }
        delegate.onDidDiscover = { [weak self] _, peripheral, ad, rssi in
            Task { await self?.handleDidDiscover(peripheral: peripheral, ad: ad, rssi: rssi) }
        }
        delegate.onDidConnect = { [weak self] _, peripheral in
            Task { await self?.handleDidConnect(peripheral: peripheral) }
        }
        delegate.onDidFailToConnect = { [weak self] _, peripheral, error in
            Task { await self?.handleDidFailToConnect(peripheral: peripheral, error: error) }
        }
        delegate.onDidDisconnect = { [weak self] _, peripheral, error in
            Task { await self?.handleDidDisconnect(peripheral: peripheral, error: error) }
        }
        peripheralDelegate.onDidDiscoverServices = { [weak self] peripheral, error in
            Task { await self?.handleDidDiscoverServices(peripheral: peripheral, error: error) }
        }
        peripheralDelegate.onDidDiscoverCharacteristics = { [weak self] peripheral, service, error in
            Task { await self?.handleDidDiscoverCharacteristics(peripheral: peripheral, service: service, error: error) }
        }
        peripheralDelegate.onDidUpdateValueForCharacteristic = { [weak self] peripheral, char, error in
            Task { await self?.handleDidUpdateValue(peripheral: peripheral, characteristic: char, error: error) }
        }
        peripheralDelegate.onDidWriteValueForCharacteristic = { [weak self] peripheral, char, error in
            Task { await self?.handleDidWriteValue(peripheral: peripheral, characteristic: char, error: error) }
        }
        peripheralDelegate.onDidUpdateNotificationState = { [weak self] peripheral, char, error in
            Task { await self?.handleDidUpdateNotificationState(peripheral: peripheral, characteristic: char, error: error) }
        }
    }

    // MARK: - Public methods (stubs filled in by later tasks)

    nonisolated func stateStream() -> AsyncStream<CBManagerState> { .never }
    nonisolated func eventStream() -> AsyncStream<CentralEvent> { .never }
    nonisolated func scan(services: [CBUUID]?, options: ScanOptions?) -> AsyncStream<DiscoveredPeripheral> { .never }
    nonisolated func notifications(peripheralID: UUID, characteristicID: CBUUID) -> AsyncThrowingStream<Data, any Error> { .finished() }

    func stopScan() async {}
    func connect(id: UUID, options: ConnectOptions?) async throws -> Peripheral { throw BluetoothError.poweredOff }
    func disconnect(id: UUID) async throws { throw BluetoothError.poweredOff }
    func retrievePeripherals(ids: [UUID]) async -> [Peripheral] { [] }
    func retrieveConnected(services: [CBUUID]) async -> [Peripheral] { [] }
    func discoverServices(peripheralID: UUID, serviceIDs: [CBUUID]?) async throws -> [Service] { throw BluetoothError.poweredOff }
    func discoverCharacteristics(peripheralID: UUID, serviceID: CBUUID, characteristicIDs: [CBUUID]?) async throws -> [Characteristic] { throw BluetoothError.poweredOff }
    func readValue(peripheralID: UUID, characteristicID: CBUUID) async throws -> Data { throw BluetoothError.poweredOff }
    func writeValue(data: Data, peripheralID: UUID, characteristicID: CBUUID, type: CBCharacteristicWriteType) async throws { throw BluetoothError.poweredOff }
    func setNotify(enabled: Bool, peripheralID: UUID, characteristicID: CBUUID) async throws { throw BluetoothError.poweredOff }

    // MARK: - Delegate handlers (filled in by later tasks)

    func handleDidUpdateState(_ state: CBManagerState) {}
    func handleDidDiscover(peripheral: CBPeripheral, ad: [String: Any], rssi: NSNumber) {}
    func handleDidConnect(peripheral: CBPeripheral) {}
    func handleDidFailToConnect(peripheral: CBPeripheral, error: (any Error)?) {}
    func handleDidDisconnect(peripheral: CBPeripheral, error: (any Error)?) {}
    func handleDidDiscoverServices(peripheral: CBPeripheral, error: (any Error)?) {}
    func handleDidDiscoverCharacteristics(peripheral: CBPeripheral, service: CBService, error: (any Error)?) {}
    func handleDidUpdateValue(peripheral: CBPeripheral, characteristic: CBCharacteristic, error: (any Error)?) {}
    func handleDidWriteValue(peripheral: CBPeripheral, characteristic: CBCharacteristic, error: (any Error)?) {}
    func handleDidUpdateNotificationState(peripheral: CBPeripheral, characteristic: CBCharacteristic, error: (any Error)?) {}
}
```

Note: `CentralActor` accepts `any CentralManaging` (the internal protocol from Task 12), which lets tests inject a fake. The `wireDelegates` task hops back into the actor isolation via `Task { await self?.handle…() }` — this is the standard pattern for bridging synchronous delegate callbacks into actor-isolated state.

- [ ] **Step 2: Write `FakeCentralManager.swift`**

Create `Tests/FCBComposableTests/FakeCentralManager.swift`:

```swift
import CoreBluetooth
import Foundation
@testable import FCBComposable

final class FakeCentralManager: NSObject, CentralManaging, @unchecked Sendable {
    var state: CBManagerState = .poweredOn
    weak var delegate: CBCentralManagerDelegate?

    private(set) var scanCalls: [(services: [CBUUID]?, options: [String: Any]?)] = []
    private(set) var stopScanCallCount = 0
    private(set) var connectCalls: [(peripheral: CBPeripheral, options: [String: Any]?)] = []
    private(set) var cancelCalls: [CBPeripheral] = []
    var registeredPeripherals: [UUID: CBPeripheral] = [:]

    func scanForPeripherals(withServices serviceUUIDs: [CBUUID]?, options: [String: Any]?) {
        scanCalls.append((serviceUUIDs, options))
    }
    func stopScan() { stopScanCallCount += 1 }
    func connect(_ peripheral: CBPeripheral, options: [String: Any]?) {
        connectCalls.append((peripheral, options))
    }
    func cancelPeripheralConnection(_ peripheral: CBPeripheral) { cancelCalls.append(peripheral) }
    func retrievePeripherals(withIdentifiers identifiers: [UUID]) -> [CBPeripheral] {
        identifiers.compactMap { registeredPeripherals[$0] }
    }
    func retrieveConnectedPeripherals(withServices serviceUUIDs: [CBUUID]) -> [CBPeripheral] { [] }

    // Test driver methods — simulate delegate callbacks
    func simulateDidUpdateState(_ newState: CBManagerState) {
        state = newState
        delegate?.centralManagerDidUpdateState(unsafeBitCast(self, to: CBCentralManager.self))
    }
    func simulateDidConnect(_ peripheral: CBPeripheral) {
        delegate?.centralManager?(unsafeBitCast(self, to: CBCentralManager.self), didConnect: peripheral)
    }
    func simulateDidFailToConnect(_ peripheral: CBPeripheral, error: NSError) {
        delegate?.centralManager?(unsafeBitCast(self, to: CBCentralManager.self), didFailToConnect: peripheral, error: error)
    }
    func simulateDidDisconnect(_ peripheral: CBPeripheral, error: NSError?) {
        delegate?.centralManager?(unsafeBitCast(self, to: CBCentralManager.self), didDisconnectPeripheral: peripheral, error: error)
    }
    func simulateDidDiscover(_ peripheral: CBPeripheral, ad: [String: Any], rssi: NSNumber) {
        delegate?.centralManager?(unsafeBitCast(self, to: CBCentralManager.self), didDiscover: peripheral, advertisementData: ad, rssi: rssi)
    }
}
```

Note: `unsafeBitCast(self, to: CBCentralManager.self)` is the same runtime-trick pattern used in `BLETestStub` — we pass a "CBCentralManager" reference into the delegate methods. The delegate immediately forwards to a closure that doesn't touch the manager, so this is safe.

- [ ] **Step 3: Write `FakePeripheralConnection.swift`**

Create `Tests/FCBComposableTests/FakePeripheralConnection.swift`:

```swift
import CoreBluetooth
import Foundation
@testable import FCBComposable

final class FakePeripheralConnection: NSObject, PeripheralConnection, @unchecked Sendable {
    let identifier: UUID
    var name: String?
    var state: CBPeripheralState = .disconnected
    var services: [CBService]?
    weak var delegate: CBPeripheralDelegate?

    private(set) var discoverServicesCalls: [[CBUUID]?] = []
    private(set) var discoverCharacteristicsCalls: [(uuids: [CBUUID]?, service: CBService)] = []
    private(set) var readCalls: [CBCharacteristic] = []
    private(set) var writeCalls: [(data: Data, characteristic: CBCharacteristic, type: CBCharacteristicWriteType)] = []
    private(set) var notifyCalls: [(enabled: Bool, characteristic: CBCharacteristic)] = []

    init(identifier: UUID = UUID(), name: String? = nil) {
        self.identifier = identifier
        self.name = name
    }

    func discoverServices(_ serviceUUIDs: [CBUUID]?) { discoverServicesCalls.append(serviceUUIDs) }
    func discoverCharacteristics(_ characteristicUUIDs: [CBUUID]?, for service: CBService) {
        discoverCharacteristicsCalls.append((characteristicUUIDs, service))
    }
    func readValue(for characteristic: CBCharacteristic) { readCalls.append(characteristic) }
    func writeValue(_ data: Data, for characteristic: CBCharacteristic, type: CBCharacteristicWriteType) {
        writeCalls.append((data, characteristic, type))
    }
    func setNotifyValue(_ enabled: Bool, for characteristic: CBCharacteristic) {
        notifyCalls.append((enabled, characteristic))
    }

    func simulateDidDiscoverServices(error: NSError? = nil) {
        delegate?.peripheral?(unsafeBitCast(self, to: CBPeripheral.self), didDiscoverServices: error)
    }
    func simulateDidDiscoverCharacteristics(for service: CBService, error: NSError? = nil) {
        delegate?.peripheral?(unsafeBitCast(self, to: CBPeripheral.self), didDiscoverCharacteristicsFor: service, error: error)
    }
    func simulateDidUpdateValue(for characteristic: CBCharacteristic, error: NSError? = nil) {
        delegate?.peripheral?(unsafeBitCast(self, to: CBPeripheral.self), didUpdateValueFor: characteristic, error: error)
    }
    func simulateDidWriteValue(for characteristic: CBCharacteristic, error: NSError? = nil) {
        delegate?.peripheral?(unsafeBitCast(self, to: CBPeripheral.self), didWriteValueFor: characteristic, error: error)
    }
    func simulateDidUpdateNotificationState(for characteristic: CBCharacteristic, error: NSError? = nil) {
        delegate?.peripheral?(unsafeBitCast(self, to: CBPeripheral.self), didUpdateNotificationStateFor: characteristic, error: error)
    }
}
```

- [ ] **Step 4: Build — confirm compiles**

Run: `swift build`
Expected: succeeds.

- [ ] **Step 5: Commit**

Run: `git add Sources/FCBComposable/BluetoothCentralClient+Live.swift Tests/FCBComposableTests/FakeCentralManager.swift Tests/FCBComposableTests/FakePeripheralConnection.swift`
Run: `git commit -m "Add CentralActor scaffolding and test fakes"`

---

### Task 15: Implement scan, state stream, and event stream

**Files:**
- Modify: `Sources/FCBComposable/BluetoothCentralClient+Live.swift`
- Modify: `Tests/FCBComposableTests/BluetoothCentralClientTests.swift`

- [ ] **Step 1: Append the failing tests**

Append inside `Tests/FCBComposableTests/BluetoothCentralClientTests.swift`:

```swift
@MainActor
struct BluetoothCentralClientScanTests {
    @Test func scanStartsScanCallOnManager() async {
        let fake = FakeCentralManager()
        let actor = CentralActor(manager: fake)
        let stream = actor.scan(services: [CBUUID(string: "180F")], options: ScanOptions(allowDuplicates: true))
        var iter = stream.makeAsyncIterator()
        Task { _ = await iter.next() }
        try? await Task.sleep(nanoseconds: 50_000_000)
        #expect(fake.scanCalls.count == 1)
        #expect(fake.scanCalls.first?.services == [CBUUID(string: "180F")])
    }

    @Test func scanYieldsDiscoveredPeripherals() async {
        let fake = FakeCentralManager()
        let actor = CentralActor(manager: fake)
        let stream = actor.scan(services: nil, options: nil)
        var iter = stream.makeAsyncIterator()

        let peripheralID = UUID()
        let peripheral = BLETestStub.peripheral()
        // Wait for scan registration on the actor
        try? await Task.sleep(nanoseconds: 50_000_000)
        fake.simulateDidDiscover(peripheral, ad: [CBAdvertisementDataLocalNameKey: "MyDev"], rssi: NSNumber(value: -50))

        let discovered = await iter.next()
        #expect(discovered?.advertisementData.localName == "MyDev")
        #expect(discovered?.rssi == -50)
        _ = peripheralID  // unused but illustrates intent
    }

    @Test func stopScanCallsStopOnManager() async {
        let fake = FakeCentralManager()
        let actor = CentralActor(manager: fake)
        await actor.stopScan()
        #expect(fake.stopScanCallCount == 1)
    }

    @Test func stateStreamYieldsStateUpdates() async {
        let fake = FakeCentralManager()
        let actor = CentralActor(manager: fake)
        let stream = actor.stateStream()
        var iter = stream.makeAsyncIterator()
        try? await Task.sleep(nanoseconds: 50_000_000)
        fake.simulateDidUpdateState(.poweredOn)
        let next = await iter.next()
        #expect(next == .poweredOn)
    }

    @Test func eventStreamYieldsDidConnect() async {
        let fake = FakeCentralManager()
        let actor = CentralActor(manager: fake)
        let stream = actor.eventStream()
        var iter = stream.makeAsyncIterator()
        try? await Task.sleep(nanoseconds: 50_000_000)
        let peripheral = BLETestStub.peripheral()
        fake.simulateDidConnect(peripheral)
        let event = await iter.next()
        if case .didConnect(let p) = event {
            #expect(p.id == peripheral.identifier)
        } else {
            Issue.record("expected .didConnect, got \(String(describing: event))")
        }
    }
}
```

Note: tests use a 50ms sleep before driving delegate callbacks to let the actor's registration tasks run. This is pragmatic for actor isolation bridging. If flaky on CI, increase the sleep — these are race-tolerant tests, not correctness-sensitive races.

- [ ] **Step 2: Run tests — expect failure**

Run: `swift test --filter BluetoothCentralClientScanTests`
Expected: tests fail — the actor stubs return `.never` streams and no-op `stopScan()`.

- [ ] **Step 3: Implement scan, state stream, event stream in `CentralActor`**

In `Sources/FCBComposable/BluetoothCentralClient+Live.swift`, replace these method bodies inside `CentralActor`:

```swift
    nonisolated func stateStream() -> AsyncStream<CBManagerState> {
        AsyncStream<CBManagerState> { continuation in
            let token = UUID()
            Task { await self.registerStateContinuation(token, continuation: continuation) }
            continuation.onTermination = { _ in
                Task { await self.unregisterStateContinuation(token) }
            }
        }
    }

    nonisolated func eventStream() -> AsyncStream<CentralEvent> {
        AsyncStream<CentralEvent> { continuation in
            let token = UUID()
            Task { await self.registerEventContinuation(token, continuation: continuation) }
            continuation.onTermination = { _ in
                Task { await self.unregisterEventContinuation(token) }
            }
        }
    }

    nonisolated func scan(services: [CBUUID]?, options: ScanOptions?) -> AsyncStream<DiscoveredPeripheral> {
        AsyncStream<DiscoveredPeripheral> { continuation in
            Task { await self.startScan(services: services, options: options, continuation: continuation) }
            continuation.onTermination = { _ in
                Task { await self.endScan() }
            }
        }
    }

    func stopScan() async {
        manager.stopScan()
        scanContinuation?.finish()
        scanContinuation = nil
    }
```

Add these private methods inside `CentralActor`:

```swift
    private func registerStateContinuation(_ token: UUID, continuation: AsyncStream<CBManagerState>.Continuation) {
        stateContinuations[token] = continuation
    }
    private func unregisterStateContinuation(_ token: UUID) {
        stateContinuations.removeValue(forKey: token)
    }
    private func registerEventContinuation(_ token: UUID, continuation: AsyncStream<CentralEvent>.Continuation) {
        eventContinuations[token] = continuation
    }
    private func unregisterEventContinuation(_ token: UUID) {
        eventContinuations.removeValue(forKey: token)
    }
    private func startScan(services: [CBUUID]?, options: ScanOptions?, continuation: AsyncStream<DiscoveredPeripheral>.Continuation) {
        scanContinuation = continuation
        manager.scanForPeripherals(withServices: services, options: options?.dictionary)
    }
    private func endScan() {
        manager.stopScan()
        scanContinuation = nil
    }
    private func emit(_ event: CentralEvent) {
        for cont in eventContinuations.values { cont.yield(event) }
    }
```

Replace the delegate-handler bodies for the methods used here:

```swift
    func handleDidUpdateState(_ state: CBManagerState) {
        for cont in stateContinuations.values { cont.yield(state) }
        emit(.didUpdateState(state))
    }

    func handleDidDiscover(peripheral: CBPeripheral, ad: [String: Any], rssi: NSNumber) {
        let p = Peripheral(peripheral)
        peripherals[p.id] = peripheral
        let discovered = DiscoveredPeripheral(
            peripheral: p,
            advertisementData: AdvertisementData(dictionary: ad),
            rssi: rssi.intValue
        )
        scanContinuation?.yield(discovered)
        emit(.didDiscover(discovered))
    }

    func handleDidConnect(peripheral: CBPeripheral) {
        let p = Peripheral(peripheral)
        peripherals[p.id] = peripheral
        peripheral.delegate = peripheralDelegate
        emit(.didConnect(p))
        if let cont = pendingConnect.removeValue(forKey: p.id) {
            cont.resume(returning: p)
        }
    }
```

- [ ] **Step 4: Run tests — confirm pass**

Run: `swift test --filter BluetoothCentralClientScanTests`
Expected: 5/5 pass.

- [ ] **Step 5: Mutation test**

Apply this batch mutation: in `startScan`, comment out `manager.scanForPeripherals(...)`. In `handleDidDiscover`, comment out `scanContinuation?.yield(discovered)`. In `handleDidConnect`, comment out the `emit(.didConnect(p))` line. In `stopScan`, comment out `manager.stopScan()`.

Run: `swift test --filter BluetoothCentralClientScanTests`
Expected: `scanStartsScanCallOnManager`, `scanYieldsDiscoveredPeripherals`, `stopScanCallsStopOnManager`, and `eventStreamYieldsDidConnect` all fail.

- [ ] **Step 6: Revert, confirm green**

Run: `git checkout -- Sources/FCBComposable/BluetoothCentralClient+Live.swift`
Run: `swift test --filter BluetoothCentralClientScanTests`
Expected: 5/5 pass.

- [ ] **Step 7: Commit**

Run: `git add Sources/FCBComposable/BluetoothCentralClient+Live.swift Tests/FCBComposableTests/BluetoothCentralClientTests.swift`
Run: `git commit -m "Implement scan, state stream, and event stream in CentralActor"`

---

### Task 16: Implement connect, disconnect, retrieve

**Files:**
- Modify: `Sources/FCBComposable/BluetoothCentralClient+Live.swift`
- Modify: `Tests/FCBComposableTests/BluetoothCentralClientTests.swift`

- [ ] **Step 1: Append the failing tests**

Append to `BluetoothCentralClientTests.swift`:

```swift
@MainActor
struct BluetoothCentralClientConnectTests {
    @Test func connectResolvesOnDidConnect() async throws {
        let fake = FakeCentralManager()
        let peripheral = BLETestStub.peripheral()
        fake.registeredPeripherals[peripheral.identifier] = peripheral
        let actor = CentralActor(manager: fake)
        try? await Task.sleep(nanoseconds: 50_000_000)

        let connectTask = Task { try await actor.connect(id: peripheral.identifier, options: nil) }
        try? await Task.sleep(nanoseconds: 50_000_000)
        fake.simulateDidConnect(peripheral)

        let result = try await connectTask.value
        #expect(result.id == peripheral.identifier)
        #expect(fake.connectCalls.count == 1)
    }

    @Test func connectThrowsConnectionFailedOnDidFailToConnect() async {
        let fake = FakeCentralManager()
        let peripheral = BLETestStub.peripheral()
        fake.registeredPeripherals[peripheral.identifier] = peripheral
        let actor = CentralActor(manager: fake)
        try? await Task.sleep(nanoseconds: 50_000_000)

        let task = Task { try await actor.connect(id: peripheral.identifier, options: nil) }
        try? await Task.sleep(nanoseconds: 50_000_000)
        fake.simulateDidFailToConnect(peripheral, error: NSError(domain: "x", code: 1))

        await #expect(throws: BluetoothError.self) {
            _ = try await task.value
        }
    }

    @Test func connectThrowsUnknownPeripheralWhenNotRegistered() async {
        let fake = FakeCentralManager()
        let actor = CentralActor(manager: fake)
        try? await Task.sleep(nanoseconds: 50_000_000)
        await #expect(throws: BluetoothError.self) {
            _ = try await actor.connect(id: UUID(), options: nil)
        }
    }

    @Test func disconnectResolvesOnDidDisconnect() async throws {
        let fake = FakeCentralManager()
        let peripheral = BLETestStub.peripheral()
        fake.registeredPeripherals[peripheral.identifier] = peripheral
        let actor = CentralActor(manager: fake)
        try? await Task.sleep(nanoseconds: 50_000_000)

        // Connect first so the actor knows about this peripheral
        let connectTask = Task { try await actor.connect(id: peripheral.identifier, options: nil) }
        try? await Task.sleep(nanoseconds: 50_000_000)
        fake.simulateDidConnect(peripheral)
        _ = try await connectTask.value

        let disconnectTask = Task { try await actor.disconnect(id: peripheral.identifier) }
        try? await Task.sleep(nanoseconds: 50_000_000)
        fake.simulateDidDisconnect(peripheral, error: nil)
        try await disconnectTask.value
        #expect(fake.cancelCalls.count == 1)
    }
}
```

- [ ] **Step 2: Run tests — expect failure**

Run: `swift test --filter BluetoothCentralClientConnectTests`
Expected: tests fail — `connect`/`disconnect` still throw `.poweredOff`.

- [ ] **Step 3: Implement connect, disconnect, retrieve in the actor**

In `BluetoothCentralClient+Live.swift`, replace these method bodies:

```swift
    func connect(id: UUID, options: ConnectOptions?) async throws -> Peripheral {
        try preflightCheck()
        guard let cb = peripherals[id] ?? lookupPeripheral(id: id) else {
            throw BluetoothError.unknownPeripheral(id)
        }
        return try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Peripheral, any Error>) in
            pendingConnect[id] = cont
            (cb as? CBPeripheral).map { manager.connect($0, options: options?.dictionary) }
        }
    }

    func disconnect(id: UUID) async throws {
        guard let cb = peripherals[id] as? CBPeripheral else {
            throw BluetoothError.unknownPeripheral(id)
        }
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, any Error>) in
            pendingDisconnect[id] = cont
            manager.cancelPeripheralConnection(cb)
        }
    }

    func retrievePeripherals(ids: [UUID]) async -> [Peripheral] {
        let cbs = manager.retrievePeripherals(withIdentifiers: ids)
        for cb in cbs { peripherals[cb.identifier] = cb }
        return cbs.map(Peripheral.init)
    }

    func retrieveConnected(services: [CBUUID]) async -> [Peripheral] {
        let cbs = manager.retrieveConnectedPeripherals(withServices: services)
        for cb in cbs { peripherals[cb.identifier] = cb }
        return cbs.map(Peripheral.init)
    }
```

Replace the relevant delegate handlers:

```swift
    func handleDidConnect(peripheral: CBPeripheral) {
        let p = Peripheral(peripheral)
        peripherals[p.id] = peripheral
        peripheral.delegate = peripheralDelegate
        emit(.didConnect(p))
        if let cont = pendingConnect.removeValue(forKey: p.id) {
            cont.resume(returning: p)
        }
    }

    func handleDidFailToConnect(peripheral: CBPeripheral, error: (any Error)?) {
        let p = Peripheral(peripheral)
        let bluetoothError = BluetoothError.connectionFailed(peripheralID: p.id, underlying: error as NSError?)
        emit(.didFailToConnect(p, bluetoothError))
        if let cont = pendingConnect.removeValue(forKey: p.id) {
            cont.resume(throwing: bluetoothError)
        }
    }

    func handleDidDisconnect(peripheral: CBPeripheral, error: (any Error)?) {
        let p = Peripheral(peripheral)
        let mappedError = error.map { BluetoothError($0) }
        emit(.didDisconnect(p, mappedError))
        if let cont = pendingDisconnect.removeValue(forKey: p.id) {
            cont.resume(returning: ())
        }
    }
```

Add the pre-flight check helper and a lookup helper:

```swift
    private func preflightCheck() throws {
        switch manager.state {
        case .poweredOn: return
        case .poweredOff: throw BluetoothError.poweredOff
        case .unsupported: throw BluetoothError.unsupported
        case .unauthorized: throw BluetoothError.unauthorized(CBManager.authorization)
        case .unknown, .resetting: return  // transient — let the operation proceed and surface real errors
        @unknown default: return
        }
    }

    private func lookupPeripheral(id: UUID) -> (any PeripheralConnection)? {
        let cbs = manager.retrievePeripherals(withIdentifiers: [id])
        if let cb = cbs.first {
            peripherals[id] = cb
            return cb
        }
        return nil
    }
```

- [ ] **Step 4: Run tests — confirm pass**

Run: `swift test --filter BluetoothCentralClientConnectTests`
Expected: 4/4 pass.

- [ ] **Step 5: Mutation test**

Apply this batch mutation: in `connect`, comment out `pendingConnect[id] = cont` (so the continuation never resolves) AND keep the `manager.connect(...)` call so `connectCalls.count == 1` still increments. Replace `handleDidFailToConnect`'s continuation resume line with no-op. Replace `disconnect`'s `manager.cancelPeripheralConnection(cb)` line with no-op.

Run: `swift test --filter BluetoothCentralClientConnectTests`
Expected: `connectResolvesOnDidConnect` hangs (test runner will time out and fail), `connectThrowsConnectionFailedOnDidFailToConnect` hangs/fails, `disconnectResolvesOnDidDisconnect` fails because `cancelCalls.count != 1`.

Note: hangs on test timeout count as failures. If the test runner doesn't time out, manually kill after 30s and treat as failure.

- [ ] **Step 6: Revert, confirm green**

Run: `git checkout -- Sources/FCBComposable/BluetoothCentralClient+Live.swift`
Run: `swift test --filter BluetoothCentralClientConnectTests`
Expected: 4/4 pass.

- [ ] **Step 7: Commit**

Run: `git add Sources/FCBComposable/BluetoothCentralClient+Live.swift Tests/FCBComposableTests/BluetoothCentralClientTests.swift`
Run: `git commit -m "Implement connect, disconnect, retrieve in CentralActor"`

---

### Task 17: Implement discoverServices, discoverCharacteristics

**Files:**
- Modify: `Sources/FCBComposable/BluetoothCentralClient+Live.swift`
- Modify: `Tests/FCBComposableTests/BluetoothCentralClientTests.swift`

- [ ] **Step 1: Append the failing tests**

```swift
@MainActor
struct BluetoothCentralClientDiscoveryTests {
    @Test func discoverServicesThrowsUnknownPeripheral() async {
        let fake = FakeCentralManager()
        let actor = CentralActor(manager: fake)
        try? await Task.sleep(nanoseconds: 50_000_000)
        await #expect(throws: BluetoothError.self) {
            _ = try await actor.discoverServices(peripheralID: UUID(), serviceIDs: nil)
        }
    }

    @Test func discoverServicesResolvesWhenDelegateFires() async throws {
        // For this test we need to inject a fake peripheral into the actor's map.
        // We do so by overriding retrievePeripherals on FakeCentralManager.
        // The actor maintains its peripherals map keyed by UUID via PeripheralConnection.
        // Because CBPeripheral isn't easily extensible, we test the pending-continuation
        // mechanism directly via the actor's internal handle method:
        let fake = FakeCentralManager()
        let actor = CentralActor(manager: fake)
        let pid = UUID()
        let fakeConn = FakePeripheralConnection(identifier: pid)
        await actor.injectPeripheralForTest(id: pid, connection: fakeConn)

        let task = Task { try await actor.discoverServices(peripheralID: pid, serviceIDs: nil) }
        try? await Task.sleep(nanoseconds: 50_000_000)
        #expect(fakeConn.discoverServicesCalls.count == 1)

        // Simulate completion: services empty (real CB conversion would happen here)
        fakeConn.services = []
        await actor.completeDiscoverServicesForTest(peripheralID: pid, services: [])
        let services = try await task.value
        #expect(services.isEmpty)
    }
}
```

Note: this test introduces two testing-only methods on the actor — `injectPeripheralForTest` and `completeDiscoverServicesForTest` — to avoid the complexity of fully mocking `CBPeripheral`. They are `internal` so the `@testable import FCBComposable` can reach them; production code never calls them.

- [ ] **Step 2: Run tests — expect failure**

Run: `swift test --filter BluetoothCentralClientDiscoveryTests`
Expected: cannot find `injectPeripheralForTest` / `completeDiscoverServicesForTest`. Red phase.

- [ ] **Step 3: Implement discovery in the actor**

Replace these method bodies:

```swift
    func discoverServices(peripheralID: UUID, serviceIDs: [CBUUID]?) async throws -> [Service] {
        try preflightCheck()
        guard let connection = peripherals[peripheralID] else {
            throw BluetoothError.unknownPeripheral(peripheralID)
        }
        return try await withCheckedThrowingContinuation { (cont: CheckedContinuation<[Service], any Error>) in
            pendingDiscoverServices[peripheralID] = cont
            connection.discoverServices(serviceIDs)
        }
    }

    func discoverCharacteristics(peripheralID: UUID, serviceID: CBUUID, characteristicIDs: [CBUUID]?) async throws -> [Characteristic] {
        try preflightCheck()
        guard let connection = peripherals[peripheralID] else {
            throw BluetoothError.unknownPeripheral(peripheralID)
        }
        guard let service = connection.services?.first(where: { $0.uuid == serviceID }) else {
            throw BluetoothError.unknownService(serviceID, peripheralID: peripheralID)
        }
        let key = "\(peripheralID.uuidString):\(serviceID.uuidString)"
        return try await withCheckedThrowingContinuation { (cont: CheckedContinuation<[Characteristic], any Error>) in
            pendingDiscoverCharacteristics[key] = cont
            connection.discoverCharacteristics(characteristicIDs, for: service)
        }
    }
```

Replace these handlers. Note: `CentralEvent` has no case for service or characteristic discovery — those are intentionally in `PeripheralEvent`, which the central client surfaces only through its `events` stream as `CentralEvent`. The handlers below just resume pending continuations; no emit.

```swift
    func handleDidDiscoverServices(peripheral: CBPeripheral, error: (any Error)?) {
        let id = peripheral.identifier
        let services = (peripheral.services ?? []).map(Service.init)
        if let cont = pendingDiscoverServices.removeValue(forKey: id) {
            if let error {
                cont.resume(throwing: BluetoothError(error))
            } else {
                cont.resume(returning: services)
            }
        }
    }

    func handleDidDiscoverCharacteristics(peripheral: CBPeripheral, service: CBService, error: (any Error)?) {
        let key = "\(peripheral.identifier.uuidString):\(service.uuid.uuidString)"
        let mapped = (service.characteristics ?? []).map(Characteristic.init)
        if let cont = pendingDiscoverCharacteristics.removeValue(forKey: key) {
            if let error {
                cont.resume(throwing: BluetoothError(error))
            } else {
                cont.resume(returning: mapped)
            }
        }
    }
```

Add the testing-only helpers (gated behind `#if DEBUG` or simply marked `internal`):

```swift
    // Testing helpers — internal access for @testable import. Do not call from production.
    func injectPeripheralForTest(id: UUID, connection: any PeripheralConnection) {
        peripherals[id] = connection
    }

    func completeDiscoverServicesForTest(peripheralID: UUID, services: [Service]) {
        if let cont = pendingDiscoverServices.removeValue(forKey: peripheralID) {
            cont.resume(returning: services)
        }
    }
```

- [ ] **Step 4: Run tests — confirm pass**

Run: `swift test --filter BluetoothCentralClientDiscoveryTests`
Expected: 2/2 pass.

- [ ] **Step 5: Mutation test**

Apply this batch mutation: in `discoverServices`, change `pendingDiscoverServices[peripheralID] = cont` to no-op (delete the line). In `handleDidDiscoverServices`, change `cont.resume(returning: services)` to `cont.resume(returning: [])`.

Run: `swift test --filter BluetoothCentralClientDiscoveryTests`
Expected: `discoverServicesResolvesWhenDelegateFires` fails (either hangs or returns wrong result).

- [ ] **Step 6: Revert, confirm green**

Run: `git checkout -- Sources/FCBComposable/BluetoothCentralClient+Live.swift`
Run: `swift test --filter BluetoothCentralClientDiscoveryTests`
Expected: 2/2 pass.

- [ ] **Step 7: Commit**

Run: `git add Sources/FCBComposable/BluetoothCentralClient+Live.swift Tests/FCBComposableTests/BluetoothCentralClientTests.swift`
Run: `git commit -m "Implement discoverServices and discoverCharacteristics in CentralActor"`

---

### Task 18: Implement readValue, writeValue, setNotify, notifications

**Files:**
- Modify: `Sources/FCBComposable/BluetoothCentralClient+Live.swift`
- Modify: `Tests/FCBComposableTests/BluetoothCentralClientTests.swift`

- [ ] **Step 1: Append the failing tests**

```swift
@MainActor
struct BluetoothCentralClientReadWriteTests {
    @Test func writeValueResolvesWhenDelegateFires() async throws {
        let fake = FakeCentralManager()
        let actor = CentralActor(manager: fake)
        let pid = UUID()
        let cid = CBUUID(string: "2A19")
        let fakeConn = FakePeripheralConnection(identifier: pid)
        await actor.injectPeripheralForTest(id: pid, connection: fakeConn)
        await actor.injectCharacteristicForTest(peripheralID: pid, characteristicID: cid)

        let task = Task { try await actor.writeValue(data: Data([0x01]), peripheralID: pid, characteristicID: cid, type: .withResponse) }
        try? await Task.sleep(nanoseconds: 50_000_000)
        #expect(fakeConn.writeCalls.count == 1)
        await actor.completeWriteForTest(peripheralID: pid, characteristicID: cid, error: nil)
        try await task.value
    }

    @Test func setNotifyResolvesWhenDelegateFires() async throws {
        let fake = FakeCentralManager()
        let actor = CentralActor(manager: fake)
        let pid = UUID()
        let cid = CBUUID(string: "2A19")
        let fakeConn = FakePeripheralConnection(identifier: pid)
        await actor.injectPeripheralForTest(id: pid, connection: fakeConn)
        await actor.injectCharacteristicForTest(peripheralID: pid, characteristicID: cid)

        let task = Task { try await actor.setNotify(enabled: true, peripheralID: pid, characteristicID: cid) }
        try? await Task.sleep(nanoseconds: 50_000_000)
        #expect(fakeConn.notifyCalls.count == 1)
        await actor.completeNotifyForTest(peripheralID: pid, characteristicID: cid, error: nil)
        try await task.value
    }

    @Test func notificationsStreamYieldsValues() async throws {
        let fake = FakeCentralManager()
        let actor = CentralActor(manager: fake)
        let pid = UUID()
        let cid = CBUUID(string: "2A19")
        let fakeConn = FakePeripheralConnection(identifier: pid)
        await actor.injectPeripheralForTest(id: pid, connection: fakeConn)
        await actor.injectCharacteristicForTest(peripheralID: pid, characteristicID: cid)

        let stream = actor.notifications(peripheralID: pid, characteristicID: cid)
        var iter = stream.makeAsyncIterator()
        try? await Task.sleep(nanoseconds: 50_000_000)
        await actor.simulateNotificationValueForTest(peripheralID: pid, characteristicID: cid, data: Data([0xAA]))
        let next = try await iter.next()
        #expect(next == Data([0xAA]))
    }
}
```

- [ ] **Step 2: Run tests — expect failure**

Run: `swift test --filter BluetoothCentralClientReadWriteTests`
Expected: cannot find injected test helpers. Red phase.

- [ ] **Step 3: Implement read/write/notify in the actor**

Replace these method bodies:

```swift
    func readValue(peripheralID: UUID, characteristicID: CBUUID) async throws -> Data {
        try preflightCheck()
        let (connection, characteristic) = try resolve(peripheralID: peripheralID, characteristicID: characteristicID)
        let key = "\(peripheralID.uuidString):\(characteristicID.uuidString)"
        if pendingReads[key] != nil {
            throw BluetoothError.operationCancelled
        }
        return try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Data, any Error>) in
            pendingReads[key] = cont
            connection.readValue(for: characteristic)
        }
    }

    func writeValue(data: Data, peripheralID: UUID, characteristicID: CBUUID, type: CBCharacteristicWriteType) async throws {
        try preflightCheck()
        let (connection, characteristic) = try resolve(peripheralID: peripheralID, characteristicID: characteristicID)
        let key = "\(peripheralID.uuidString):\(characteristicID.uuidString)"
        if type == .withoutResponse {
            connection.writeValue(data, for: characteristic, type: .withoutResponse)
            return
        }
        return try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, any Error>) in
            pendingWrites[key] = cont
            connection.writeValue(data, for: characteristic, type: .withResponse)
        }
    }

    func setNotify(enabled: Bool, peripheralID: UUID, characteristicID: CBUUID) async throws {
        try preflightCheck()
        let (connection, characteristic) = try resolve(peripheralID: peripheralID, characteristicID: characteristicID)
        let key = "\(peripheralID.uuidString):\(characteristicID.uuidString)"
        return try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, any Error>) in
            pendingNotify[key] = cont
            connection.setNotifyValue(enabled, for: characteristic)
        }
    }

    nonisolated func notifications(peripheralID: UUID, characteristicID: CBUUID) -> AsyncThrowingStream<Data, any Error> {
        AsyncThrowingStream<Data, any Error> { continuation in
            let key = "\(peripheralID.uuidString):\(characteristicID.uuidString)"
            Task { await self.registerNotificationContinuation(key: key, continuation: continuation) }
            continuation.onTermination = { _ in
                Task { await self.unregisterNotificationContinuation(key: key) }
            }
        }
    }
```

Replace these handlers:

```swift
    func handleDidUpdateValue(peripheral: CBPeripheral, characteristic: CBCharacteristic, error: (any Error)?) {
        let key = "\(peripheral.identifier.uuidString):\(characteristic.uuid.uuidString)"
        if let cont = pendingReads.removeValue(forKey: key) {
            if let error {
                cont.resume(throwing: BluetoothError(error))
            } else {
                cont.resume(returning: characteristic.value ?? Data())
            }
        }
        if let notifCont = notificationContinuations[key] {
            if let error {
                notifCont.finish(throwing: BluetoothError(error))
            } else if let data = characteristic.value {
                notifCont.yield(data)
            }
        }
    }

    func handleDidWriteValue(peripheral: CBPeripheral, characteristic: CBCharacteristic, error: (any Error)?) {
        let key = "\(peripheral.identifier.uuidString):\(characteristic.uuid.uuidString)"
        if let cont = pendingWrites.removeValue(forKey: key) {
            if let error {
                cont.resume(throwing: BluetoothError(error))
            } else {
                cont.resume(returning: ())
            }
        }
    }

    func handleDidUpdateNotificationState(peripheral: CBPeripheral, characteristic: CBCharacteristic, error: (any Error)?) {
        let key = "\(peripheral.identifier.uuidString):\(characteristic.uuid.uuidString)"
        if let cont = pendingNotify.removeValue(forKey: key) {
            if let error {
                cont.resume(throwing: BluetoothError(error))
            } else {
                cont.resume(returning: ())
            }
        }
    }
```

Add these private helpers and a characteristic map:

```swift
    private var characteristics: [String: CBCharacteristic] = [:]

    private func registerNotificationContinuation(key: String, continuation: AsyncThrowingStream<Data, any Error>.Continuation) {
        notificationContinuations[key] = continuation
    }
    private func unregisterNotificationContinuation(key: String) {
        notificationContinuations.removeValue(forKey: key)
    }

    private func resolve(peripheralID: UUID, characteristicID: CBUUID) throws -> (any PeripheralConnection, CBCharacteristic) {
        guard let connection = peripherals[peripheralID] else {
            throw BluetoothError.unknownPeripheral(peripheralID)
        }
        let key = "\(peripheralID.uuidString):\(characteristicID.uuidString)"
        guard let characteristic = characteristics[key] else {
            throw BluetoothError.unknownCharacteristic(characteristicID, serviceID: CBUUID())
        }
        return (connection, characteristic)
    }
```

Update `handleDidDiscoverCharacteristics` to populate the `characteristics` map:

```swift
    func handleDidDiscoverCharacteristics(peripheral: CBPeripheral, service: CBService, error: (any Error)?) {
        let key = "\(peripheral.identifier.uuidString):\(service.uuid.uuidString)"
        let cbChars = service.characteristics ?? []
        for c in cbChars {
            let charKey = "\(peripheral.identifier.uuidString):\(c.uuid.uuidString)"
            characteristics[charKey] = c
        }
        let mapped = cbChars.map(Characteristic.init)
        if let cont = pendingDiscoverCharacteristics.removeValue(forKey: key) {
            if let error {
                cont.resume(throwing: BluetoothError(error))
            } else {
                cont.resume(returning: mapped)
            }
        }
    }
```

Add testing-only helpers:

```swift
    func injectCharacteristicForTest(peripheralID: UUID, characteristicID: CBUUID) {
        let key = "\(peripheralID.uuidString):\(characteristicID.uuidString)"
        characteristics[key] = unsafeBitCast(class_createInstance(CBCharacteristic.self, 0)!, to: CBCharacteristic.self)
    }

    func completeWriteForTest(peripheralID: UUID, characteristicID: CBUUID, error: (any Error)?) {
        let key = "\(peripheralID.uuidString):\(characteristicID.uuidString)"
        if let cont = pendingWrites.removeValue(forKey: key) {
            if let error { cont.resume(throwing: BluetoothError(error)) }
            else { cont.resume(returning: ()) }
        }
    }

    func completeNotifyForTest(peripheralID: UUID, characteristicID: CBUUID, error: (any Error)?) {
        let key = "\(peripheralID.uuidString):\(characteristicID.uuidString)"
        if let cont = pendingNotify.removeValue(forKey: key) {
            if let error { cont.resume(throwing: BluetoothError(error)) }
            else { cont.resume(returning: ()) }
        }
    }

    func simulateNotificationValueForTest(peripheralID: UUID, characteristicID: CBUUID, data: Data) {
        let key = "\(peripheralID.uuidString):\(characteristicID.uuidString)"
        notificationContinuations[key]?.yield(data)
    }
```

Also add `import ObjectiveC.runtime` at the top of the file if not already present (needed for `class_createInstance`).

- [ ] **Step 4: Run tests — confirm pass**

Run: `swift test --filter BluetoothCentralClientReadWriteTests`
Expected: 3/3 pass.

- [ ] **Step 5: Mutation test**

Apply this batch mutation: in `writeValue`, comment out `connection.writeValue(...)` in the `.withResponse` branch. In `setNotify`, comment out `connection.setNotifyValue(...)`. In `simulateNotificationValueForTest`, change `notificationContinuations[key]?.yield(data)` to no-op.

Run: `swift test --filter BluetoothCentralClientReadWriteTests`
Expected: all 3 tests fail.

- [ ] **Step 6: Revert, confirm green**

Run: `git checkout -- Sources/FCBComposable/BluetoothCentralClient+Live.swift`
Run: `swift test --filter BluetoothCentralClientReadWriteTests`
Expected: 3/3 pass.

- [ ] **Step 7: Commit**

Run: `git add Sources/FCBComposable/BluetoothCentralClient+Live.swift Tests/FCBComposableTests/BluetoothCentralClientTests.swift`
Run: `git commit -m "Implement readValue, writeValue, setNotify, notifications in CentralActor"`

---

### Task 19: `BluetoothCentralClient.previewValue`

**Files:**
- Create: `Sources/FCBComposable/BluetoothCentralClient+Preview.swift`

No new tests — the preview value is for SwiftUI previews and demos. It's a canned mock with deterministic data.

- [ ] **Step 1: Write the preview value**

```swift
import ComposableArchitecture
import CoreBluetooth
import Foundation

extension BluetoothCentralClient {
    public static let previewValue: BluetoothCentralClient = {
        let sampleID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
        let sample = Peripheral(id: sampleID, name: "Preview Device", state: .connected)
        let discovered = DiscoveredPeripheral(
            peripheral: sample,
            advertisementData: AdvertisementData(localName: "Preview Device", isConnectable: true),
            rssi: -55
        )
        return BluetoothCentralClient(
            state: {
                AsyncStream { continuation in
                    continuation.yield(.poweredOn)
                    continuation.finish()
                }
            },
            authorization: { .allowedAlways },
            scan: { _, _ in
                AsyncStream { continuation in
                    continuation.yield(discovered)
                    continuation.finish()
                }
            },
            stopScan: { },
            connect: { _, _ in sample },
            disconnect: { _ in },
            retrievePeripherals: { _ in [sample] },
            retrieveConnected: { _ in [sample] },
            discoverServices: { _, _ in [] },
            discoverCharacteristics: { _, _, _ in [] },
            readValue: { _, _ in Data() },
            writeValue: { _, _, _, _ in },
            setNotify: { _, _, _ in },
            notifications: { _, _ in
                AsyncThrowingStream { continuation in
                    continuation.finish()
                }
            },
            events: {
                AsyncStream { continuation in
                    continuation.yield(.didConnect(sample))
                    continuation.finish()
                }
            }
        )
    }()
}
```

- [ ] **Step 2: Build — confirm compiles**

Run: `swift build`
Expected: succeeds.

- [ ] **Step 3: Commit**

Run: `git add Sources/FCBComposable/BluetoothCentralClient+Preview.swift`
Run: `git commit -m "Add BluetoothCentralClient.previewValue"`

---

## Phase G — `BluetoothPeripheralClient`

### Task 20: Witness struct, live-actor scaffolding, `FakePeripheralManager`

**Files:**
- Create: `Sources/FCBComposable/BluetoothPeripheralClient.swift`
- Create: `Sources/FCBComposable/BluetoothPeripheralClient+Live.swift`
- Create: `Tests/FCBComposableTests/FakePeripheralManager.swift`
- Create: `Tests/FCBComposableTests/BluetoothPeripheralClientTests.swift`

- [ ] **Step 1: Write the witness struct**

Create `Sources/FCBComposable/BluetoothPeripheralClient.swift`:

```swift
import ComposableArchitecture
import CoreBluetooth
import Foundation

@DependencyClient
public struct BluetoothPeripheralClient: Sendable {
    public var state: @Sendable () -> AsyncStream<CBManagerState> = { .never }
    public var authorization: @Sendable () -> CBManagerAuthorization = { .notDetermined }

    public var add: @Sendable (_ service: MutableService) async throws -> Service
    public var remove: @Sendable (_ serviceID: CBUUID) async -> Void
    public var removeAll: @Sendable () async -> Void

    public var startAdvertising: @Sendable (_ data: AdvertisementData?) async throws -> Void
    public var stopAdvertising: @Sendable () async -> Void
    public var isAdvertising: @Sendable () async -> Bool = { false }

    public var respond: @Sendable (_ requestID: UUID, _ result: CBATTError.Code) async -> Void
    public var updateValue: @Sendable (_ data: Data, _ characteristicID: CBUUID, _ centralIDs: [UUID]?) async throws -> Void

    public var readRequests: @Sendable () -> AsyncStream<ReadRequest> = { .never }
    public var writeRequests: @Sendable () -> AsyncStream<[WriteRequest]> = { .never }
    public var subscriptions: @Sendable () -> AsyncStream<SubscriptionEvent> = { .never }

    public var events: @Sendable () -> AsyncStream<PeripheralManagerEvent> = { .never }
}

extension BluetoothPeripheralClient: TestDependencyKey {
    public static let testValue = BluetoothPeripheralClient()
}

extension DependencyValues {
    public var bluetoothPeripheralClient: BluetoothPeripheralClient {
        get { self[BluetoothPeripheralClient.self] }
        set { self[BluetoothPeripheralClient.self] = newValue }
    }
}
```

- [ ] **Step 2: Write the live actor scaffold**

Create `Sources/FCBComposable/BluetoothPeripheralClient+Live.swift`:

```swift
import ComposableArchitecture
import CoreBluetooth
import FCB
import Foundation
import ObjectiveC.runtime

extension BluetoothPeripheralClient: DependencyKey {
    public static let liveValue: BluetoothPeripheralClient = {
        let actor = PeripheralRoleActor(manager: CBPeripheralManager(delegate: nil, queue: nil))
        return makeClient(actor: actor)
    }()

    static func makeClient(actor: PeripheralRoleActor) -> BluetoothPeripheralClient {
        BluetoothPeripheralClient(
            state: { actor.stateStream() },
            authorization: { CBManager.authorization },
            add: { service in try await actor.add(service: service) },
            remove: { id in await actor.remove(serviceID: id) },
            removeAll: { await actor.removeAll() },
            startAdvertising: { data in try await actor.startAdvertising(data: data) },
            stopAdvertising: { await actor.stopAdvertising() },
            isAdvertising: { await actor.isAdvertising() },
            respond: { reqID, result in await actor.respond(requestID: reqID, result: result) },
            updateValue: { data, cid, centralIDs in try await actor.updateValue(data: data, characteristicID: cid, centralIDs: centralIDs) },
            readRequests: { actor.readRequestsStream() },
            writeRequests: { actor.writeRequestsStream() },
            subscriptions: { actor.subscriptionsStream() },
            events: { actor.eventStream() }
        )
    }
}

final actor PeripheralRoleActor {
    private let manager: any PeripheralManaging
    private let delegate = FCBPeripheralManagerDelegate()

    private var services: [CBUUID: CBMutableService] = [:]
    private var characteristics: [CBUUID: CBMutableCharacteristic] = [:]
    private var pendingRequests: [UUID: CBATTRequest] = [:]
    private var centrals: [UUID: CBCentral] = [:]

    private var stateContinuations: [UUID: AsyncStream<CBManagerState>.Continuation] = [:]
    private var eventContinuations: [UUID: AsyncStream<PeripheralManagerEvent>.Continuation] = [:]
    private var readRequestContinuations: [UUID: AsyncStream<ReadRequest>.Continuation] = [:]
    private var writeRequestContinuations: [UUID: AsyncStream<[WriteRequest]>.Continuation] = [:]
    private var subscriptionContinuations: [UUID: AsyncStream<SubscriptionEvent>.Continuation] = [:]

    private var pendingAddService: [CBUUID: CheckedContinuation<Service, any Error>] = [:]
    private var pendingStartAdvertising: CheckedContinuation<Void, any Error>?

    init(manager: any PeripheralManaging) {
        self.manager = manager
        Task { await self.wireDelegate() }
    }

    private func wireDelegate() {
        manager.delegate = delegate
        delegate.onDidUpdateState = { [weak self] m in
            Task { await self?.handleDidUpdateState(m.state) }
        }
        delegate.onDidStartAdvertising = { [weak self] _, error in
            Task { await self?.handleDidStartAdvertising(error: error) }
        }
        delegate.onDidAddService = { [weak self] _, service, error in
            Task { await self?.handleDidAddService(service: service, error: error) }
        }
        delegate.onDidSubscribeToCharacteristic = { [weak self] _, central, char in
            Task { await self?.handleDidSubscribe(central: central, characteristic: char) }
        }
        delegate.onDidUnsubscribeFromCharacteristic = { [weak self] _, central, char in
            Task { await self?.handleDidUnsubscribe(central: central, characteristic: char) }
        }
        delegate.onDidReceiveRead = { [weak self] _, request in
            Task { await self?.handleDidReceiveRead(request: request) }
        }
        delegate.onDidReceiveWrite = { [weak self] _, requests in
            Task { await self?.handleDidReceiveWrite(requests: requests) }
        }
        delegate.onIsReadyToUpdateSubscribers = { [weak self] _ in
            Task { await self?.handleIsReadyToUpdateSubscribers() }
        }
    }

    // MARK: - Stubs (filled in by later tasks)

    nonisolated func stateStream() -> AsyncStream<CBManagerState> { .never }
    nonisolated func eventStream() -> AsyncStream<PeripheralManagerEvent> { .never }
    nonisolated func readRequestsStream() -> AsyncStream<ReadRequest> { .never }
    nonisolated func writeRequestsStream() -> AsyncStream<[WriteRequest]> { .never }
    nonisolated func subscriptionsStream() -> AsyncStream<SubscriptionEvent> { .never }

    func add(service: MutableService) async throws -> Service { throw BluetoothError.poweredOff }
    func remove(serviceID: CBUUID) async {}
    func removeAll() async {}
    func startAdvertising(data: AdvertisementData?) async throws { throw BluetoothError.poweredOff }
    func stopAdvertising() async {}
    func isAdvertising() async -> Bool { false }
    func respond(requestID: UUID, result: CBATTError.Code) async {}
    func updateValue(data: Data, characteristicID: CBUUID, centralIDs: [UUID]?) async throws { throw BluetoothError.poweredOff }

    func handleDidUpdateState(_ state: CBManagerState) {}
    func handleDidStartAdvertising(error: (any Error)?) {}
    func handleDidAddService(service: CBService, error: (any Error)?) {}
    func handleDidSubscribe(central: CBCentral, characteristic: CBCharacteristic) {}
    func handleDidUnsubscribe(central: CBCentral, characteristic: CBCharacteristic) {}
    func handleDidReceiveRead(request: CBATTRequest) {}
    func handleDidReceiveWrite(requests: [CBATTRequest]) {}
    func handleIsReadyToUpdateSubscribers() {}
}
```

- [ ] **Step 3: Write `FakePeripheralManager.swift`**

Create `Tests/FCBComposableTests/FakePeripheralManager.swift`:

```swift
import CoreBluetooth
import Foundation
@testable import FCBComposable

final class FakePeripheralManager: NSObject, PeripheralManaging, @unchecked Sendable {
    var state: CBManagerState = .poweredOn
    var isAdvertising: Bool = false
    weak var delegate: CBPeripheralManagerDelegate?

    private(set) var addedServices: [CBMutableService] = []
    private(set) var removedServices: [CBMutableService] = []
    private(set) var removeAllCount = 0
    private(set) var startAdvertisingCalls: [[String: Any]?] = []
    private(set) var stopAdvertisingCount = 0
    private(set) var respondCalls: [(request: CBATTRequest, code: CBATTError.Code)] = []
    private(set) var updateValueCalls: [(data: Data, characteristic: CBMutableCharacteristic, centrals: [CBCentral]?)] = []

    func add(_ service: CBMutableService) { addedServices.append(service) }
    func remove(_ service: CBMutableService) { removedServices.append(service) }
    func removeAllServices() { removeAllCount += 1 }
    func startAdvertising(_ advertisementData: [String: Any]?) {
        startAdvertisingCalls.append(advertisementData)
        isAdvertising = true
    }
    func stopAdvertising() { stopAdvertisingCount += 1; isAdvertising = false }
    func respond(to request: CBATTRequest, withResult result: CBATTError.Code) {
        respondCalls.append((request, result))
    }
    func updateValue(_ value: Data, for characteristic: CBMutableCharacteristic, onSubscribedCentrals centrals: [CBCentral]?) -> Bool {
        updateValueCalls.append((value, characteristic, centrals))
        return true
    }

    func simulateDidUpdateState(_ newState: CBManagerState) {
        state = newState
        delegate?.peripheralManagerDidUpdateState(unsafeBitCast(self, to: CBPeripheralManager.self))
    }
    func simulateDidStartAdvertising(error: NSError? = nil) {
        delegate?.peripheralManagerDidStartAdvertising?(unsafeBitCast(self, to: CBPeripheralManager.self), error: error)
    }
    func simulateDidAddService(_ service: CBService, error: NSError? = nil) {
        delegate?.peripheralManager?(unsafeBitCast(self, to: CBPeripheralManager.self), didAdd: service, error: error)
    }
    func simulateDidReceiveRead(_ request: CBATTRequest) {
        delegate?.peripheralManager?(unsafeBitCast(self, to: CBPeripheralManager.self), didReceiveRead: request)
    }
    func simulateDidReceiveWrite(_ requests: [CBATTRequest]) {
        delegate?.peripheralManager?(unsafeBitCast(self, to: CBPeripheralManager.self), didReceiveWrite: requests)
    }
    func simulateDidSubscribe(central: CBCentral, characteristic: CBCharacteristic) {
        delegate?.peripheralManager?(unsafeBitCast(self, to: CBPeripheralManager.self), central: central, didSubscribeTo: characteristic)
    }
}
```

- [ ] **Step 4: Write the testValue contract test**

Create `Tests/FCBComposableTests/BluetoothPeripheralClientTests.swift`:

```swift
import ComposableArchitecture
import CoreBluetooth
import Foundation
import Testing
@testable import FCBComposable

@MainActor
struct BluetoothPeripheralClientContractTests {
    @Test func testValueRespondIsUnimplemented() async {
        let client = BluetoothPeripheralClient.testValue
        // respond is non-throwing in the witness — it just records nothing.
        // To verify the witness exists and the testValue compiles, call it:
        await client.respond(UUID(), .success)
    }
}
```

- [ ] **Step 5: Build + run tests**

Run: `swift build`
Expected: succeeds.

Run: `swift test --filter BluetoothPeripheralClientContractTests`
Expected: 1/1 pass.

- [ ] **Step 6: Commit**

Run: `git add Sources/FCBComposable/BluetoothPeripheralClient.swift Sources/FCBComposable/BluetoothPeripheralClient+Live.swift Tests/FCBComposableTests/FakePeripheralManager.swift Tests/FCBComposableTests/BluetoothPeripheralClientTests.swift`
Run: `git commit -m "Add BluetoothPeripheralClient witness, actor scaffold, fakes"`

---

### Task 21: State stream, event stream, add/remove services

**Files:**
- Modify: `Sources/FCBComposable/BluetoothPeripheralClient+Live.swift`
- Modify: `Tests/FCBComposableTests/BluetoothPeripheralClientTests.swift`

- [ ] **Step 1: Append the failing tests**

```swift
@MainActor
struct BluetoothPeripheralClientServicesTests {
    @Test func stateStreamYieldsStateUpdates() async {
        let fake = FakePeripheralManager()
        let actor = PeripheralRoleActor(manager: fake)
        let stream = actor.stateStream()
        var iter = stream.makeAsyncIterator()
        try? await Task.sleep(nanoseconds: 50_000_000)
        fake.simulateDidUpdateState(.poweredOn)
        let next = await iter.next()
        #expect(next == .poweredOn)
    }

    @Test func addServiceResolvesWhenDelegateFires() async throws {
        let fake = FakePeripheralManager()
        let actor = PeripheralRoleActor(manager: fake)
        try? await Task.sleep(nanoseconds: 50_000_000)
        let mutable = MutableService(id: CBUUID(string: "180F"), isPrimary: true, characteristics: [])

        let task = Task { try await actor.add(service: mutable) }
        try? await Task.sleep(nanoseconds: 50_000_000)
        #expect(fake.addedServices.count == 1)

        let cbService = fake.addedServices[0]
        fake.simulateDidAddService(cbService, error: nil)
        let result = try await task.value
        #expect(result.id == CBUUID(string: "180F"))
    }

    @Test func removeServiceCallsManager() async {
        let fake = FakePeripheralManager()
        let actor = PeripheralRoleActor(manager: fake)
        try? await Task.sleep(nanoseconds: 50_000_000)
        // Inject a known service in the actor's map
        let cbService = CBMutableService(type: CBUUID(string: "180F"), primary: true)
        await actor.injectServiceForTest(id: CBUUID(string: "180F"), service: cbService)

        await actor.remove(serviceID: CBUUID(string: "180F"))
        #expect(fake.removedServices.count == 1)
    }

    @Test func removeAllCallsManager() async {
        let fake = FakePeripheralManager()
        let actor = PeripheralRoleActor(manager: fake)
        try? await Task.sleep(nanoseconds: 50_000_000)
        await actor.removeAll()
        #expect(fake.removeAllCount == 1)
    }
}
```

- [ ] **Step 2: Run tests — expect failure**

Run: `swift test --filter BluetoothPeripheralClientServicesTests`
Expected: fail — actor stubs do nothing.

- [ ] **Step 3: Implement state stream, event stream, and services**

In `BluetoothPeripheralClient+Live.swift`, replace these method bodies:

```swift
    nonisolated func stateStream() -> AsyncStream<CBManagerState> {
        AsyncStream<CBManagerState> { continuation in
            let token = UUID()
            Task { await self.registerStateContinuation(token, continuation: continuation) }
            continuation.onTermination = { _ in Task { await self.unregisterStateContinuation(token) } }
        }
    }

    nonisolated func eventStream() -> AsyncStream<PeripheralManagerEvent> {
        AsyncStream<PeripheralManagerEvent> { continuation in
            let token = UUID()
            Task { await self.registerEventContinuation(token, continuation: continuation) }
            continuation.onTermination = { _ in Task { await self.unregisterEventContinuation(token) } }
        }
    }

    func add(service: MutableService) async throws -> Service {
        try preflightCheck()
        let cb = service.toCB()
        services[service.id] = cb
        for char in cb.characteristics ?? [] {
            if let mc = char as? CBMutableCharacteristic {
                characteristics[char.uuid] = mc
            }
        }
        return try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Service, any Error>) in
            pendingAddService[service.id] = cont
            manager.add(cb)
        }
    }

    func remove(serviceID: CBUUID) async {
        guard let cb = services.removeValue(forKey: serviceID) else { return }
        manager.remove(cb)
    }

    func removeAll() async {
        services.removeAll()
        characteristics.removeAll()
        manager.removeAllServices()
    }
```

Add the private continuation-register helpers and pre-flight check (mirrors the pattern from `CentralActor`):

```swift
    private func registerStateContinuation(_ token: UUID, continuation: AsyncStream<CBManagerState>.Continuation) {
        stateContinuations[token] = continuation
    }
    private func unregisterStateContinuation(_ token: UUID) {
        stateContinuations.removeValue(forKey: token)
    }
    private func registerEventContinuation(_ token: UUID, continuation: AsyncStream<PeripheralManagerEvent>.Continuation) {
        eventContinuations[token] = continuation
    }
    private func unregisterEventContinuation(_ token: UUID) {
        eventContinuations.removeValue(forKey: token)
    }
    private func emit(_ event: PeripheralManagerEvent) {
        for cont in eventContinuations.values { cont.yield(event) }
    }
    private func preflightCheck() throws {
        switch manager.state {
        case .poweredOn: return
        case .poweredOff: throw BluetoothError.poweredOff
        case .unsupported: throw BluetoothError.unsupported
        case .unauthorized: throw BluetoothError.unauthorized(CBManager.authorization)
        case .unknown, .resetting: return
        @unknown default: return
        }
    }
```

Replace these handlers:

```swift
    func handleDidUpdateState(_ state: CBManagerState) {
        for cont in stateContinuations.values { cont.yield(state) }
        emit(.didUpdateState(state))
    }

    func handleDidAddService(service: CBService, error: (any Error)?) {
        let mapped = Service(service)
        let mappedError = error.map { BluetoothError($0) }
        emit(.didAddService(mapped, error: mappedError))
        if let cont = pendingAddService.removeValue(forKey: service.uuid) {
            if let err = mappedError {
                cont.resume(throwing: err)
            } else {
                cont.resume(returning: mapped)
            }
        }
    }
```

Add the testing-only injector:

```swift
    func injectServiceForTest(id: CBUUID, service: CBMutableService) {
        services[id] = service
    }
```

- [ ] **Step 4: Run tests — confirm pass**

Run: `swift test --filter BluetoothPeripheralClientServicesTests`
Expected: 4/4 pass.

- [ ] **Step 5: Mutation test**

Apply this batch mutation: in `add(service:)`, comment out `manager.add(cb)`. In `remove(serviceID:)`, comment out `manager.remove(cb)`. In `removeAll()`, comment out `manager.removeAllServices()`. In `handleDidUpdateState`, comment out the `cont.yield(state)` line in the for-loop.

Run: `swift test --filter BluetoothPeripheralClientServicesTests`
Expected: all 4 tests fail.

- [ ] **Step 6: Revert, confirm green**

Run: `git checkout -- Sources/FCBComposable/BluetoothPeripheralClient+Live.swift`
Run: `swift test --filter BluetoothPeripheralClientServicesTests`
Expected: 4/4 pass.

- [ ] **Step 7: Commit**

Run: `git add Sources/FCBComposable/BluetoothPeripheralClient+Live.swift Tests/FCBComposableTests/BluetoothPeripheralClientTests.swift`
Run: `git commit -m "Implement state stream, event stream, add/remove services in PeripheralRoleActor"`

---

### Task 22: Start/stop advertising

**Files:**
- Modify: `Sources/FCBComposable/BluetoothPeripheralClient+Live.swift`
- Modify: `Tests/FCBComposableTests/BluetoothPeripheralClientTests.swift`

- [ ] **Step 1: Append failing tests**

```swift
@MainActor
struct BluetoothPeripheralClientAdvertisingTests {
    @Test func startAdvertisingResolvesWhenDelegateFires() async throws {
        let fake = FakePeripheralManager()
        let actor = PeripheralRoleActor(manager: fake)
        try? await Task.sleep(nanoseconds: 50_000_000)
        let ad = AdvertisementData(localName: "Me")

        let task = Task { try await actor.startAdvertising(data: ad) }
        try? await Task.sleep(nanoseconds: 50_000_000)
        #expect(fake.startAdvertisingCalls.count == 1)

        fake.simulateDidStartAdvertising(error: nil)
        try await task.value
    }

    @Test func stopAdvertisingCallsManager() async {
        let fake = FakePeripheralManager()
        let actor = PeripheralRoleActor(manager: fake)
        try? await Task.sleep(nanoseconds: 50_000_000)
        await actor.stopAdvertising()
        #expect(fake.stopAdvertisingCount == 1)
    }

    @Test func isAdvertisingReflectsManagerState() async {
        let fake = FakePeripheralManager()
        fake.isAdvertising = true
        let actor = PeripheralRoleActor(manager: fake)
        try? await Task.sleep(nanoseconds: 50_000_000)
        let advertising = await actor.isAdvertising()
        #expect(advertising == true)
    }
}
```

- [ ] **Step 2: Run tests — expect failure**

Run: `swift test --filter BluetoothPeripheralClientAdvertisingTests`
Expected: fail — stubs throw `.poweredOff` or return `false`.

- [ ] **Step 3: Implement advertising**

Replace these method bodies:

```swift
    func startAdvertising(data: AdvertisementData?) async throws {
        try preflightCheck()
        let dict = advertisementDictionary(from: data)
        return try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, any Error>) in
            pendingStartAdvertising = cont
            manager.startAdvertising(dict)
        }
    }

    func stopAdvertising() async {
        manager.stopAdvertising()
    }

    func isAdvertising() async -> Bool {
        manager.isAdvertising
    }
```

Replace this handler:

```swift
    func handleDidStartAdvertising(error: (any Error)?) {
        let mappedError = error.map { BluetoothError($0) }
        emit(.didStartAdvertising(error: mappedError))
        if let cont = pendingStartAdvertising {
            pendingStartAdvertising = nil
            if let err = mappedError {
                cont.resume(throwing: err)
            } else {
                cont.resume(returning: ())
            }
        }
    }
```

Add the dictionary helper:

```swift
    private func advertisementDictionary(from data: AdvertisementData?) -> [String: Any]? {
        guard let data else { return nil }
        var dict: [String: Any] = [:]
        if let localName = data.localName { dict[CBAdvertisementDataLocalNameKey] = localName }
        if !data.serviceUUIDs.isEmpty { dict[CBAdvertisementDataServiceUUIDsKey] = data.serviceUUIDs }
        return dict
    }
```

- [ ] **Step 4: Run tests — confirm pass**

Run: `swift test --filter BluetoothPeripheralClientAdvertisingTests`
Expected: 3/3 pass.

- [ ] **Step 5: Mutation test**

Apply this batch mutation: in `startAdvertising`, comment out `manager.startAdvertising(dict)`. In `stopAdvertising`, comment out `manager.stopAdvertising()`. In `isAdvertising`, change to `return false`.

Run: `swift test --filter BluetoothPeripheralClientAdvertisingTests`
Expected: all 3 tests fail.

- [ ] **Step 6: Revert, confirm green**

Run: `git checkout -- Sources/FCBComposable/BluetoothPeripheralClient+Live.swift`
Run: `swift test --filter BluetoothPeripheralClientAdvertisingTests`
Expected: 3/3 pass.

- [ ] **Step 7: Commit**

Run: `git add Sources/FCBComposable/BluetoothPeripheralClient+Live.swift Tests/FCBComposableTests/BluetoothPeripheralClientTests.swift`
Run: `git commit -m "Implement start/stop advertising and isAdvertising"`

---

### Task 23: Requests, responses, value updates, subscription streams

**Files:**
- Modify: `Sources/FCBComposable/BluetoothPeripheralClient+Live.swift`
- Modify: `Tests/FCBComposableTests/BluetoothPeripheralClientTests.swift`

- [ ] **Step 1: Append failing tests**

```swift
@MainActor
struct BluetoothPeripheralClientRequestsTests {
    @Test func readRequestsStreamYieldsRequests() async {
        let fake = FakePeripheralManager()
        let actor = PeripheralRoleActor(manager: fake)
        let stream = actor.readRequestsStream()
        var iter = stream.makeAsyncIterator()
        try? await Task.sleep(nanoseconds: 50_000_000)
        let cbReq = BLETestStub.attRequest()
        fake.simulateDidReceiveRead(cbReq)
        let next = await iter.next()
        #expect(next != nil)
    }

    @Test func writeRequestsStreamYieldsBatches() async {
        let fake = FakePeripheralManager()
        let actor = PeripheralRoleActor(manager: fake)
        let stream = actor.writeRequestsStream()
        var iter = stream.makeAsyncIterator()
        try? await Task.sleep(nanoseconds: 50_000_000)
        fake.simulateDidReceiveWrite([BLETestStub.attRequest(), BLETestStub.attRequest()])
        let next = await iter.next()
        #expect(next?.count == 2)
    }

    @Test func respondLookupCallsManager() async {
        let fake = FakePeripheralManager()
        let actor = PeripheralRoleActor(manager: fake)
        try? await Task.sleep(nanoseconds: 50_000_000)
        let cbReq = BLETestStub.attRequest()
        let id = UUID()
        await actor.injectRequestForTest(id: id, request: cbReq)
        await actor.respond(requestID: id, result: .success)
        #expect(fake.respondCalls.count == 1)
    }

    @Test func subscriptionStreamYieldsSubscribeEvent() async {
        let fake = FakePeripheralManager()
        let actor = PeripheralRoleActor(manager: fake)
        let stream = actor.subscriptionsStream()
        var iter = stream.makeAsyncIterator()
        try? await Task.sleep(nanoseconds: 50_000_000)
        fake.simulateDidSubscribe(central: BLETestStub.central(), characteristic: BLETestStub.characteristic())
        let event = await iter.next()
        if case .subscribed = event {
            // pass
        } else {
            Issue.record("expected .subscribed, got \(String(describing: event))")
        }
    }
}
```

- [ ] **Step 2: Run tests — expect failure**

Run: `swift test --filter BluetoothPeripheralClientRequestsTests`
Expected: fail — stream methods return `.never`; `respond` is no-op; `injectRequestForTest` doesn't exist.

- [ ] **Step 3: Implement requests, responses, subscriptions**

Replace these method bodies and add register helpers:

```swift
    nonisolated func readRequestsStream() -> AsyncStream<ReadRequest> {
        AsyncStream<ReadRequest> { continuation in
            let token = UUID()
            Task { await self.registerReadRequestContinuation(token, continuation: continuation) }
            continuation.onTermination = { _ in Task { await self.unregisterReadRequestContinuation(token) } }
        }
    }

    nonisolated func writeRequestsStream() -> AsyncStream<[WriteRequest]> {
        AsyncStream<[WriteRequest]> { continuation in
            let token = UUID()
            Task { await self.registerWriteRequestContinuation(token, continuation: continuation) }
            continuation.onTermination = { _ in Task { await self.unregisterWriteRequestContinuation(token) } }
        }
    }

    nonisolated func subscriptionsStream() -> AsyncStream<SubscriptionEvent> {
        AsyncStream<SubscriptionEvent> { continuation in
            let token = UUID()
            Task { await self.registerSubscriptionContinuation(token, continuation: continuation) }
            continuation.onTermination = { _ in Task { await self.unregisterSubscriptionContinuation(token) } }
        }
    }

    func respond(requestID: UUID, result: CBATTError.Code) async {
        guard let cbReq = pendingRequests.removeValue(forKey: requestID) else { return }
        manager.respond(to: cbReq, withResult: result)
    }

    func updateValue(data: Data, characteristicID: CBUUID, centralIDs: [UUID]?) async throws {
        try preflightCheck()
        guard let char = characteristics[characteristicID] else {
            throw BluetoothError.unknownCharacteristic(characteristicID, serviceID: CBUUID())
        }
        let cbCentrals = centralIDs?.compactMap { centrals[$0] }
        _ = manager.updateValue(data, for: char, onSubscribedCentrals: cbCentrals)
    }
```

Add the register helpers:

```swift
    private func registerReadRequestContinuation(_ token: UUID, continuation: AsyncStream<ReadRequest>.Continuation) {
        readRequestContinuations[token] = continuation
    }
    private func unregisterReadRequestContinuation(_ token: UUID) {
        readRequestContinuations.removeValue(forKey: token)
    }
    private func registerWriteRequestContinuation(_ token: UUID, continuation: AsyncStream<[WriteRequest]>.Continuation) {
        writeRequestContinuations[token] = continuation
    }
    private func unregisterWriteRequestContinuation(_ token: UUID) {
        writeRequestContinuations.removeValue(forKey: token)
    }
    private func registerSubscriptionContinuation(_ token: UUID, continuation: AsyncStream<SubscriptionEvent>.Continuation) {
        subscriptionContinuations[token] = continuation
    }
    private func unregisterSubscriptionContinuation(_ token: UUID) {
        subscriptionContinuations.removeValue(forKey: token)
    }
```

Replace these handlers:

```swift
    func handleDidReceiveRead(request: CBATTRequest) {
        let id = UUID()
        pendingRequests[id] = request
        let mapped = ReadRequest(
            id: id,
            central: Central(request.central),
            characteristic: Characteristic(request.characteristic),
            offset: request.offset
        )
        for cont in readRequestContinuations.values { cont.yield(mapped) }
        emit(.didReceiveRead(mapped))
    }

    func handleDidReceiveWrite(requests: [CBATTRequest]) {
        let mapped: [WriteRequest] = requests.map { req in
            let id = UUID()
            pendingRequests[id] = req
            return WriteRequest(
                id: id,
                central: Central(req.central),
                characteristic: Characteristic(req.characteristic),
                offset: req.offset,
                value: req.value
            )
        }
        for cont in writeRequestContinuations.values { cont.yield(mapped) }
        emit(.didReceiveWrite(mapped))
    }

    func handleDidSubscribe(central: CBCentral, characteristic: CBCharacteristic) {
        let c = Central(central)
        let ch = Characteristic(characteristic)
        centrals[c.id] = central
        let event = SubscriptionEvent.subscribed(central: c, characteristic: ch)
        for cont in subscriptionContinuations.values { cont.yield(event) }
        emit(.didSubscribeToCharacteristic(c, characteristic: ch))
    }

    func handleDidUnsubscribe(central: CBCentral, characteristic: CBCharacteristic) {
        let c = Central(central)
        let ch = Characteristic(characteristic)
        let event = SubscriptionEvent.unsubscribed(central: c, characteristic: ch)
        for cont in subscriptionContinuations.values { cont.yield(event) }
        emit(.didUnsubscribeFromCharacteristic(c, characteristic: ch))
    }

    func handleIsReadyToUpdateSubscribers() {
        emit(.isReadyToUpdateSubscribers)
    }
```

Add testing-only injector:

```swift
    func injectRequestForTest(id: UUID, request: CBATTRequest) {
        pendingRequests[id] = request
    }
```

- [ ] **Step 4: Run tests — confirm pass**

Run: `swift test --filter BluetoothPeripheralClientRequestsTests`
Expected: 4/4 pass.

- [ ] **Step 5: Mutation test**

Apply this batch mutation: in `handleDidReceiveRead`, comment out the for-loop that yields to read continuations. In `handleDidReceiveWrite`, comment out the for-loop that yields to write continuations. In `respond`, comment out `manager.respond(...)`. In `handleDidSubscribe`, comment out the for-loop that yields to subscription continuations.

Run: `swift test --filter BluetoothPeripheralClientRequestsTests`
Expected: all 4 tests fail.

- [ ] **Step 6: Revert, confirm green**

Run: `git checkout -- Sources/FCBComposable/BluetoothPeripheralClient+Live.swift`
Run: `swift test --filter BluetoothPeripheralClientRequestsTests`
Expected: 4/4 pass.

- [ ] **Step 7: Commit**

Run: `git add Sources/FCBComposable/BluetoothPeripheralClient+Live.swift Tests/FCBComposableTests/BluetoothPeripheralClientTests.swift`
Run: `git commit -m "Implement request, response, subscription handling in PeripheralRoleActor"`

---

### Task 24: `BluetoothPeripheralClient.previewValue`

**Files:**
- Create: `Sources/FCBComposable/BluetoothPeripheralClient+Preview.swift`

- [ ] **Step 1: Write the preview value**

```swift
import ComposableArchitecture
import CoreBluetooth
import Foundation

extension BluetoothPeripheralClient {
    public static let previewValue: BluetoothPeripheralClient = {
        let sampleServiceID = CBUUID(string: "180F")
        let sampleService = Service(id: sampleServiceID,
                                    peripheralID: UUID(),
                                    isPrimary: true)
        return BluetoothPeripheralClient(
            state: {
                AsyncStream { continuation in
                    continuation.yield(.poweredOn)
                    continuation.finish()
                }
            },
            authorization: { .allowedAlways },
            add: { _ in sampleService },
            remove: { _ in },
            removeAll: { },
            startAdvertising: { _ in },
            stopAdvertising: { },
            isAdvertising: { true },
            respond: { _, _ in },
            updateValue: { _, _, _ in },
            readRequests: { AsyncStream { $0.finish() } },
            writeRequests: { AsyncStream { $0.finish() } },
            subscriptions: { AsyncStream { $0.finish() } },
            events: {
                AsyncStream { continuation in
                    continuation.yield(.didStartAdvertising(error: nil))
                    continuation.finish()
                }
            }
        )
    }()
}
```

- [ ] **Step 2: Build — confirm compiles**

Run: `swift build`
Expected: succeeds.

- [ ] **Step 3: Run full test suite — sanity check**

Run: `swift test`
Expected: every test passes.

- [ ] **Step 4: Commit**

Run: `git add Sources/FCBComposable/BluetoothPeripheralClient+Preview.swift`
Run: `git commit -m "Add BluetoothPeripheralClient.previewValue"`

---

## Phase H — Wrap-up

### Task 25: Update `CLAUDE.md` to reflect the new architecture

**Files:**
- Modify: `CLAUDE.md` (full rewrite)

- [ ] **Step 1: Rewrite `CLAUDE.md`**

```markdown
# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build & Test

Swift Package (`swift-tools-version: 6.3`, Swift 6 strict concurrency, iOS 17+). Tests use the Swift Testing framework (`import Testing`, `@Test`, `#expect`), not XCTest.

- Build: `swift build`
- Run all tests: `swift test`
- Run a single test type: `swift test --filter FCBCentralManagerDelegateTests`
- Clean: `swift package clean`

## Two-tier architecture

The package ships two products. Consumers depend on whichever fits.

### `FCB` (Layer 1, no external dependencies)

Closure-based wrappers around the three CoreBluetooth delegates:

- `FCBCentralManagerDelegate` — wraps `CBCentralManagerDelegate`.
- `FCBPeripheralDelegate` — wraps `CBPeripheralDelegate`.
- `FCBPeripheralManagerDelegate` — wraps `CBPeripheralManagerDelegate`.

Every callback is exposed as an optional `@Sendable` closure. Subclassable via `open`.

### `FCBComposable` (Layer 2, depends on `FCB` + swift-composable-architecture)

TCA `@DependencyClient` clients backed by internal `actor`s:

- `BluetoothCentralClient` — `scan`, `connect`, `discoverServices`, `discoverCharacteristics`, `readValue`, `writeValue`, `setNotify`, `notifications`, plus an escape-hatch `events` stream emitting `CentralEvent`.
- `BluetoothPeripheralClient` — `add`/`remove` services, `startAdvertising`/`stopAdvertising`, `respond`, `updateValue`, plus streams for read/write requests, subscriptions, and a unified `events` stream emitting `PeripheralManagerEvent`.

Sendable value types (`Peripheral`, `Service`, `Characteristic`, `Central`, `DiscoveredPeripheral`, `AdvertisementData`, `ReadRequest`, `WriteRequest`, etc.) wrap every non-Sendable CoreBluetooth type. `BluetoothError` classifies CoreBluetooth errors by domain/code (`CBErrorDomain`, `CBATTErrorDomain`) with an `.underlying(NSError)` catch-all.

Each client provides `liveValue`, `testValue` (macro-generated, throws on call), and `previewValue` (canned mock for SwiftUI previews).

## Conventions

- All Layer 2 streams are constructed as `AsyncStream { continuation in Task { await actor.register(continuation) } }` — the closure that builds the stream is `nonisolated` and hops into the actor to register the continuation. The same pattern is used for termination cleanup.
- Pending async-throws operations (e.g., `connect`, `discoverServices`) use per-operation `CheckedContinuation` maps inside the actor, keyed by `UUID` or `"\(peripheralUUID):\(characteristicUUID)"` strings. Delegate callbacks resume the matching continuation.
- The actor depends on `CentralManaging` / `PeripheralManaging` / `PeripheralConnection` internal protocols (`Sources/FCBComposable/Internal/`). Production uses CB types directly; tests inject fakes.
- CoreBluetooth instances that have no public init (`CBPeripheral`, `CBService`, `CBCharacteristic`, etc.) are stubbed in tests via `class_createInstance` from the Objective-C runtime. Helpers live in `Tests/FCBTests/BLETestStub.swift`.

## Origin

Extracted and modernized from `../fuikit/fuikit/Classes/FCB/` (December 2020 code). The original `FCBPeripheralManager` (a `CBPeripheralManager` subclass that hooked outgoing methods) was intentionally dropped — the closure pattern lives at the delegate layer only. The original was also missing a `CBPeripheralDelegate` wrapper; this package adds one.
```

- [ ] **Step 2: Commit**

Run: `git add CLAUDE.md`
Run: `git commit -m "Update CLAUDE.md for two-tier FCB / FCBComposable architecture"`

---

## Done

Run a final sanity check:

- [ ] Run: `swift test`
- [ ] Expected: every test passes, no compiler warnings.
- [ ] Run: `git log --oneline`
- [ ] Expected: ~25 commits since the design spec, in roughly the order above.








