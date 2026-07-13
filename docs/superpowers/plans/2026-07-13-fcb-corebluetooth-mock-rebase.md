# FCB CoreBluetooth Mock Rebase Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rebase `FCBComposable`'s central-role internals on Nordic's CoreBluetooth Mock (CBM) so one production code path runs against real CoreBluetooth on device and scripted mock peripherals in tests/Simulator, exposed via a new `BluetoothCentralClient.mocked()` factory.

**Architecture:** The internal `CentralActor` switches from `CBCentralManager`/`CBPeripheral` (behind the `CentralManaging`/`PeripheralConnection` protocols) to `CBMCentralManager`/`CBMPeripheral` directly — CBM is itself the abstraction (native passthrough vs. mock), so both internal protocols are deleted. New internal CBM-flavored closure delegate wrappers replace the Layer 1 CB-typed wrappers for the central role. The public `BluetoothCentralClient` API keeps CoreBluetooth types (`CBUUID`, `CBManagerState`, `CBCharacteristicWriteType` are typealiased or bridged from CBM).

**Tech Stack:** Swift 6.3 tools / Swift 6 language mode, strict concurrency; Swift Testing (`@Test`, `#expect`); swift-composable-architecture; CoreBluetoothMock ≥ 1.0.0.

**Spec:** `docs/superpowers/specs/2026-07-13-fcb-corebluetooth-mock-rebase-design.md`

## Global Constraints

- Repo root: `/Users/ell/development/ios/pods/FCB`. All commands run from there.
- Build: `swift build`. Test: `swift test` (runs on the macOS host). Single-type filter: `swift test --filter <TypeName>`.
- Swift 6 strict concurrency; tests use Swift Testing (`import Testing`), NOT XCTest.
- Public API of `BluetoothCentralClient` must not change (except the added `mocked()` factory). Signatures keep CoreBluetooth types: `CBUUID`, `CBManagerState`, `CBManagerAuthorization`, `CBCharacteristicWriteType`.
- `FCB` (Layer 1) target and `BluetoothPeripheralClient` (peripheral role) are untouched.
- CBM's simulation (`CBMCentralManagerMock.simulate…`) is process-global. EVERY test that touches it must live inside the single serialized parent suite `CBMBackedTests` (created in Task 1) via `extension CBMBackedTests { @Suite … }` — the `.serialized` trait is inherited by nested suites. Each such test starts with `CBMCentralManagerMock.tearDownSimulation()`.
- Verified CBM facts (v1.0.6, do not re-derive): `CBMPeripheral` is a *protocol*; `CBMUUID = CBUUID`, `CBMPeripheralState = CBPeripheralState`, `CBMCharacteristicWriteType = CBCharacteristicWriteType`, `CBMManagerAuthorization = CBManagerAuthorization` are typealiases; `CBMManagerState` is a SEPARATE enum (needs bridging); `CBMCentralManagerFactory.instance(forceMock:)` creates the manager; `CBMCentralManagerDelegate`/`CBMPeripheralDelegate` have default implementations for all methods; `CBMServiceMock(type:primary:characteristics:)` and `CBMCharacteristicMock(type:properties:)` are publicly constructible.
- User rules: run exactly ONE command per Bash invocation (no `&&`, `|`, `;`, `$( )`, `xargs`, inline interpreter scripts). Temp files go in `/tmp/FCB/`.
- The repo has unrelated uncommitted WIP under `Example/`. When committing, `git add` ONLY the files named in the task — never `git add -A` or `git add .`.
- After each task's tests pass, run the mutation-verification cycle (per user global CLAUDE.md): (a) all green → (b) apply the task's listed mutations in one batch, run tests, confirm the task's tests FAIL → (c) revert mutations, confirm green. Only then commit.

---

### Task 1: CBM dependency + internal CBM delegate wrappers

**Files:**
- Modify: `Package.swift`
- Create: `Sources/FCBComposable/Internal/FCBMDelegates.swift`
- Create: `Tests/FCBComposableTests/CBMBackedTests.swift`
- Create: `Tests/FCBComposableTests/FCBMDelegateTests.swift`

**Interfaces:**
- Consumes: CBM public API (`CBMCentralManagerDelegate`, `CBMPeripheralDelegate`, `CBMCentralManager`, `CBMPeripheral`, `CBMService`, `CBMCharacteristic`).
- Produces: `FCBMCentralManagerDelegate` (internal, closures: `onDidUpdateState`, `onDidDiscover`, `onDidConnect`, `onDidFailToConnect`, `onDidDisconnect`), `FCBMPeripheralDelegate` (internal, closures: `onDidDiscoverServices`, `onDidDiscoverCharacteristics`, `onDidUpdateValueForCharacteristic`, `onDidWriteValueForCharacteristic`, `onDidUpdateNotificationState`), and the serialized parent suite `CBMBackedTests` used by Tasks 2–4.

- [ ] **Step 1: Add the CBM dependency to Package.swift**

Replace the full contents of `Package.swift` with:

```swift
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
        .package(url: "https://github.com/NordicSemiconductor/IOS-CoreBluetooth-Mock.git", from: "1.0.0"),
    ],
    targets: [
        .target(name: "FCB"),
        .target(
            name: "FCBComposable",
            dependencies: [
                "FCB",
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
                .product(name: "CoreBluetoothMock", package: "IOS-CoreBluetooth-Mock"),
            ]
        ),
        .testTarget(name: "FCBTests", dependencies: ["FCB"]),
        .testTarget(name: "FCBComposableTests", dependencies: ["FCBComposable"]),
    ],
    swiftLanguageModes: [.v6]
)
```

- [ ] **Step 2: Verify the dependency resolves**

Run: `swift build`
Expected: resolves IOS-CoreBluetooth-Mock, builds successfully.

- [ ] **Step 3: Create the serialized parent suite**

Create `Tests/FCBComposableTests/CBMBackedTests.swift`:

```swift
import Testing

/// Parent suite for ALL tests that touch CoreBluetoothMock's process-global
/// simulation (`CBMCentralManagerMock.simulate…` / `tearDownSimulation`).
/// `.serialized` is inherited by nested suites, so no two CBM-backed tests
/// ever run concurrently. Nest new CBM suites via `extension CBMBackedTests`.
@Suite(.serialized) struct CBMBackedTests {}
```

- [ ] **Step 4: Write the failing delegate-wrapper tests**

Create `Tests/FCBComposableTests/FCBMDelegateTests.swift`:

```swift
import CoreBluetoothMock
import Foundation
import Testing
@testable import FCBComposable

extension CBMBackedTests {
    @Suite @MainActor
    struct FCBMDelegateTests {
        @Test func centralDelegateForwardsDidUpdateState() async {
            CBMCentralManagerMock.tearDownSimulation()
            CBMCentralManagerMock.simulateInitialState(.poweredOn)
            let manager = CBMCentralManagerFactory.instance(forceMock: true)
            let delegate = FCBMCentralManagerDelegate()
            nonisolated(unsafe) var received: CBMManagerState?
            delegate.onDidUpdateState = { central in received = central.state }
            delegate.centralManagerDidUpdateState(manager)
            #expect(received == .poweredOn)
        }

        @Test func peripheralDelegateForwardsDidUpdateValue() async {
            CBMCentralManagerMock.tearDownSimulation()
            CBMCentralManagerMock.simulateInitialState(.poweredOn)
            let id = UUID()
            let spec = CBMPeripheralSpec
                .simulatePeripheral(identifier: id)
                .connectable(name: "WrapperDev", services: [], delegate: nil)
                .allowForRetrieval()
                .build()
            CBMCentralManagerMock.simulatePeripherals([spec])
            let manager = CBMCentralManagerFactory.instance(forceMock: true)
            let peripheral = manager.retrievePeripherals(withIdentifiers: [id]).first!
            let characteristic = CBMCharacteristicMock(type: CBMUUID(string: "2A19"), properties: [.read])
            let delegate = FCBMPeripheralDelegate()
            nonisolated(unsafe) var receivedID: CBMUUID?
            delegate.onDidUpdateValueForCharacteristic = { _, c, _ in receivedID = c.uuid }
            delegate.peripheral(peripheral, didUpdateValueFor: characteristic, error: nil)
            #expect(receivedID == CBMUUID(string: "2A19"))
        }
    }
}
```

