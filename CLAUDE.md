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

### `FCBComposable` (Layer 2, depends on `FCB` + swift-composable-architecture)

TCA `@DependencyClient` clients backed by internal `actor`s:

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
- The actor depends on `CentralManaging` / `PeripheralManaging` / `PeripheralConnection` internal protocols (`Sources/FCBComposable/Internal/`). Production uses CB types directly; tests inject fakes (`FakeCentralManager`, `FakePeripheralManager`, `FakePeripheralConnection`).
- Tests capture `var` into `@Sendable` closures with `nonisolated(unsafe) var …`.
- CoreBluetooth instances that have no public init (`CBPeripheral`, `CBService`, `CBCharacteristic`, etc.) are stubbed in tests via `class_createInstance` from the Objective-C runtime, plus `Unmanaged.passRetained` to leak the stub for the test process's lifetime (avoids KVO dealloc crashes). `CBPeripheral` stubs additionally have a real `NSUUID` injected via `object_setIvar` to make `.identifier` non-crashing. Helpers live in `Tests/FCBTests/BLETestStub.swift` (Layer 1) and `BLETestStubLocal` enums local to the Layer 2 test files.

## Origin

Extracted and modernized from `../fuikit/fuikit/Classes/FCB/` (December 2020 code). The original `FCBPeripheralManager` (a `CBPeripheralManager` subclass that hooked outgoing methods) was intentionally dropped — the closure pattern lives at the delegate layer only. The original was also missing a `CBPeripheralDelegate` wrapper; this package adds one. The design spec lives at `docs/superpowers/specs/2026-06-10-fcb-tca-integration-design.md` and the 25-task implementation plan at `docs/superpowers/plans/2026-06-10-fcb-tca-integration.md`.
