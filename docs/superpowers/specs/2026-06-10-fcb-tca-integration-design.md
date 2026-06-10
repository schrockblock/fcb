# FCB Package Modernization & TCA Integration — Design

**Date:** 2026-06-10
**Status:** Approved (pending spec review)

## Background

The CoreBluetooth wrappers currently living in `../fuikit/fuikit/Classes/FCB/` (three Swift files dated December 2020) are being extracted into a standalone Swift Package at this repository, modernized for Swift 6 strict concurrency and iOS 17+, and extended with a layer that integrates them with PointFree's Composable Architecture (TCA).

### What's in the source package today

- `FCBCentralManagerDelegate.swift` — `open class FCentralManagerDelegate: NSObject, CBCentralManagerDelegate` exposing each delegate callback as an optional closure. The class name is misspelled (`FCentral…` instead of `FCBCentral…`).
- `FCBPeripheralManager.swift` — `open class FCBPeripheralManager: CBPeripheralManager` that overrides each outgoing method on `CBPeripheralManager` and exposes a paired `on…` closure hook. `super` is always called first.
- `FCBPeripheralManagerDelegate.swift` — `open class FCBPeripheralManagerDelegate: NSObject, CBPeripheralManagerDelegate` exposing each delegate callback as an optional closure. One iOS 13 L2CAP method is intentionally omitted per an inline comment.

### Gaps and dated bits in the source

- No `CBPeripheralDelegate` wrapper — the central side of the closure pattern is incomplete; consumers can't observe service/characteristic discovery or value updates in the same style.
- No `FCBCentralManager` subclass mirroring the `FCBPeripheralManager` design (asymmetric).
- Name typos: `FCentralManagerDelegate`, `onUnpublichL2CAPChannel`.
- `@available(iOS 5.0/6.0/11.0/13.0)` annotations are all moot at any modern deployment target.
- iOS 17 `centralManager(_:didDisconnectPeripheral:timestamp:isReconnecting:error:)` variant isn't covered.
- Closures are not `@Sendable`, which will fail under Swift 6 strict concurrency (the new package already declares `swiftLanguageModes: [.v6]`).

## Goals

1. Extract and modernize the CoreBluetooth closure-shim wrappers into a standalone Swift Package with zero external dependencies.
2. Add a separate layer that exposes the same functionality as TCA `@DependencyClient` clients with Sendable value types and `AsyncStream`-based event observation.
3. Both layers ship as separate SwiftPM products so non-TCA consumers don't pay the TCA dependency cost.
4. Target iOS 17+ throughout; no `@available` annotations in the public API.
5. Cover the central side gap with a new `CBPeripheralDelegate` closure wrapper.

## Non-goals

