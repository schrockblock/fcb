# FCB — L2CAP Channel Support — Design

**Date:** 2026-08-01
**Status:** Approved
**Consumer:** ReTiCA's BLE interface (`../ReTiCA`), whose RBTP v2 data plane is L2CAP CoC.
This is sub-project 1 of 2; sub-project 2 refactors ReTiCA's `BLEDriver.liveValue` to
compose FCB's clients (separate spec in the ReTiCA repo).

## Context

`FCBComposable`'s two clients cover scan/advertise/GATT but expose no L2CAP. The Layer 1
delegate wrappers already carry the L2CAP callbacks (`didPublishL2CAPChannel`,
`didUnpublishL2CAPChannel`, `didOpen channel` on both peripheral-manager and peripheral
delegates), so this slice is purely additive Layer 2 work: L2CAP operations on both
clients, a channel handle type, and a tested stream-pumping engine.

Two platform facts shape the design:

1. **CoreBluetoothMock cannot simulate L2CAP.** `CBMPeripheralMock.openL2CAPChannel`
   is `fatalError("L2CAP mock is not implemented")`. The central-side native passthrough
   works on real hardware; mocked centrals must fail gracefully, not crash.
2. **The peripheral role is real CoreBluetooth behind the internal `PeripheralManaging`
   protocol**, with `FakePeripheralManager` in tests — so peripheral-side L2CAP is fully
   testable by extending the protocol and the fake.

## Public API (FCBComposable)

### `L2CAPConnection` — the channel handle

```swift
/// A live L2CAP connection. Not a model — a capability handle (carries closures),
/// so it is Identifiable but deliberately not Hashable/Equatable.
public struct L2CAPConnection: Sendable, Identifiable {
    public let id: UUID          // FCB-minted handle, unique per connection
    public let peerID: UUID      // remote device identifier (CBL2CAPChannel.peer.identifier)
    public let psm: UInt16
    public var incoming: @Sendable () -> AsyncStream<Data>   // finishes on EOF/error/close
    public var send: @Sendable (Data) async throws -> Void
    public var close: @Sendable () async -> Void             // silent: does NOT finish-with-event
}
```

Semantics:
- `incoming()` yields raw byte chunks as the transport delivers them (no framing — that
  is the consumer's concern). The stream finishes when the channel dies (peer EOF,
  stream error) or after `close()`. Single-consumer: the first call returns the live
  stream; subsequent calls return an immediately-finished stream (matching AsyncStream's
  single-consumption nature rather than pretending to broadcast).
- `send` buffers internally and drains as the output stream has space; it throws only if
  the channel is already closed. (No buffer cap in this slice — parity with the consumer's
  current driver; noted in Out of Scope.)
- `close()` is silent teardown: streams closed and unscheduled, no terminal event beyond
  the `incoming` stream finishing. Matches the "reducer-initiated close has no echo"
  semantic the consumer relies on.

### `BluetoothCentralClient` — one addition

```swift
public var openL2CAPChannel: @Sendable (_ peripheralID: UUID, _ psm: UInt16) async throws -> L2CAPConnection
```

- Requires the peripheral to be connected (same precondition style as
  `discoverServices`); throws `BluetoothError` on CB-level failure.
- On a **mocked** central (CBM mock peripheral), throws the new
  `BluetoothError.l2capNotSupported` instead of hitting CBM's `fatalError` — detected by
  checking the underlying peripheral is not native before calling through.

### `BluetoothPeripheralClient` — three additions

```swift
public var publishL2CAPChannel: @Sendable (_ withEncryption: Bool) async throws -> UInt16  // resolves to the PSM
public var unpublishL2CAPChannel: @Sendable (_ psm: UInt16) async -> Void
public var l2capConnections: @Sendable () -> AsyncStream<L2CAPConnection>                  // inbound channels
```