- [ ] **Step 5: Run tests to verify they fail**

Run: `swift test --filter FCBMDelegateTests`
Expected: BUILD FAILURE — `FCBMCentralManagerDelegate` / `FCBMPeripheralDelegate` not defined.

- [ ] **Step 6: Implement the wrappers**

Create `Sources/FCBComposable/Internal/FCBMDelegates.swift`:

```swift
import CoreBluetoothMock
import Foundation

/// Closure-based wrapper around `CBMCentralManagerDelegate`, mirroring Layer 1's
/// `FCBCentralManagerDelegate` pattern but typed on CoreBluetoothMock. Internal:
/// FCBComposable's public surface stays CoreBluetooth-typed. Only the callbacks
/// `CentralActor` consumes are exposed; CBM provides defaults for the rest.
final class FCBMCentralManagerDelegate: NSObject, CBMCentralManagerDelegate {
    var onDidUpdateState: (@Sendable (CBMCentralManager) -> Void)?
    var onDidDiscover: (@Sendable (CBMCentralManager, any CBMPeripheral, [String: Any], NSNumber) -> Void)?
    var onDidConnect: (@Sendable (CBMCentralManager, any CBMPeripheral) -> Void)?
    var onDidFailToConnect: (@Sendable (CBMCentralManager, any CBMPeripheral, (any Error)?) -> Void)?
    var onDidDisconnect: (@Sendable (CBMCentralManager, any CBMPeripheral, (any Error)?) -> Void)?

    func centralManagerDidUpdateState(_ central: CBMCentralManager) {
        onDidUpdateState?(central)
    }
    func centralManager(_ central: CBMCentralManager, didDiscover peripheral: any CBMPeripheral, advertisementData: [String: Any], rssi RSSI: NSNumber) {
        onDidDiscover?(central, peripheral, advertisementData, RSSI)
    }
    func centralManager(_ central: CBMCentralManager, didConnect peripheral: any CBMPeripheral) {
        onDidConnect?(central, peripheral)
    }
    func centralManager(_ central: CBMCentralManager, didFailToConnect peripheral: any CBMPeripheral, error: (any Error)?) {
        onDidFailToConnect?(central, peripheral, error)
    }
    func centralManager(_ central: CBMCentralManager, didDisconnectPeripheral peripheral: any CBMPeripheral, error: (any Error)?) {
        onDidDisconnect?(central, peripheral, error)
    }
}

final class FCBMPeripheralDelegate: NSObject, CBMPeripheralDelegate {
    var onDidDiscoverServices: (@Sendable (any CBMPeripheral, (any Error)?) -> Void)?
    var onDidDiscoverCharacteristics: (@Sendable (any CBMPeripheral, CBMService, (any Error)?) -> Void)?
    var onDidUpdateValueForCharacteristic: (@Sendable (any CBMPeripheral, CBMCharacteristic, (any Error)?) -> Void)?
    var onDidWriteValueForCharacteristic: (@Sendable (any CBMPeripheral, CBMCharacteristic, (any Error)?) -> Void)?
    var onDidUpdateNotificationState: (@Sendable (any CBMPeripheral, CBMCharacteristic, (any Error)?) -> Void)?

    func peripheral(_ peripheral: any CBMPeripheral, didDiscoverServices error: (any Error)?) {
        onDidDiscoverServices?(peripheral, error)
    }
    func peripheral(_ peripheral: any CBMPeripheral, didDiscoverCharacteristicsFor service: CBMService, error: (any Error)?) {
        onDidDiscoverCharacteristics?(peripheral, service, error)
    }
    func peripheral(_ peripheral: any CBMPeripheral, didUpdateValueFor characteristic: CBMCharacteristic, error: (any Error)?) {
        onDidUpdateValueForCharacteristic?(peripheral, characteristic, error)
    }
    func peripheral(_ peripheral: any CBMPeripheral, didWriteValueFor characteristic: CBMCharacteristic, error: (any Error)?) {
        onDidWriteValueForCharacteristic?(peripheral, characteristic, error)
    }
    func peripheral(_ peripheral: any CBMPeripheral, didUpdateNotificationStateFor characteristic: CBMCharacteristic, error: (any Error)?) {
        onDidUpdateNotificationState?(peripheral, characteristic, error)
    }
}
```

Note: if the compiler rejects a conformance signature, check the exact declaration in the CBM checkout (`~/Library/Developer/Xcode/DerivedData/Meshtastified-*/SourcePackages/checkouts/IOS-CoreBluetooth-Mock/CoreBluetoothMock/CBMCentralManagerDelegate.swift` and `CBMPeripheralDelegate.swift`) and match it exactly — do not change the closure property names.

- [ ] **Step 7: Run tests to verify they pass**

Run: `swift test --filter FCBMDelegateTests`
Expected: 2 tests PASS.

- [ ] **Step 8: Mutation check**

Batch-apply: in `centralManagerDidUpdateState`, comment out the `onDidUpdateState?(central)` call; in `peripheral(_:didUpdateValueFor:error:)`, comment out the forward. Run `swift test --filter FCBMDelegateTests` → expect BOTH tests FAIL. Revert both mutations. Run again → expect 2 PASS.

- [ ] **Step 9: Run the full suite (no regressions)**

Run: `swift test`
Expected: all existing tests still PASS.

- [ ] **Step 10: Commit**

```bash
git add Package.swift Package.resolved Sources/FCBComposable/Internal/FCBMDelegates.swift Tests/FCBComposableTests/CBMBackedTests.swift Tests/FCBComposableTests/FCBMDelegateTests.swift
```

```bash
git commit -m "feat: add CoreBluetoothMock dependency and internal CBM delegate wrappers" -m "Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 2: CBM value-type mapping initializers + CBManagerState bridge

**Files:**
- Create: `Sources/FCBComposable/Models/Peripheral+CBM.swift`
- Create: `Sources/FCBComposable/Models/Service+CBM.swift`
- Create: `Sources/FCBComposable/Models/Characteristic+CBM.swift`
- Create: `Sources/FCBComposable/Internal/CBManagerState+CBM.swift`
- Test: `Tests/FCBComposableTests/CBMMappingTests.swift`

**Interfaces:**
- Consumes: existing value types `Peripheral(id:name:state:)`, `Service(id:peripheralID:isPrimary:)`, `Characteristic(id:serviceID:peripheralID:properties:value:isNotifying:)`, `ConnectionState(_: CBPeripheralState)` (works for CBM via the `CBMPeripheralState = CBPeripheralState` typealias).
- Produces: `Peripheral.init(_ p: any CBMPeripheral)`, `Service.init(_ s: CBMService)`, `Characteristic.init(_ c: CBMCharacteristic)`, `CBManagerState.init(_ state: CBMManagerState)` — all used by Task 3's actor rewrite. The existing `+CB` initializers remain until Task 3 deletes them.

- [ ] **Step 1: Write the failing mapping tests**

Create `Tests/FCBComposableTests/CBMMappingTests.swift`:

```swift
@preconcurrency import CoreBluetooth
import CoreBluetoothMock
import Foundation
import Testing
@testable import FCBComposable