- Backwards compatibility with the existing `fuikit` `FCB` classes. Consumers migrate to the new API; there is no compatibility shim. (The packages are independent — fuikit's classes continue to exist in fuikit until its consumers migrate.)
- A `CBPeripheralManager` subclass that hooks outgoing method calls. The original's pattern is unusual and not needed for the TCA layer; dropped in favor of a delegate-only design.
- End-to-end integration tests against real BLE hardware. The package ships unit tests only.

## Architecture

### Package layout

```
FCB/
├── Package.swift
├── Sources/
│   ├── FCB/                        # Layer 1: closure-shim
│   │   ├── FCBCentralManagerDelegate.swift
│   │   ├── FCBPeripheralDelegate.swift
│   │   └── FCBPeripheralManagerDelegate.swift
│   └── FCBComposable/              # Layer 2: TCA
│       ├── Models/                 # Sendable value types
│       │   ├── Peripheral.swift
│       │   ├── DiscoveredPeripheral.swift
│       │   ├── AdvertisementData.swift
│       │   ├── Service.swift
│       │   ├── Characteristic.swift
│       │   ├── Central.swift
│       │   ├── ReadRequest.swift
│       │   ├── WriteRequest.swift
│       │   └── MutableService.swift
│       ├── Events/                 # Delegate-event enums (escape hatches)
│       │   ├── CentralEvent.swift
│       │   ├── PeripheralEvent.swift
│       │   └── PeripheralManagerEvent.swift
│       ├── Errors/
│       │   └── BluetoothError.swift
│       ├── BluetoothCentralClient.swift
│       └── BluetoothPeripheralClient.swift
└── Tests/
    ├── FCBTests/
    └── FCBComposableTests/
```

### `Package.swift`

Two products, two targets. iOS 17 minimum.

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

### Dependency flow

`FCBComposable` depends on `FCB`. Each `Bluetooth…Client.liveValue` is backed by a private actor that internally owns a `CBCentralManager` or `CBPeripheralManager`, sets the manager's delegate to an FCB delegate instance from Layer 1, and rewires those closures into `AsyncStream.Continuation`s and pending `CheckedContinuation`s for the role-based methods.

## Layer 1 — `FCB` (closure-shim)

Three `open class … : NSObject, CB…Delegate` types. Every closure property is `@Sendable`. No `@available` annotations.

### `FCBCentralManagerDelegate`

Closure properties (one per `CBCentralManagerDelegate` method):

- `onDidUpdateState: (@Sendable (CBCentralManager) -> Void)?`
- `onWillRestoreState: (@Sendable (CBCentralManager, [String: Any]) -> Void)?`
- `onDidDiscover: (@Sendable (CBCentralManager, CBPeripheral, [String: Any], NSNumber) -> Void)?`
- `onDidConnect: (@Sendable (CBCentralManager, CBPeripheral) -> Void)?`
- `onDidFailToConnect: (@Sendable (CBCentralManager, CBPeripheral, (any Error)?) -> Void)?`
- `onDidDisconnect: (@Sendable (CBCentralManager, CBPeripheral, (any Error)?) -> Void)?` — the pre-iOS-17 callback.
- `onDidDisconnectWithTimestamp: (@Sendable (CBCentralManager, CBPeripheral, CFAbsoluteTime, Bool, (any Error)?) -> Void)?` — the iOS 17+ callback.
- `onConnectionEventDidOccur: (@Sendable (CBCentralManager, CBConnectionEvent, CBPeripheral) -> Void)?`
- `onDidUpdateANCSAuthorization: (@Sendable (CBCentralManager, CBPeripheral) -> Void)?`

### `FCBPeripheralDelegate` (new — fills the gap)

Covers every `CBPeripheralDelegate` callback:

- `onDidUpdateName`
- `onDidModifyServices`
- `onDidReadRSSI`
- `onDidDiscoverServices`
- `onDidDiscoverIncludedServices`
- `onDidDiscoverCharacteristics`
- `onDidDiscoverDescriptors`
- `onDidUpdateValueForCharacteristic`
- `onDidUpdateValueForDescriptor`
- `onDidWriteValueForCharacteristic`
- `onDidWriteValueForDescriptor`
- `onDidUpdateNotificationState`
- `onIsReadyToSendWriteWithoutResponse`
- `onDidOpenL2CAPChannel`

### `FCBPeripheralManagerDelegate`

Covers every `CBPeripheralManagerDelegate` callback including the iOS 13 `didOpen: CBL2CAPChannel?` callback the original explicitly skipped:

- `onDidUpdateState`
- `onWillRestoreState`
- `onDidStartAdvertising`
- `onDidAddService`
- `onDidSubscribeToCharacteristic`
- `onDidUnsubscribeFromCharacteristic`
- `onDidReceiveRead`
- `onDidReceiveWrite`
- `onIsReadyToUpdateSubscribers`
- `onDidPublishL2CAPChannel`
- `onDidUnpublishL2CAPChannel`
- `onDidOpenL2CAPChannel`

### Conventions

- All public types `open` for subclassing.
- Naming cleaned: `FCentral…` → `FCBCentral…`, `onUnpublich…` → `onUnpublish…`, `onDidDiscoverPeripheralAdAndRSSI` → `onDidDiscover`.
- Single-line `open class` declarations; closures default to `nil`; every protocol method calls its corresponding optional closure with the delegate arguments.

## Layer 2 — `FCBComposable`

### Sendable value types

All structs, `Sendable`, `Identifiable` by `UUID` or `CBUUID` where applicable, `Equatable`, `Hashable`. CoreBluetooth types that are already `Sendable` (`CBUUID`, `CBCharacteristicProperties`, `CBManagerState`, `CBManagerAuthorization`, `CBConnectionEvent`, `CBATTError.Code`, `CBCharacteristicWriteType`) are exposed directly; non-`Sendable` CoreBluetooth types (`CBPeripheral`, `CBService`, `CBCharacteristic`, `CBCentral`, `CBATTRequest`) are wrapped.

- `Peripheral` — `id: UUID`, `name: String?`, `state: ConnectionState`.
- `ConnectionState` — enum: `.disconnected`, `.connecting`, `.connected`, `.disconnecting`.
- `DiscoveredPeripheral` — `peripheral: Peripheral`, `advertisementData: AdvertisementData`, `rssi: Int`.
- `AdvertisementData` — typed wrapper around CoreBluetooth's `[String: Any]` dictionary: `localName`, `serviceUUIDs`, `manufacturerData`, `txPowerLevel`, `isConnectable`, `solicitedServiceUUIDs`, `serviceData: [CBUUID: Data]`, `overflowServiceUUIDs`.
- `Service` — `id: CBUUID`, `peripheralID: UUID`, `isPrimary: Bool`.
- `Characteristic` — `id: CBUUID`, `serviceID: CBUUID`, `peripheralID: UUID`, `properties: CBCharacteristicProperties`, `value: Data?`, `isNotifying: Bool`.
- `Central` — `id: UUID`, `maximumUpdateValueLength: Int`.
- `ReadRequest` — `id: UUID` (assigned by the live client; used by `respond` to resolve back to the underlying `CBATTRequest`), `central: Central`, `characteristic: Characteristic`, `offset: Int`.
- `WriteRequest` — same shape as `ReadRequest` plus `value: Data?`.
- `MutableService` — input type for `BluetoothPeripheralClient.add`: `id: CBUUID`, `isPrimary: Bool`, `characteristics: [MutableCharacteristic]`.
- `MutableCharacteristic` — `id: CBUUID`, `properties: CBCharacteristicProperties`, `permissions: CBAttributePermissions`, `value: Data?`.
- `RestorationState` — Sendable wrapper around CoreBluetooth's restoration dictionaries.

### Event enums (escape hatches from Question 5)

Three enums, all `Sendable`. Every payload uses the value types above — no `CB*` types leak into the public events.

- `CentralEvent` — one case per `CBCentralManagerDelegate` callback.
- `PeripheralEvent` — one case per `CBPeripheralDelegate` callback.
- `PeripheralManagerEvent` — one case per `CBPeripheralManagerDelegate` callback.

Each event carries the relevant value types plus a `BluetoothError?` where CoreBluetooth provides an error.

### `BluetoothError`

```swift
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
```

Conversion rule: every `Error?` coming out of CoreBluetooth flows through `BluetoothError(_:)`, which classifies by domain/code and falls back to `.underlying`. The public API never exposes raw `Error` — only `BluetoothError`. `NSError` is `Sendable`, so wrapping it is safe under strict concurrency.

Pre-flight checks: before performing any operation the live actor inspects `CBCentralManager.state`/`CBPeripheralManager.state` and throws `.poweredOff` / `.unsupported` / `.unauthorized(…)` synchronously rather than waiting on a delegate callback that won't fire.

### `BluetoothCentralClient`

Witness-style struct generated by TCA's `@DependencyClient` macro. All closures `@Sendable`. Defaults use `unimplemented` so missing test wiring fails loudly.

```swift
@DependencyClient
public struct BluetoothCentralClient: Sendable {
    public var state: @Sendable () -> AsyncStream<CBManagerState> = { .never }
    public var authorization: @Sendable () -> CBManagerAuthorization = { .notDetermined }

    public var scan: @Sendable (_ services: [CBUUID]?, _ options: ScanOptions?) -> AsyncStream<DiscoveredPeripheral> = { _, _ in .never }
    public var stopScan: @Sendable () async -> Void

    public var connect: @Sendable (_ id: Peripheral.ID, _ options: ConnectOptions?) async throws -> Peripheral
    public var disconnect: @Sendable (_ id: Peripheral.ID) async throws -> Void
    public var retrievePeripherals: @Sendable (_ ids: [UUID]) async -> [Peripheral]
    public var retrieveConnected: @Sendable (_ services: [CBUUID]) async -> [Peripheral]

    public var discoverServices: @Sendable (_ peripheralID: UUID, _ serviceIDs: [CBUUID]?) async throws -> [Service]
    public var discoverCharacteristics: @Sendable (_ peripheralID: UUID, _ serviceID: CBUUID, _ characteristicIDs: [CBUUID]?) async throws -> [Characteristic]

    public var readValue: @Sendable (_ peripheralID: UUID, _ characteristicID: CBUUID) async throws -> Data
    public var writeValue: @Sendable (_ data: Data, _ peripheralID: UUID, _ characteristicID: CBUUID, _ type: CBCharacteristicWriteType) async throws -> Void
    public var setNotify: @Sendable (_ enabled: Bool, _ peripheralID: UUID, _ characteristicID: CBUUID) async throws -> Void
    public var notifications: @Sendable (_ peripheralID: UUID, _ characteristicID: CBUUID) -> AsyncThrowingStream<Data, any Error> = { _, _ in .finished() }

    public var events: @Sendable () -> AsyncStream<CentralEvent> = { .never }
}
```

`ScanOptions` and `ConnectOptions` are Sendable structs wrapping the corresponding CoreBluetooth dictionary keys (allow duplicates, notify on connection, etc.).

### `BluetoothPeripheralClient`

```swift
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
```

`SubscriptionEvent` is `.subscribed(Central, Characteristic)` / `.unsubscribed(Central, Characteristic)`.

### `DependencyKey` conformance & implementations

Each client provides:

- `liveValue` — real implementation backed by an internal `actor` that owns the `CBCentralManager` / `CBPeripheralManager`, the Layer 1 FCB delegate (closures wired into `AsyncStream.Continuation`s), per-operation `[KeyType: CheckedContinuation]` maps for `async throws` methods, and resolution maps `[UUID: CBPeripheral]`, `[UUID: CBATTRequest]`, `[CBUUID: CBCharacteristic]`, etc.
- `testValue` — the macro-generated zero-arg init that returns `unimplemented` closures.
- `previewValue` — a static mock with a fixed set of fake peripherals, instant successful connects, canned characteristic data, no real CoreBluetooth involvement.

### Pending-operation pattern

Inside the actor, methods that need to suspend until a delegate callback fires:

```swift
private var pendingDiscoverServices: [UUID: CheckedContinuation<[Service], any Error>] = [:]

func discoverServices(peripheralID: UUID, serviceIDs: [CBUUID]?) async throws -> [Service] {
    guard let cb = peripherals[peripheralID] else { throw BluetoothError.unknownPeripheral(peripheralID) }
    return try await withCheckedThrowingContinuation { cont in
        pendingDiscoverServices[peripheralID] = cont
        cb.discoverServices(serviceIDs)
    }
}

// inside the FCBPeripheralDelegate.onDidDiscoverServices closure (Task-hopped into the actor):
if let cont = pendingDiscoverServices.removeValue(forKey: peripheralID) {
    if let error { cont.resume(throwing: BluetoothError(error)) }
    else { cont.resume(returning: cb.services?.map(Service.init) ?? []) }
}
```

Same pattern for `connect`, `discoverCharacteristics`, `readValue`, `writeValue` (response type), `setNotify`. Concurrent reads on different characteristics are keyed by `CBUUID` (no clobbering). Concurrent reads on the *same* characteristic are not supported — CoreBluetooth itself doesn't support overlapping reads on one characteristic; the second call throws `.operationCancelled` immediately if a pending read already exists.

## Testing strategy

### Layer 1 (`FCBTests`) — closure-shim unit tests

Pure synchronous tests. Pattern: instantiate the delegate, assign a recording closure, invoke the protocol method directly, assert the closure ran with the expected arguments. One test per closure on each of the three delegate wrappers (~30 tests total). No `@MainActor`, no real BLE.

```swift
@Test func centralDelegateForwardsDidConnect() {
    let sut = FCBCentralManagerDelegate()
    var captured: (CBCentralManager, CBPeripheral)?
    sut.onDidConnect = { c, p in captured = (c, p) }
    let manager = CBCentralManager()
    let peripheral = MockPeripheral()
    sut.centralManager(manager, didConnect: peripheral)
    #expect(captured?.1 === peripheral)
}
```

### Layer 2 (`FCBComposableTests`) — three categories

1. **Value-type conversion tests.** `AdvertisementData(from: [String: Any])`, `Peripheral(from: CBPeripheral)`, `BluetoothError(_: NSError)` mapping. Pure functions; one test per input shape.

2. **Client contract tests using `testValue`.** Verify that calling an unimplemented closure on `BluetoothCentralClient()` / `BluetoothPeripheralClient()` fails the test (sanity check on the macro and on the `testValue` definition).

3. **Live-client behavior tests using a fake CB layer.** The live actor depends on a narrow internal protocol — `CentralManaging` / `PeripheralManaging` — with the production conformance being `CBCentralManager` and a test conformance being a hand-rolled fake that lets tests drive delegate callbacks deterministically. Tests cover:
   - `connect(id:)` resolves when `onDidConnect` fires.
   - `connect(id:)` throws `.connectionFailed` when `onDidFailToConnect` fires.
   - `discoverServices` throws `.unknownPeripheral` if the ID isn't in the map.
   - `scan()` stream yields advertised peripherals.
   - `notifications(…)` stream finishes when the characteristic is unsubscribed.
   - Pre-flight check throws `.poweredOff` synchronously when state is `.poweredOff`.
   - Concurrent reads on different characteristics don't clobber each other's continuations.

### Verification discipline

Every new or modified test follows the three-step protocol from the user-level `CLAUDE.md`:

a. Run tests → all green.
b. Batch-mutate the production code under test in meaningful ways (invert returns, drop guards, force-throw — not just syntax breaks) → confirm all targeted tests fail in one run.
c. Revert all mutations → confirm all green again.

Only after step (c) is the test set safe to commit.

### CoreBluetooth instantiation in tests

`CBPeripheral` has no public initializer and `CBCentralManager()` triggers permission prompts. The implementation plan resolves this with one of: (a) Objective-C runtime tricks to mint bare `CBPeripheral` instances, (b) a thin internal protocol that the delegate wrappers' tests can satisfy with plain stub classes, or (c) accepting that some forwarding tests assert closure invocation only (without inspecting the forwarded arguments). Decision deferred to the plan because it affects only test scaffolding, not the public API.

### Out of scope

- End-to-end tests against real BLE hardware. The package ships unit tests only.
- Integration tests of TCA Reducers using the clients. Those belong in consuming apps.

## Open decisions deferred to implementation

- Exact actor isolation strategy for the live client (single internal actor vs. `@MainActor`). Will be decided when wiring `CBCentralManager` initialization with a queue parameter.
- Concrete shape of the `CentralManaging` / `PeripheralManaging` internal protocols. Designed during test-writing — surface is dictated by what the actor actually calls on the manager.
- Whether `previewValue` lives in its own file (`BluetoothCentralClient+Preview.swift`) or alongside the client definition. Cosmetic.