- `publishL2CAPChannel` resolves when `didPublishL2CAPChannel` fires (CheckedContinuation,
  same pattern as the actor's other pending operations); its error case surfaces as a
  thrown `BluetoothError`.
- Every inbound `didOpen channel` is wrapped in a pump and yielded on `l2capConnections()`.
- `BluetoothError` gains `case l2capNotSupported`.

`@DependencyClient` gives all new entries throwing/unimplemented `testValue`s for free,
matching the existing surface.

## Internals

### `L2CAPChannelPump` (internal)

The stream-pumping engine — a port of ReTiCA's review-hardened `ChannelIO`
(`../ReTiCA/Sources/ReTiCAInterfaces/CoreBluetoothDriver.swift`), which is the proven
reference for the mechanics:

- CFStream dispatch-queue scheduling (`CFReadStreamSetDispatchQueue` /
  `CFWriteStreamSetDispatchQueue`) onto a per-connection serial queue; `StreamDelegate`
  events arrive on that queue.
- Outbound: append to a buffer, drain on `.hasSpaceAvailable`, handle partial writes
  (`maxLength` recomputed per iteration), stop on `written <= 0`.
- Inbound: drain `hasBytesAvailable` in 4096-byte reads → yield `Data` chunks into the
  `incoming` continuation.
- `.errorOccurred` / `.endEncountered` → teardown + finish `incoming`; `close()` →
  same teardown, `finished` flag prevents double-finish; teardown closes both streams
  AND unschedules them from the queue.

**Designed-for-test constructor:** `init(input: InputStream, output: OutputStream,
queue: DispatchQueue)` with a convenience init from `CBL2CAPChannel`. Bound stream pairs
(`Stream.getBoundStreams(withBufferSize:toInputStream:outputStream:)`) drive the pump in
unit tests with no Bluetooth — coverage this code has never had in ReTiCA.

The pump produces the three closures packed into `L2CAPConnection`; `peerID`/`psm` come
from the `CBL2CAPChannel`.

### Central side (`CentralActor`)

- New pending-operation map for `openL2CAPChannel`, keyed by peripheral UUID (same
  CheckedContinuation pattern as `connect`); resolved from the CBM peripheral delegate's
  `didOpen channel` callback (already proxied by the internal FCBM delegate wrappers —
  extend them if the L2CAP callback is not yet wired through).
- Native-vs-mock check before calling through; mock → throw `.l2capNotSupported`.

### Peripheral side (`PeripheralActor` + `PeripheralManaging`)

- `PeripheralManaging` gains `func publishL2CAPChannel(withEncryption: Bool)` and
  `func unpublishL2CAPChannel(_ PSM: CBL2CAPPSM)`; the `CBPeripheralManager` conformance
  is a passthrough.
- The actor: pending continuation for publish (resolved by `didPublishL2CAPChannel` with
  PSM or error), `l2capConnections` continuations registered via the existing
  nonisolated-AsyncStream convention, each `didOpen` wrapped in a pump and yielded.
- `FakePeripheralManager` gains: recorded publish/unpublish calls, a configurable publish
  result (PSM or error), and a `simulateInboundL2CAPChannel(...)` hook taking a stream
  pair + peer UUID + PSM, so tests can inject working inbound channels.
  (CBL2CAPChannel itself cannot be instantiated in tests; the fake path must inject the
  stream pair/metadata directly — the pump's designed-for-test constructor is what makes
  this work, so the actor's channel-wrapping path takes (streams, peerID, psm), not the
  CBL2CAPChannel, with a thin extraction shim at the delegate boundary.)

## Error handling

- All CB errors crossing the client boundary are classified into the existing
  `BluetoothError` taxonomy; `.l2capNotSupported` is the one new case.
- A pump-level stream error is not an API error: it finishes `incoming` (the consumer
  observes channel death), and subsequent `send` throws.

## Testing

All in `Tests/FCBComposableTests`, Swift Testing, existing conventions (serialized
CBM parent suite where CBM is touched):

1. **Pump unit tests** (bound stream pairs, no Bluetooth): round-trip in both
   directions; large payload through a small bound-buffer (forces partial writes +
   multiple drains); EOF finishes `incoming`; `send` after close throws; `close()` is
   silent (no duplicate finish); teardown unschedules (no callbacks after close).
2. **Peripheral client tests** (FakePeripheralManager): `publishL2CAPChannel` resolves
   to the fake's PSM and records encryption flag; publish error → thrown
   `BluetoothError`; `unpublishL2CAPChannel` recorded; simulated inbound channel appears
   on `l2capConnections()` with working round-trip IO over its bound pair.
3. **Central client test** (CBM mocked): `openL2CAPChannel` against a mocked, connected
   peripheral throws `.l2capNotSupported` (graceful, no crash).
4. Existing suites stay green (`swift test` full run).

The user's global mutation-verification discipline applies to every test-bearing task.

## Out of scope

- CBM L2CAP simulation (upstream limitation; central native path is hardware-verified
  via ReTiCA's existing hardware checklist in sub-project 2).
- Outbound write-buffer cap / backpressure signaling (parity with ReTiCA's current
  driver; candidate future work for both).
- Any ReTiCA changes (sub-project 2).
- Demo-app (Example/) coverage of L2CAP; the Example tree currently has unrelated
  uncommitted changes that must not be touched or committed by this work.