extension CBMBackedTests {
    @Suite @MainActor
    struct CBMMappingTests {
        @Test func serviceMapsUUIDAndPrimary() {
            let service = CBMServiceMock(type: CBMUUID(string: "180F"), primary: true)
            let mapped = Service(service)
            #expect(mapped.id == CBMUUID(string: "180F"))
            #expect(mapped.isPrimary)
        }

        @Test func characteristicMapsFields() {
            let characteristic = CBMCharacteristicMock(type: CBMUUID(string: "2A19"), properties: [.read, .notify])
            _ = CBMServiceMock(type: CBMUUID(string: "180F"), primary: true, characteristics: characteristic)
            let mapped = Characteristic(characteristic)
            #expect(mapped.id == CBMUUID(string: "2A19"))
            #expect(mapped.serviceID == CBMUUID(string: "180F"))
            #expect(mapped.properties.contains(.notify))
            #expect(mapped.isNotifying == false)
        }

        @Test func peripheralMapsIdentifierNameAndState() async {
            CBMCentralManagerMock.tearDownSimulation()
            CBMCentralManagerMock.simulateInitialState(.poweredOn)
            let id = UUID()
            let spec = CBMPeripheralSpec
                .simulatePeripheral(identifier: id)
                .connectable(name: "Mapped", services: [], delegate: nil)
                .allowForRetrieval()
                .build()
            CBMCentralManagerMock.simulatePeripherals([spec])
            let manager = CBMCentralManagerFactory.instance(forceMock: true)
            let cbm = manager.retrievePeripherals(withIdentifiers: [id]).first!
            let mapped = Peripheral(cbm)
            #expect(mapped.id == id)
            #expect(mapped.name == "Mapped")
            #expect(mapped.state == .disconnected)
        }

