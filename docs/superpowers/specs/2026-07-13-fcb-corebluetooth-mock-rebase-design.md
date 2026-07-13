# FCB: Rebase FCBComposable on CoreBluetooth Mock — Design

**Date:** 2026-07-13
**Status:** Approved

## Goal

Rebase the internals of `FCBComposable` on Nordic's [IOS-CoreBluetooth-Mock](https://github.com/NordicSemiconductor/IOS-CoreBluetooth-Mock) (CBM) so that the single production code path can run against either real CoreBluetooth (on device) or a scripted mock peripheral (in unit/integration tests and the iOS Simulator). CBM is designed for exactly this: `CBMCentralManagerNative` transparently forwards to real CoreBluetooth, while `CBMCentralManagerMock` runs against `CBMPeripheralSpec` simulations.

Motivating consumer: the Meshtastified app (spec: `2026-07-13-meshtastic-mvp-design.md` in the Meshtastified repo) needs integration tests where its protocol layer runs through FCB's real `CentralActor` against a scripted Meshtastic radio, and a working Simulator experience.

## Current state

- `CentralActor` (in `BluetoothCentralClient+Live.swift`) depends on internal protocols:
  - `CentralManaging` — satisfied by `CBCentralManager`; methods take/return `CBPeripheral`.
  - `PeripheralConnection` — satisfied by `CBPeripheral`; methods take `CBService`/`CBCharacteristic`.
- Delegate wiring uses Layer 1's `FCBCentralManagerDelegate` / `FCBPeripheralDelegate` (closure wrappers typed on real CB delegate protocols).
- Layer 2 tests inject `FakeCentralManager` / `FakePeripheralConnection` and stub un-instantiable CB types via ObjC-runtime tricks (`class_createInstance`, `Unmanaged.passRetained`).

## Design

### Scope

Only `FCBComposable` changes. The `FCB` Layer 1 target (plain CB delegate wrappers) stays untouched and CB-typed — peripheral-role code (`BluetoothPeripheralClient`) is out of scope because CBM has no peripheral-manager mock and Meshtastified only needs the central role.

### Type migration (mechanical)

Within `FCBComposable`'s central-role internals, replace CB types with their CBM mirrors:

- `CentralManaging` and `PeripheralConnection` are **deleted**: `CentralActor` holds a `CBMCentralManager` and `any CBMPeripheral` values directly. CBM is itself the abstraction (native passthrough vs. mock), so the internal protocols would duplicate it — and CBM's concrete peripheral classes are internal to CBM, so retrofitting conformances onto them isn't possible anyway. Tests drive the real actor through `CBMCentralManagerMock` + `CBMPeripheralSpec` instead of injected fakes.
- `CBManagerState` ↔ `CBMManagerState` etc. are typealiases or trivially bridged; public API types (`CBUUID`, `CBCharacteristicWriteType`, `CBManagerState`, `CBManagerAuthorization`) remain CoreBluetooth types so **the public `BluetoothCentralClient` surface is unchanged**. CBM uses `CBMUUID`/write-type typealiases that bridge to the CB equivalents.

### Delegate wrappers

Layer 1's `FCBCentralManagerDelegate`/`FCBPeripheralDelegate` are typed on real CB protocols and cannot serve CBM. Add CBM-flavored closure wrappers **internal to FCBComposable**:

- `internal final class FCBMCentralManagerDelegate: CBMCentralManagerDelegate` — same closure-per-callback pattern as Layer 1.
- `internal final class FCBMPeripheralDelegate: CBMPeripheralDelegate` — likewise.

Keeping them internal avoids committing to a public CBM-typed API and leaves Layer 1's role (public CB closure wrappers) intact.

### Manager creation and the mock seam

- `liveValue` creates its manager via `CBMCentralManagerFactory.instance(forceMock: false)` — native passthrough in production, mock when the process has called `CBMCentralManagerMock.simulatePeripherals(_:)` and forced mock.
- Add a public entry point so consumers can build a client for a simulated environment, e.g.:

```swift
extension BluetoothCentralClient {
  /// A live client backed by CBMCentralManagerMock. The caller configures
  /// CBMCentralManagerMock.simulate… / simulatePeripherals(_:) beforehand.
  public static func mocked() -> BluetoothCentralClient
}
```

Consumers (tests, Simulator builds) script `CBMPeripheralSpec`s with CBM's own API and pass state via `CBMCentralManagerMock.simulateInitialState(.poweredOn)`; FCB does not wrap or re-export CBM's simulation API.

### Dependency

`Package.swift`: `FCBComposable` gains `.package(url: "https://github.com/NordicSemiconductor/IOS-CoreBluetooth-Mock.git", from: "1.0.0")` → product `CoreBluetoothMock`. `FCB` and `FCBComposable`'s public API gain no CBM exposure beyond the `mocked()` factory.

### Tests

- Existing Layer 2 central-role tests keep their intent but migrate from injected fakes (`FakeCentralManager`, fake connections — deleted) to driving the real actor through `CBMCentralManagerMock` + scripted `CBMPeripheralSpec`s, which **removes** the ObjC-runtime stubbing (`class_createInstance` / `object_setIvar`) for the central role. CBM's simulation is process-global, so all CBM-touching tests nest in one serialized suite.
- Add one end-to-end test: `BluetoothCentralClient.mocked()` against a trivial `CBMPeripheralSpec` (advertise → scan → connect → discover → write → notify round-trip), proving the CBM seam works through the real `CentralActor`.
- Layer 1 tests and peripheral-role tests are unchanged.

## Acceptance criteria

- `swift build` and `swift test` pass on the macOS host.
- Public `BluetoothCentralClient` API unchanged for existing consumers (the demo app still compiles).
- New `mocked()` client passes the end-to-end CBM spec test.
- No ObjC-runtime stubbing remains in central-role Layer 2 tests.

## Out of scope

- Peripheral role (`BluetoothPeripheralClient`) — CBM offers no peripheral-manager mock.
- Wrapping/re-exporting CBM's simulation API.
- Any Layer 1 (`FCB` target) changes.
- State restoration support.
