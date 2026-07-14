# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build & Test

Swift Package (`swift-tools-version: 6.3`, Swift 6 strict concurrency, iOS 17+ / macOS 13+). Tests use the Swift Testing framework (`import Testing`, `@Test`, `#expect`), not XCTest. Tests run on the macOS dev host.

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

Every callback is exposed as an optional `@Sendable` closure. Subclassable via `open`. Two `CBCentralManagerDelegate` methods (`connectionEventDidOccur` and `didUpdateANCSAuthorizationFor`) are guarded with `#if !os(macOS)` because they're unavailable on macOS.

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

- `BluetoothCentralClient` — `scan`, `connect`, `discoverServices`, `discoverCharacteristics`, `readValue`, `writeValue`, `setNotify`, `notifications`, plus an escape-hatch `events` stream emitting `CentralEvent`.
- `BluetoothPeripheralClient` — `add`/`remove` services, `startAdvertising`/`stopAdvertising`, `respond`, `updateValue`, plus streams for read/write requests, subscriptions, and a unified `events` stream emitting `PeripheralManagerEvent`.

Sendable value types (`Peripheral`, `Service`, `Characteristic`, `Central`, `DiscoveredPeripheral`, `AdvertisementData`, `ReadRequest`, `WriteRequest`, etc.) wrap every non-Sendable CoreBluetooth type. `BluetoothError` classifies CoreBluetooth errors by domain/code (`CBErrorDomain`, `CBATTErrorDomain`) with an `.underlying(NSError)` catch-all.

Each client provides `liveValue`, `testValue` (macro-generated, throws on call), and `previewValue` (canned mock for SwiftUI previews).

## Conventions

- `@preconcurrency import CoreBluetooth` everywhere CB types appear in Sendable contexts. `CBUUID`, `CBCharacteristicProperties`, etc. lack Sendable annotations in the SDK.
- All Layer 2 streams are constructed as `nonisolated` AsyncStream methods that hop into actor isolation via `Task { await actor.register(continuation) }` to register continuations.
- Delegate closures (from the FCB layer) extract Sendable info (UUIDs, value-type Service/Characteristic) synchronously, then call actor-isolated handlers via `Task { await self?.handle…() }`.
- Pending async-throws operations (e.g., `connect`, `discoverServices`) use per-operation `CheckedContinuation` maps inside the actor, keyed by `UUID` or `"\(peripheralUUID):\(characteristicUUID)"` strings.
- `nonisolated(unsafe)` is used in a few places where non-Sendable `CentralManaging`/`PeripheralManaging` need to be read inside an actor (managers are `let` and the read properties are documented as thread-safe).
- `CentralActor` holds a `CBMCentralManager` and `any CBMPeripheral` values directly (no internal manager protocols for the central role); `PeripheralManaging` remains for the peripheral role, with `FakePeripheralManager` in tests. Central-role Layer 2 tests drive the real actor through `CBMCentralManagerMock` + `CBMPeripheralSpec`. Internal CBM closure-delegate wrappers live in `Sources/FCBComposable/Internal/FCBMDelegates.swift`.
- Tests capture `var` into `@Sendable` closures with `nonisolated(unsafe) var …`.
- Layer 1 tests still stub un-instantiable CoreBluetooth types via `class_createInstance` (`Tests/FCBTests/BLETestStub.swift`); peripheral-role Layer 2 tests keep their local stubs. Central-role Layer 2 tests need no stubbing — they use CoreBluetoothMock. CBM's simulation is process-global, so every CBM-touching test nests inside the serialized `CBMBackedTests` parent suite (`Tests/FCBComposableTests/CBMBackedTests.swift`) and starts with `CBMCentralManagerMock.tearDownSimulation()`.

## Origin

Extracted and modernized from `../fuikit/fuikit/Classes/FCB/` (December 2020 code). The original `FCBPeripheralManager` (a `CBPeripheralManager` subclass that hooked outgoing methods) was intentionally dropped — the closure pattern lives at the delegate layer only. The original was also missing a `CBPeripheralDelegate` wrapper; this package adds one. The design spec lives at `docs/superpowers/specs/2026-06-10-fcb-tca-integration-design.md` and the 25-task implementation plan at `docs/superpowers/plans/2026-06-10-fcb-tca-integration.md`.