        @Test func managerStateBridgesAllCases() {
            #expect(CBManagerState(CBMManagerState.unknown) == .unknown)
            #expect(CBManagerState(CBMManagerState.resetting) == .resetting)
            #expect(CBManagerState(CBMManagerState.unsupported) == .unsupported)
            #expect(CBManagerState(CBMManagerState.unauthorized) == .unauthorized)
            #expect(CBManagerState(CBMManagerState.poweredOff) == .poweredOff)
            #expect(CBManagerState(CBMManagerState.poweredOn) == .poweredOn)
        }
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test --filter CBMMappingTests`
Expected: BUILD FAILURE — no CBM initializers on `Service`/`Characteristic`/`Peripheral`/`CBManagerState`.

- [ ] **Step 3: Implement the mapping initializers**

Create `Sources/FCBComposable/Models/Peripheral+CBM.swift`:

```swift
import CoreBluetoothMock
import Foundation

extension Peripheral {
    init(_ p: any CBMPeripheral) {
        self.init(id: p.identifier, name: p.name, state: ConnectionState(p.state))
    }
}
```

Create `Sources/FCBComposable/Models/Service+CBM.swift`:

```swift
import CoreBluetoothMock
import Foundation

extension Service {
    init(_ s: CBMService) {
        self.init(id: s.uuid, peripheralID: s.peripheral?.identifier ?? UUID(), isPrimary: s.isPrimary)
    }
}
```

Create `Sources/FCBComposable/Models/Characteristic+CBM.swift`:

```swift
@preconcurrency import CoreBluetooth
import CoreBluetoothMock
import Foundation

extension Characteristic {
    init(_ c: CBMCharacteristic) {
        self.init(
            id: c.uuid,
            serviceID: c.service?.uuid ?? CBUUID(),
            peripheralID: c.service?.peripheral?.identifier ?? UUID(),
            properties: c.properties,
            value: c.value,
            isNotifying: c.isNotifying
        )
    }
}
```

Create `Sources/FCBComposable/Internal/CBManagerState+CBM.swift`:

```swift
@preconcurrency import CoreBluetooth
import CoreBluetoothMock

extension CBManagerState {
    /// Bridges CBM's standalone `CBMManagerState` enum to the public
    /// `CBManagerState` used in `BluetoothCentralClient`'s API.
    init(_ state: CBMManagerState) {
        switch state {
        case .unknown: self = .unknown
        case .resetting: self = .resetting
        case .unsupported: self = .unsupported
        case .unauthorized: self = .unauthorized
        case .poweredOff: self = .poweredOff
        case .poweredOn: self = .poweredOn
        }
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `swift test --filter CBMMappingTests`
Expected: 4 tests PASS.

- [ ] **Step 5: Mutation check**

Batch-apply: in `Service+CBM.swift` replace `isPrimary: s.isPrimary` with `isPrimary: false`; in `Characteristic+CBM.swift` replace `serviceID: c.service?.uuid ?? CBUUID()` with `serviceID: CBUUID()`; in `CBManagerState+CBM.swift` swap the `.poweredOn` case body to `self = .poweredOff`; in `Peripheral+CBM.swift` replace `name: p.name` with `name: nil`. Run `swift test --filter CBMMappingTests` → expect all 4 tests FAIL. Revert all mutations → expect 4 PASS.

- [ ] **Step 6: Commit**

```bash
git add Sources/FCBComposable/Models/Peripheral+CBM.swift Sources/FCBComposable/Models/Service+CBM.swift Sources/FCBComposable/Models/Characteristic+CBM.swift Sources/FCBComposable/Internal/CBManagerState+CBM.swift Tests/FCBComposableTests/CBMMappingTests.swift
```

```bash
git commit -m "feat: add CBM-to-value-type mapping initializers and CBMManagerState bridge" -m "Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 3: Rebase CentralActor on CBM and migrate the central client tests

This is the core migration. The old call-recording fakes (`FakeCentralManager`, `FakePeripheralConnection`) and the ObjC-runtime `CBPeripheral` stubs are replaced by CBM's supported simulation API (`CBMCentralManagerMock` + `CBMPeripheralSpec`), and the actor's test-only injection helpers are deleted — tests now exercise the real delegate paths.

**Files:**
- Modify: `Sources/FCBComposable/BluetoothCentralClient+Live.swift` (full rewrite below)
- Delete: `Sources/FCBComposable/Internal/CentralManaging.swift`
- Delete: `Sources/FCBComposable/Internal/PeripheralConnection.swift`
- Delete: `Sources/FCBComposable/Models/Peripheral+CB.swift`
- Delete: `Sources/FCBComposable/Models/Service+CB.swift`
- Delete: `Sources/FCBComposable/Models/Characteristic+CB.swift`
- Delete: `Tests/FCBComposableTests/FakeCentralManager.swift`
- Delete: `Tests/FCBComposableTests/FakePeripheralConnection.swift`
- Rewrite: `Tests/FCBComposableTests/BluetoothCentralClientTests.swift` (full contents below)

**Interfaces:**
- Consumes: `FCBMCentralManagerDelegate`/`FCBMPeripheralDelegate` (Task 1), CBM mapping initializers + `CBManagerState.init(_: CBMManagerState)` (Task 2).
- Produces: `CentralActor.init(manager: CBMCentralManager)` — Task 4's `mocked()` factory calls this with `CBMCentralManagerFactory.instance(forceMock: true)`. All other `CentralActor` method signatures are unchanged (`connect(id:options:)`, `disconnect(id:)`, `discoverServices(peripheralID:serviceIDs:)`, `discoverCharacteristics(peripheralID:serviceID:characteristicIDs:)`, `readValue(peripheralID:characteristicID:)`, `writeValue(data:peripheralID:characteristicID:type:)`, `setNotify(enabled:peripheralID:characteristicID:)`, `scan(services:options:)`, `notifications(peripheralID:characteristicID:)`, `stateStream()`, `eventStream()`, `stopScan()`, `retrievePeripherals(ids:)`, `retrieveConnected(services:)`). The `injectPeripheralForTest`/`completeDiscoverServicesForTest`/`injectCharacteristicForTest`/`completeWriteForTest`/`completeNotifyForTest`/`simulateNotificationValueForTest` helpers are REMOVED.

- [ ] **Step 1: Rewrite the test file (this is the "red" step)**

Replace the full contents of `Tests/FCBComposableTests/BluetoothCentralClientTests.swift` with:

```swift
import ComposableArchitecture
@preconcurrency import CoreBluetooth
@preconcurrency import CoreBluetoothMock
import Foundation
import Testing
@testable import FCBComposable

@MainActor
struct BluetoothCentralClientContractTests {
    @Test func testValueDisconnectThrowsUnimplemented() async {
        let client = BluetoothCentralClient.testValue
        await withKnownIssue("disconnect should report unimplemented") {
            _ = try await client.disconnect(UUID())
        }
    }
}

// MARK: - CBM simulation harness

let cbmBatteryServiceUUID = CBMUUID(string: "180F")
let cbmBatteryLevelUUID = CBMUUID(string: "2A19")

/// Spec delegate that answers reads with a canned value and records writes.
final class RecordingSpecDelegate: CBMPeripheralSpecDelegate, @unchecked Sendable {
    var readValue = Data([0x64])
    private(set) var writes: [(characteristicUUID: CBMUUID, data: Data)] = []

    func peripheral(_ peripheral: CBMPeripheralSpec,
                    didReceiveReadRequestFor characteristic: CBMCharacteristicMock) -> Result<Data, any Error> {
        .success(readValue)
    }

    func peripheral(_ peripheral: CBMPeripheralSpec,
                    didReceiveWriteRequestFor characteristic: CBMCharacteristicMock,
                    data: Data) -> Result<Void, any Error> {
        writes.append((characteristic.uuid, data))
        return .success(())
    }
}

struct MockRadioSetup {
    let actor: CentralActor
    let spec: CBMPeripheralSpec
    let specDelegate: RecordingSpecDelegate
    let characteristic: CBMCharacteristicMock
    let id: UUID
}

/// Tears down any previous simulation and stands up one battery-service
/// peripheral behind a fresh mock manager wrapped in a CentralActor.
@MainActor
func makeMockRadio(id: UUID = UUID(), state: CBMManagerState = .poweredOn) -> MockRadioSetup {
    CBMCentralManagerMock.tearDownSimulation()
    CBMCentralManagerMock.simulateInitialState(state)
    let specDelegate = RecordingSpecDelegate()
    let batteryLevel = CBMCharacteristicMock(type: cbmBatteryLevelUUID, properties: [.read, .write, .notify])
    let batteryService = CBMServiceMock(type: cbmBatteryServiceUUID, primary: true, characteristics: batteryLevel)
    let spec = CBMPeripheralSpec
        .simulatePeripheral(identifier: id, proximity: .near)
        .advertising(advertisementData: [
            CBMAdvertisementDataLocalNameKey: "MockDev",
            CBMAdvertisementDataServiceUUIDsKey: [cbmBatteryServiceUUID],
        ], withInterval: 0.05)
        .connectable(name: "MockDev", services: [batteryService], delegate: specDelegate, connectionInterval: 0.01)
        .allowForRetrieval()
        .build()
    CBMCentralManagerMock.simulatePeripherals([spec])
    let actor = CentralActor(manager: CBMCentralManagerFactory.instance(forceMock: true))
    return MockRadioSetup(actor: actor, spec: spec, specDelegate: specDelegate, characteristic: batteryLevel, id: id)
}

/// A mock manager with NO simulated peripherals (for unknown-peripheral paths).
@MainActor
func makeEmptyMockActor(state: CBMManagerState = .poweredOn) -> CentralActor {
    CBMCentralManagerMock.tearDownSimulation()
    CBMCentralManagerMock.simulateInitialState(state)
    CBMCentralManagerMock.simulatePeripherals([])
    return CentralActor(manager: CBMCentralManagerFactory.instance(forceMock: true))
}

/// Connects and discovers the battery service + characteristic — the
/// precondition for read/write/notify tests.
@MainActor
func connectAndDiscover(_ setup: MockRadioSetup) async throws {
    _ = try await setup.actor.connect(id: setup.id, options: nil)
    _ = try await setup.actor.discoverServices(peripheralID: setup.id, serviceIDs: [cbmBatteryServiceUUID])
    _ = try await setup.actor.discoverCharacteristics(peripheralID: setup.id, serviceID: cbmBatteryServiceUUID, characteristicIDs: nil)
}

// MARK: - Suites (all inside the serialized CBM parent suite)

extension CBMBackedTests {
    @Suite @MainActor
    struct CentralScanAndStateTests {
        @Test func scanYieldsDiscoveredPeripheral() async {
            let setup = makeMockRadio()
            let stream = setup.actor.scan(services: [cbmBatteryServiceUUID], options: nil)
            var iter = stream.makeAsyncIterator()
            let discovered = await iter.next()
            #expect(discovered?.advertisementData.localName == "MockDev")
            #expect(discovered?.peripheral.id == setup.id)
        }

        @Test func stateStreamReplaysCurrentStateOnSubscribe() async {
            let setup = makeMockRadio()
            var iter = setup.actor.stateStream().makeAsyncIterator()
            let first = await iter.next()
            #expect(first == .poweredOn)
        }

        @Test func stateStreamYieldsPowerOff() async {
            let setup = makeMockRadio()
            var iter = setup.actor.stateStream().makeAsyncIterator()
            let first = await iter.next()
            #expect(first == .poweredOn)
            CBMCentralManagerMock.simulatePowerOff()
            let next = await iter.next()
            #expect(next == .poweredOff)
        }

        @Test func eventStreamYieldsDidConnect() async throws {
            let setup = makeMockRadio()
            let stream = setup.actor.eventStream()
            let connectTask = Task { try await setup.actor.connect(id: setup.id, options: nil) }
            var connectedID: UUID?
            for await event in stream {
                if case .didConnect(let p) = event {
                    connectedID = p.id
                    break
                }
            }
            _ = try await connectTask.value
            #expect(connectedID == setup.id)
        }
    }

    @Suite @MainActor
    struct CentralConnectTests {
        @Test func connectResolvesViaRetrieval() async throws {
            let setup = makeMockRadio()
            let peripheral = try await setup.actor.connect(id: setup.id, options: nil)
            #expect(peripheral.id == setup.id)
            #expect(peripheral.state == .connected)
        }

        @Test func connectThrowsUnknownPeripheral() async {
            let actor = makeEmptyMockActor()
            await #expect(throws: BluetoothError.self) {
                _ = try await actor.connect(id: UUID(), options: nil)
            }
        }

        @Test func connectThrowsWhenPoweredOff() async {
            let actor = makeEmptyMockActor(state: .poweredOff)
            await #expect(throws: BluetoothError.self) {
                _ = try await actor.connect(id: UUID(), options: nil)
            }
        }

        @Test func disconnectResolves() async throws {
            let setup = makeMockRadio()
            _ = try await setup.actor.connect(id: setup.id, options: nil)
            try await setup.actor.disconnect(id: setup.id)
        }
    }

    @Suite @MainActor
    struct CentralDiscoveryTests {
        @Test func discoverServicesThrowsUnknownPeripheral() async {
            let actor = makeEmptyMockActor()
            await #expect(throws: BluetoothError.self) {
                _ = try await actor.discoverServices(peripheralID: UUID(), serviceIDs: nil)
            }
        }

        @Test func discoverServicesReturnsMappedService() async throws {
            let setup = makeMockRadio()
            _ = try await setup.actor.connect(id: setup.id, options: nil)
            let services = try await setup.actor.discoverServices(peripheralID: setup.id, serviceIDs: [cbmBatteryServiceUUID])
            #expect(services.map(\.id) == [cbmBatteryServiceUUID])
            #expect(services.first?.isPrimary == true)
        }

        @Test func discoverCharacteristicsReturnsMappedCharacteristic() async throws {
            let setup = makeMockRadio()
            _ = try await setup.actor.connect(id: setup.id, options: nil)
            _ = try await setup.actor.discoverServices(peripheralID: setup.id, serviceIDs: [cbmBatteryServiceUUID])
            let characteristics = try await setup.actor.discoverCharacteristics(peripheralID: setup.id, serviceID: cbmBatteryServiceUUID, characteristicIDs: nil)
            #expect(characteristics.contains { $0.id == cbmBatteryLevelUUID })
            #expect(characteristics.first?.properties.contains(.notify) == true)
        }
    }

    @Suite @MainActor
    struct CentralReadWriteNotifyTests {
        @Test func readValueReturnsSpecDelegateValue() async throws {
            let setup = makeMockRadio()
            try await connectAndDiscover(setup)
            let value = try await setup.actor.readValue(peripheralID: setup.id, characteristicID: cbmBatteryLevelUUID)
            #expect(value == Data([0x64]))
        }

        @Test func writeValueDeliversDataToSpecDelegate() async throws {
            let setup = makeMockRadio()
            try await connectAndDiscover(setup)
            try await setup.actor.writeValue(data: Data([0x01]), peripheralID: setup.id, characteristicID: cbmBatteryLevelUUID, type: .withResponse)
            #expect(setup.specDelegate.writes.count == 1)
            #expect(setup.specDelegate.writes.first?.data == Data([0x01]))
        }

        @Test func notificationsStreamYieldsSimulatedUpdate() async throws {
            let setup = makeMockRadio()
            try await connectAndDiscover(setup)
            try await setup.actor.setNotify(enabled: true, peripheralID: setup.id, characteristicID: cbmBatteryLevelUUID)
            let stream = setup.actor.notifications(peripheralID: setup.id, characteristicID: cbmBatteryLevelUUID)
            var iter = stream.makeAsyncIterator()
            try? await Task.sleep(nanoseconds: 50_000_000)
            setup.spec.simulateValueUpdate(Data([0xAA]), for: setup.characteristic)
            let next = try await iter.next()
            #expect(next == Data([0xAA]))
        }
    }
}
```

- [ ] **Step 2: Delete the obsolete files**

Run each as a single command:

```bash
rm Sources/FCBComposable/Internal/CentralManaging.swift
```
```bash
rm Sources/FCBComposable/Internal/PeripheralConnection.swift
```
```bash
rm Sources/FCBComposable/Models/Peripheral+CB.swift
```
```bash
rm Sources/FCBComposable/Models/Service+CB.swift
```
```bash
rm Sources/FCBComposable/Models/Characteristic+CB.swift
```
```bash
rm Tests/FCBComposableTests/FakeCentralManager.swift
```
```bash
rm Tests/FCBComposableTests/FakePeripheralConnection.swift
```

IMPORTANT: `ConnectionState.init(_ cb: CBPeripheralState)` currently lives in `Peripheral+CB.swift` and is still needed — Task 2's `Peripheral(any CBMPeripheral)` initializer calls it (`CBMPeripheralState` is a typealias for `CBPeripheralState`). Before deleting `Peripheral+CB.swift`, MOVE the `ConnectionState` extension into `Sources/FCBComposable/Models/Peripheral+CBM.swift` so it survives:

```swift
// Append to Sources/FCBComposable/Models/Peripheral+CBM.swift
extension ConnectionState {
    init(_ cb: CBMPeripheralState) {
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

(`CBMPeripheralState = CBPeripheralState`, so this is the same initializer with the CBM spelling; `@unknown default` stays because `CBPeripheralState` is a resilient ObjC enum.)

- [ ] **Step 3: Verify the build fails for the expected reason**

Run: `swift build`
Expected: FAILURE in `BluetoothCentralClient+Live.swift` — `CentralManaging`/`PeripheralConnection` no longer exist.

- [ ] **Step 4: Rewrite the live actor**

Replace the full contents of `Sources/FCBComposable/BluetoothCentralClient+Live.swift` with:

```swift
import ComposableArchitecture
@preconcurrency import CoreBluetooth
@preconcurrency import CoreBluetoothMock
import Foundation

extension BluetoothCentralClient: DependencyKey {
    public static let liveValue: BluetoothCentralClient = {
        // CBMCentralManagerFactory returns the native passthrough manager on
        // device, or the mock when a simulation is active and mock is forced.
        let actor = CentralActor(manager: CBMCentralManagerFactory.instance())
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
            retrieveConnected: { services in
                nonisolated(unsafe) let servicesCopy: [CBUUID] = Array(services)
                return await actor.retrieveConnected(services: servicesCopy)
            },
            discoverServices: { pid, sids in
                nonisolated(unsafe) let sidsCopy: [CBUUID]? = sids.map { Array($0) }
                return try await actor.discoverServices(peripheralID: pid, serviceIDs: sidsCopy)
            },
            discoverCharacteristics: { pid, sid, cids in
                nonisolated(unsafe) let cidsCopy: [CBUUID]? = cids.map { Array($0) }
                return try await actor.discoverCharacteristics(peripheralID: pid, serviceID: sid, characteristicIDs: cidsCopy)
            },
            readValue: { pid, cid in try await actor.readValue(peripheralID: pid, characteristicID: cid) },
            writeValue: { data, pid, cid, type in try await actor.writeValue(data: data, peripheralID: pid, characteristicID: cid, type: type) },
            setNotify: { enabled, pid, cid in try await actor.setNotify(enabled: enabled, peripheralID: pid, characteristicID: cid) },
            notifications: { pid, cid in actor.notifications(peripheralID: pid, characteristicID: cid) },
            events: { actor.eventStream() }
        )
    }
}

final actor CentralActor {
    private let manager: CBMCentralManager
    private let delegate = FCBMCentralManagerDelegate()
    private var peripheralDelegate = FCBMPeripheralDelegate()

    private var peripherals: [UUID: any CBMPeripheral] = [:]
    private var characteristics: [String: CBMCharacteristic] = [:]

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

    init(manager: CBMCentralManager) {
        self.manager = manager
        Task { await self.wireDelegates() }
    }

    private func wireDelegates() {
        manager.delegate = delegate
        delegate.onDidUpdateState = { [weak self] central in
            let state = central.state
            Task { await self?.handleDidUpdateState(state) }
        }
        delegate.onDidDiscover = { [weak self] _, peripheral, ad, rssi in
            let advertisementData = AdvertisementData(dictionary: ad)
            let rssiInt = rssi.intValue
            nonisolated(unsafe) let p = peripheral
            Task { await self?.recordDiscoveredPeripheral(peripheral: p, ad: advertisementData, rssi: rssiInt) }
        }
        delegate.onDidConnect = { [weak self] _, peripheral in
            nonisolated(unsafe) let p = peripheral
            Task { await self?.handleDidConnect(peripheral: p) }
        }
        delegate.onDidFailToConnect = { [weak self] _, peripheral, error in
            let nsError = error.map { $0 as NSError }
            nonisolated(unsafe) let p = peripheral
            Task { await self?.handleDidFailToConnect(peripheral: p, nsError: nsError) }
        }
        delegate.onDidDisconnect = { [weak self] _, peripheral, error in
            let nsError = error.map { $0 as NSError }
            nonisolated(unsafe) let p = peripheral
            Task { await self?.handleDidDisconnect(peripheral: p, nsError: nsError) }
        }
        peripheralDelegate.onDidDiscoverServices = { [weak self] peripheral, error in
            let id = peripheral.identifier
            let services = peripheral.services?.map { Service($0) } ?? []
            let nsError = error.map { $0 as NSError }
            Task { await self?.handleDidDiscoverServices(id: id, services: services, nsError: nsError) }
        }
        peripheralDelegate.onDidDiscoverCharacteristics = { [weak self] peripheral, service, error in
            let pid = peripheral.identifier
            let serviceID = service.uuid
            nonisolated(unsafe) let cbmChars: [CBMCharacteristic] = service.characteristics ?? []
            let valueTypes = cbmChars.map { Characteristic($0) }
            let nsError = error.map { $0 as NSError }
            Task { await self?.handleDidDiscoverCharacteristics(peripheralID: pid, serviceID: serviceID, cbmCharacteristics: cbmChars, characteristics: valueTypes, error: nsError) }
        }
        peripheralDelegate.onDidUpdateValueForCharacteristic = { [weak self] peripheral, characteristic, error in
            let pid = peripheral.identifier
            let cid = characteristic.uuid
            let value = characteristic.value ?? Data()
            let nsError = error as NSError?
            Task { await self?.handleDidUpdateValue(peripheralID: pid, characteristicID: cid, value: value, error: nsError) }
        }
        peripheralDelegate.onDidWriteValueForCharacteristic = { [weak self] peripheral, characteristic, error in
            let pid = peripheral.identifier
            let cid = characteristic.uuid
            let nsError = error as NSError?
            Task { await self?.handleDidWriteValue(peripheralID: pid, characteristicID: cid, error: nsError) }
        }
        peripheralDelegate.onDidUpdateNotificationState = { [weak self] peripheral, characteristic, error in
            let pid = peripheral.identifier
            let cid = characteristic.uuid
            let nsError = error as NSError?
            Task { await self?.handleDidUpdateNotificationState(peripheralID: pid, characteristicID: cid, error: nsError) }
        }
    }

    // MARK: - Public stream methods

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
        // Wrap in a sendable box so the values can cross actor boundaries under Swift 6.
        nonisolated(unsafe) let servicesCopy: [CBUUID]? = services.map { Array($0) }
        nonisolated(unsafe) let optionsCopy = options
        return AsyncStream<DiscoveredPeripheral> { continuation in
            Task { await self.startScan(services: servicesCopy, options: optionsCopy, continuation: continuation) }
            continuation.onTermination = { _ in
                Task { await self.endScan() }
            }
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

    func stopScan() async {
        manager.stopScan()
        scanContinuation?.finish()
        scanContinuation = nil
    }

    func connect(id: UUID, options: ConnectOptions?) async throws -> Peripheral {
        try preflightCheck()
        let connection: any CBMPeripheral
        if let existing = peripherals[id] {
            connection = existing
        } else if let lookedUp = lookupPeripheral(id: id) {
            connection = lookedUp
        } else {
            throw BluetoothError.unknownPeripheral(id)
        }
        return try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Peripheral, any Error>) in
            pendingConnect[id] = cont
            manager.connect(connection, options: options?.dictionary)
        }
    }

    func disconnect(id: UUID) async throws {
        guard let connection = peripherals[id] else {
            throw BluetoothError.unknownPeripheral(id)
        }
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, any Error>) in
            pendingDisconnect[id] = cont
            manager.cancelPeripheralConnection(connection)
        }
    }

    func retrievePeripherals(ids: [UUID]) async -> [Peripheral] {
        let found = manager.retrievePeripherals(withIdentifiers: ids)
        for p in found { peripherals[p.identifier] = p }
        return found.map { Peripheral($0) }
    }

    func retrieveConnected(services: [CBUUID]) async -> [Peripheral] {
        let found = manager.retrieveConnectedPeripherals(withServices: services)
        for p in found { peripherals[p.identifier] = p }
        return found.map { Peripheral($0) }
    }

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

    // MARK: - Private helpers

    private func preflightCheck() throws {
        switch manager.state {
        case .poweredOn: return
        case .poweredOff: throw BluetoothError.poweredOff
        case .unsupported: throw BluetoothError.unsupported
        case .unauthorized: throw BluetoothError.unauthorized(CBManager.authorization)
        case .unknown, .resetting: return
        }
    }

    private func resolve(peripheralID: UUID, characteristicID: CBUUID) throws -> (any CBMPeripheral, CBMCharacteristic) {
        guard let connection = peripherals[peripheralID] else {
            throw BluetoothError.unknownPeripheral(peripheralID)
        }
        let key = "\(peripheralID.uuidString):\(characteristicID.uuidString)"
        guard let characteristic = characteristics[key] else {
            throw BluetoothError.unknownCharacteristic(characteristicID, serviceID: CBUUID())
        }
        return (connection, characteristic)
    }

    private func lookupPeripheral(id: UUID) -> (any CBMPeripheral)? {
        let found = manager.retrievePeripherals(withIdentifiers: [id])
        if let p = found.first {
            peripherals[id] = p
            return p
        }
        return nil
    }

    // MARK: - Private actor-isolated registration helpers

    private func registerStateContinuation(_ token: UUID, continuation: AsyncStream<CBManagerState>.Continuation) {
        stateContinuations[token] = continuation
        // Replay the manager's current state so subscribers that attach AFTER a
        // state transition (e.g. .poweredOn fired during app init, long before
        // the consumer's for-await began) don't wait forever for an event that
        // already happened.
        continuation.yield(CBManagerState(manager.state))
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

    private func registerNotificationContinuation(key: String, continuation: AsyncThrowingStream<Data, any Error>.Continuation) {
        notificationContinuations[key] = continuation
    }

    private func unregisterNotificationContinuation(key: String) {
        notificationContinuations.removeValue(forKey: key)
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

    // MARK: - Delegate handlers (actor-isolated)

    private func handleDidUpdateState(_ state: CBMManagerState) {
        let bridged = CBManagerState(state)
        for cont in stateContinuations.values { cont.yield(bridged) }
        emit(.didUpdateState(bridged))
    }

    private func recordDiscoveredPeripheral(peripheral: any CBMPeripheral, ad: AdvertisementData, rssi: Int) {
        let id = peripheral.identifier
        let mapped = Peripheral(peripheral)
        peripherals[id] = peripheral
        let discovered = DiscoveredPeripheral(peripheral: mapped, advertisementData: ad, rssi: rssi)
        scanContinuation?.yield(discovered)
        emit(.didDiscover(discovered))
    }

    private func handleDidConnect(peripheral: any CBMPeripheral) {
        let id = peripheral.identifier
        let mapped = Peripheral(peripheral)
        peripherals[id] = peripheral
        peripheral.delegate = peripheralDelegate
        emit(.didConnect(mapped))
        if let cont = pendingConnect.removeValue(forKey: id) {
            cont.resume(returning: mapped)
        }
    }

    private func handleDidFailToConnect(peripheral: any CBMPeripheral, nsError: NSError?) {
        let id = peripheral.identifier
        let mapped = Peripheral(peripheral)
        let err = BluetoothError.connectionFailed(peripheralID: id, underlying: nsError)
        emit(.didFailToConnect(mapped, err))
        if let cont = pendingConnect.removeValue(forKey: id) {
            cont.resume(throwing: err)
        }
    }

    private func handleDidDisconnect(peripheral: any CBMPeripheral, nsError: NSError?) {
        let id = peripheral.identifier
        let mapped = Peripheral(peripheral)
        peripherals.removeValue(forKey: id)
        let btError = nsError.map { BluetoothError.disconnected(peripheralID: id, underlying: $0) }
        emit(.didDisconnect(mapped, btError))
        if let cont = pendingDisconnect.removeValue(forKey: id) {
            if let btError {
                cont.resume(throwing: btError)
            } else {
                cont.resume()
            }
        }
    }

    private func handleDidDiscoverServices(id: UUID, services: [Service], nsError: NSError?) {
        if let cont = pendingDiscoverServices.removeValue(forKey: id) {
            if let nsError {
                cont.resume(throwing: BluetoothError(nsError))
            } else {
                cont.resume(returning: services)
            }
        }
    }

    private func handleDidDiscoverCharacteristics(peripheralID: UUID, serviceID: CBUUID, cbmCharacteristics: [CBMCharacteristic], characteristics newChars: [Characteristic], error: NSError?) {
        for c in cbmCharacteristics {
            let charKey = "\(peripheralID.uuidString):\(c.uuid.uuidString)"
            characteristics[charKey] = c
        }
        let key = "\(peripheralID.uuidString):\(serviceID.uuidString)"
        if let cont = pendingDiscoverCharacteristics.removeValue(forKey: key) {
            if let error {
                cont.resume(throwing: BluetoothError(error))
            } else {
                cont.resume(returning: newChars)
            }
        }
    }

    private func handleDidUpdateValue(peripheralID: UUID, characteristicID: CBUUID, value: Data, error: NSError?) {
        let key = "\(peripheralID.uuidString):\(characteristicID.uuidString)"
        if let cont = pendingReads.removeValue(forKey: key) {
            if let error {
                cont.resume(throwing: BluetoothError(error))
            } else {
                cont.resume(returning: value)
            }
        }
        if let notifCont = notificationContinuations[key] {
            if let error {
                notifCont.finish(throwing: BluetoothError(error))
            } else {
                notifCont.yield(value)
            }
        }
    }

    private func handleDidWriteValue(peripheralID: UUID, characteristicID: CBUUID, error: NSError?) {
        let key = "\(peripheralID.uuidString):\(characteristicID.uuidString)"
        if let cont = pendingWrites.removeValue(forKey: key) {
            if let error {
                cont.resume(throwing: BluetoothError(error))
            } else {
                cont.resume(returning: ())
            }
        }
    }

    private func handleDidUpdateNotificationState(peripheralID: UUID, characteristicID: CBUUID, error: NSError?) {
        let key = "\(peripheralID.uuidString):\(characteristicID.uuidString)"
        if let cont = pendingNotify.removeValue(forKey: key) {
            if let error {
                cont.resume(throwing: BluetoothError(error))
            } else {
                cont.resume(returning: ())
            }
        }
    }
}
```

Concurrency note: if the compiler rejects a `nonisolated(unsafe) let` capture or demands one where the plan doesn't show it, follow the file's existing precedent (extract Sendable values synchronously in the closure, wrap non-Sendable references with `nonisolated(unsafe) let` before the `Task` hop). Do not restructure the actor to satisfy a diagnostic.

- [ ] **Step 5: Run the full test suite**

Run: `swift test`
Expected: ALL tests pass — the new CBM-backed central tests, the mapping tests, the wrapper tests, plus untouched Layer 1 (`FCBTests`) and peripheral-role tests.

- [ ] **Step 6: Mutation check**

Batch-apply these mutations, run `swift test --filter CBMBackedTests`, and confirm the named tests FAIL:

1. In `preflightCheck()`, change `case .poweredOff: throw BluetoothError.poweredOff` to `case .poweredOff: return` → `connectThrowsWhenPoweredOff` fails.
2. In `handleDidUpdateValue`, comment out `notifCont.yield(value)` → `notificationsStreamYieldsSimulatedUpdate` fails.
3. In `handleDidConnect`, comment out `cont.resume(returning: mapped)` (keep the removal) → `connectResolvesViaRetrieval` (and others) fail/hang. If it hangs rather than fails, that still counts — note it and rely on the other mutations for signal.
4. In `recordDiscoveredPeripheral`, comment out `scanContinuation?.yield(discovered)` → `scanYieldsDiscoveredPeripheral` fails/hangs.

Revert all mutations. Run `swift test` → all PASS.

- [ ] **Step 7: Commit**

```bash
git add -u Sources/FCBComposable Tests/FCBComposableTests
```

```bash
git add Sources/FCBComposable/Models/Peripheral+CBM.swift Tests/FCBComposableTests/BluetoothCentralClientTests.swift
```

```bash
git commit -m "refactor: rebase CentralActor on CoreBluetoothMock, drop internal CB protocols and ObjC-runtime test stubs" -m "Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 4: Public `mocked()` factory + end-to-end round trip through the client

**Files:**
- Modify: `Sources/FCBComposable/BluetoothCentralClient+Live.swift` (add one extension method)
- Test: `Tests/FCBComposableTests/MockedClientEndToEndTests.swift`

**Interfaces:**
- Consumes: `CentralActor.init(manager: CBMCentralManager)`, `makeClient(actor:)` (Task 3), `RecordingSpecDelegate` and UUID constants from `BluetoothCentralClientTests.swift` (they are internal to the test target — reference them directly).
- Produces: `public static func mocked() -> BluetoothCentralClient` — the seam Meshtastified's integration tests and Simulator builds will use.

- [ ] **Step 1: Write the failing end-to-end test**

Create `Tests/FCBComposableTests/MockedClientEndToEndTests.swift`:

```swift
@preconcurrency import CoreBluetooth
@preconcurrency import CoreBluetoothMock
import Foundation
import Testing
@testable import FCBComposable

extension CBMBackedTests {
    @Suite @MainActor
    struct MockedClientEndToEndTests {
        @Test func fullRoundTripThroughMockedClient() async throws {
            CBMCentralManagerMock.tearDownSimulation()
            CBMCentralManagerMock.simulateInitialState(.poweredOn)
            let id = UUID()
            let characteristic = CBMCharacteristicMock(type: cbmBatteryLevelUUID, properties: [.read, .write, .notify])
            let service = CBMServiceMock(type: cbmBatteryServiceUUID, primary: true, characteristics: characteristic)
            let specDelegate = RecordingSpecDelegate()
            let spec = CBMPeripheralSpec
                .simulatePeripheral(identifier: id, proximity: .near)
                .advertising(advertisementData: [
                    CBMAdvertisementDataLocalNameKey: "E2EDev",
                    CBMAdvertisementDataServiceUUIDsKey: [cbmBatteryServiceUUID],
                ], withInterval: 0.05)
                .connectable(name: "E2EDev", services: [service], delegate: specDelegate, connectionInterval: 0.01)
                .build()
            CBMCentralManagerMock.simulatePeripherals([spec])

            let client = BluetoothCentralClient.mocked()

            // Scan
            var scanIter = client.scan([cbmBatteryServiceUUID], nil).makeAsyncIterator()
            let discovered = await scanIter.next()
            #expect(discovered?.advertisementData.localName == "E2EDev")
            let pid = try #require(discovered?.peripheral.id)

            // Connect + discover
            let connected = try await client.connect(pid, nil)
            #expect(connected.id == id)
            let services = try await client.discoverServices(pid, [cbmBatteryServiceUUID])
            #expect(services.map(\.id) == [cbmBatteryServiceUUID])
            let characteristics = try await client.discoverCharacteristics(pid, cbmBatteryServiceUUID, nil)
            #expect(characteristics.contains { $0.id == cbmBatteryLevelUUID })

            // Write with response reaches the spec delegate
            try await client.writeValue(Data([0x2A]), pid, cbmBatteryLevelUUID, .withResponse)
            #expect(specDelegate.writes.first?.data == Data([0x2A]))

            // Notifications round-trip
            try await client.setNotify(true, pid, cbmBatteryLevelUUID)
            var notifIter = client.notifications(pid, cbmBatteryLevelUUID).makeAsyncIterator()
            try? await Task.sleep(nanoseconds: 50_000_000)
            spec.simulateValueUpdate(Data([0xAA]), for: characteristic)
            let value = try await notifIter.next()
            #expect(value == Data([0xAA]))
        }
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter MockedClientEndToEndTests`
Expected: BUILD FAILURE — `BluetoothCentralClient.mocked()` not defined.

- [ ] **Step 3: Implement `mocked()`**

In `Sources/FCBComposable/BluetoothCentralClient+Live.swift`, add below the `DependencyKey` extension:

```swift
extension BluetoothCentralClient {
    /// A live client backed by `CBMCentralManagerMock`. Configure the simulation
    /// FIRST via `CBMCentralManagerMock.simulateInitialState(_:)` and
    /// `CBMCentralManagerMock.simulatePeripherals(_:)`, then create the client.
    /// Intended for integration tests and Simulator builds; FCB does not wrap
    /// CBM's simulation API — script `CBMPeripheralSpec`s directly.
    public static func mocked() -> BluetoothCentralClient {
        makeClient(actor: CentralActor(manager: CBMCentralManagerFactory.instance(forceMock: true)))
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `swift test --filter MockedClientEndToEndTests`
Expected: PASS.

- [ ] **Step 5: Mutation check**

Apply: change `forceMock: true` to `forceMock: false` in `mocked()`. Run `swift test --filter MockedClientEndToEndTests` → expect FAIL or hang (on the macOS host, real CoreBluetooth yields no simulated device; if it hangs, treat as failure signal). Revert → PASS.

- [ ] **Step 6: Run the full suite**

Run: `swift test`
Expected: all PASS.

- [ ] **Step 7: Commit**

```bash
git add Sources/FCBComposable/BluetoothCentralClient+Live.swift Tests/FCBComposableTests/MockedClientEndToEndTests.swift
```

```bash
git commit -m "feat: add BluetoothCentralClient.mocked() factory with end-to-end CBM round-trip test" -m "Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 5: Demo-app compile check + documentation update

**Files:**
- Modify: `CLAUDE.md`
- (Read-only check): `Example/FCBDemoFeatures`

**Interfaces:**
- Consumes: everything above.
- Produces: spec acceptance criteria verified; CLAUDE.md reflects the new architecture for future sessions.

- [ ] **Step 1: Verify the demo package still compiles (public API unchanged)**

Run: `swift build --package-path Example/FCBDemoFeatures`
Expected: builds successfully. (The demo depends on `FCBComposable` via a path dependency, so this proves no public API broke. The `Example/` tree has unrelated uncommitted WIP — do not modify or commit anything under it.)

- [ ] **Step 2: Verify no ObjC-runtime stubbing remains in central-role Layer 2 tests**

Run: `grep -rn "class_createInstance" Tests/FCBComposableTests`
Expected: no output. (Layer 1 `Tests/FCBTests/BLETestStub.swift` and peripheral-role test stubs are allowed to remain.)

- [ ] **Step 3: Update CLAUDE.md**

In `CLAUDE.md`, make these edits:

1. Replace the heading and first sentence of the Layer 2 section:

Old:
```markdown
### `FCBComposable` (Layer 2, depends on `FCB` + swift-composable-architecture)

TCA `@DependencyClient` clients backed by internal `actor`s:
```

New:
```markdown
### `FCBComposable` (Layer 2, depends on `FCB` + swift-composable-architecture + CoreBluetoothMock)

TCA `@DependencyClient` clients backed by internal `actor`s. The central role is
built on Nordic's CoreBluetoothMock (`CBMCentralManager`/`CBMPeripheral`):
`liveValue` uses `CBMCentralManagerFactory.instance()` (native passthrough on
device), and `BluetoothCentralClient.mocked()` returns a client backed by
`CBMCentralManagerMock` for integration tests and Simulator use — configure
`CBMCentralManagerMock.simulateInitialState(_:)` / `simulatePeripherals(_:)`
before creating it. The peripheral role remains on real CoreBluetooth (CBM has
no peripheral-manager mock). Public API keeps CoreBluetooth types; the internal
`CBMManagerState` → `CBManagerState` bridge lives in
`Sources/FCBComposable/Internal/CBManagerState+CBM.swift`.
```

2. Replace the conventions bullet that mentions `CentralManaging`:

Old:
```markdown
- The actor depends on `CentralManaging` / `PeripheralManaging` / `PeripheralConnection` internal protocols (`Sources/FCBComposable/Internal/`). Production uses CB types directly; tests inject fakes (`FakeCentralManager`, `FakePeripheralManager`, `FakePeripheralConnection`).
```

New:
```markdown
- `CentralActor` holds a `CBMCentralManager` and `any CBMPeripheral` values directly (no internal manager protocols for the central role); `PeripheralManaging` remains for the peripheral role, with `FakePeripheralManager` in tests. Central-role Layer 2 tests drive the real actor through `CBMCentralManagerMock` + `CBMPeripheralSpec`. Internal CBM closure-delegate wrappers live in `Sources/FCBComposable/Internal/FCBMDelegates.swift`.
```

3. Replace the ObjC-runtime stubbing bullet:

Old:
```markdown
- CoreBluetooth instances that have no public init (`CBPeripheral`, `CBService`, `CBCharacteristic`, etc.) are stubbed in tests via `class_createInstance` from the Objective-C runtime, plus `Unmanaged.passRetained` to leak the stub for the test process's lifetime (avoids KVO dealloc crashes). `CBPeripheral` stubs additionally have a real `NSUUID` injected via `object_setIvar` to make `.identifier` non-crashing. Helpers live in `Tests/FCBTests/BLETestStub.swift` (Layer 1) and `BLETestStubLocal` enums local to the Layer 2 test files.
```

New:
```markdown
- Layer 1 tests still stub un-instantiable CoreBluetooth types via `class_createInstance` (`Tests/FCBTests/BLETestStub.swift`); peripheral-role Layer 2 tests keep their local stubs. Central-role Layer 2 tests need no stubbing — they use CoreBluetoothMock. CBM's simulation is process-global, so every CBM-touching test nests inside the serialized `CBMBackedTests` parent suite (`Tests/FCBComposableTests/CBMBackedTests.swift`) and starts with `CBMCentralManagerMock.tearDownSimulation()`.
```

- [ ] **Step 4: Final full verification**

Run: `swift build`
Expected: success.

Run: `swift test`
Expected: all PASS.

- [ ] **Step 5: Commit**

```bash
git add CLAUDE.md
```

```bash
git commit -m "docs: update CLAUDE.md for the CoreBluetoothMock rebase" -m "Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```
