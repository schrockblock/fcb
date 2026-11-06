# FCB

FCB is a Swift package that wraps Apple's CoreBluetooth framework in two layers:

- **`FCB`** turns the three CoreBluetooth delegate protocols into objects with closure properties, so you can handle Bluetooth callbacks without writing a delegate class.
- **`FCBComposable`** builds on that to give you async/await clients for the central and peripheral roles, packaged as dependencies for [The Composable Architecture](https://github.com/pointfreeco/swift-composable-architecture) (TCA). Callbacks become `async` functions and `AsyncStream`s, CoreBluetooth objects become `Sendable` value types, and tests can swap in a simulated Bluetooth stack.

It is written for Swift 6 with strict concurrency checking. It provides the Bluetooth layer for a Swift implementation of the Reticulum network stack (over BLE and L2CAP) and for a Meshtastic client library.

## The problem it solves

CoreBluetooth reports everything through delegate callbacks on objects that are not `Sendable`. In a Swift 6 codebase that means hand-written delegate classes, continuations to bridge into `async` code, bookkeeping for which callback answers which request, and no good way to unit-test code that talks to a radio.

`FCBComposable` does that bookkeeping once, inside an actor per role:

- `connect`, `discoverServices`, `readValue`, `writeValue` and the rest are `async throws` calls that return when CoreBluetooth answers.
- Scan results, notifications, state changes and incoming requests are `AsyncStream`s.
- A disconnect, or Bluetooth turning off, fails every operation still waiting on that peripheral instead of leaving it hanging.
- Peripherals, services, characteristics and requests are passed around as `Sendable` structs identified by `UUID` and `CBUUID`, never as CoreBluetooth objects.
- The clients are TCA dependencies (`@Dependency(\.bluetoothCentralClient)`), so tests and SwiftUI previews can replace any endpoint with a closure.

If you don't use TCA, the `FCB` product on its own has no dependencies.

## Requirements

- Swift 6.3 toolchain (`swift-tools-version: 6.3`, Swift 6 language mode)
- iOS 17 or later, macOS 13 or later

Dependencies of `FCBComposable` (`FCB` has none):

- [swift-composable-architecture](https://github.com/pointfreeco/swift-composable-architecture) 1.0.0 or later
- [IOS-CoreBluetooth-Mock](https://github.com/NordicSemiconductor/IOS-CoreBluetooth-Mock) (Nordic Semiconductor) 1.0.0 or later

## Installation

Add the package with Swift Package Manager. There are no tagged releases yet, so depend on a branch or a commit:

```swift
// Package.swift
dependencies: [
    .package(url: "https://github.com/schrockblock/fcb", branch: "main"),
    // or over SSH: .package(url: "git@github.com:schrockblock/fcb.git", branch: "main"),
],
targets: [
    .target(
        name: "MyApp",
        dependencies: [
            .product(name: "FCBComposable", package: "fcb"),
            // or, for the dependency-free delegate wrappers only:
            // .product(name: "FCB", package: "fcb"),
        ]
    ),
]
```

In Xcode, use File > Add Package Dependencies and enter `https://github.com/schrockblock/fcb`.

## Products

| Product | What it contains | Depends on |
|---|---|---|
| `FCB` | `FCBCentralManagerDelegate`, `FCBPeripheralDelegate`, `FCBPeripheralManagerDelegate`: `open` classes that implement the CoreBluetooth delegate protocols and forward each callback to an optional `@Sendable` closure property. | CoreBluetooth only |
| `FCBComposable` | `BluetoothCentralClient`, `BluetoothPeripheralClient`, the value types they use (`Peripheral`, `Service`, `Characteristic`, `DiscoveredPeripheral`, `AdvertisementData`, `ReadRequest`, `WriteRequest`, `L2CAPConnection`, ...), event enums (`CentralEvent`, `PeripheralManagerEvent`) and `BluetoothError`. | `FCB`, ComposableArchitecture, CoreBluetoothMock |

## Usage

### Central role: scan, connect, subscribe

A TCA reducer that finds a heart-rate monitor and streams its readings:

```swift
import ComposableArchitecture
import CoreBluetooth
import FCBComposable

let heartRateService = CBUUID(string: "180D")
let heartRateMeasurement = CBUUID(string: "2A37")

@Reducer
struct HeartRateFeature {
    @ObservableState
    struct State: Equatable {
        var deviceName: String?
        var lastReading: Data?
        var error: String?
    }

    enum Action {
        case startTapped
        case connected(Peripheral)
        case reading(Data)
        case failed(String)
    }

    @Dependency(\.bluetoothCentralClient) var bluetooth

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .startTapped:
                return .run { send in
                    // Wait for the radio to power on.
                    for await radio in bluetooth.state() where radio == .poweredOn { break }

                    // Take the first peripheral advertising the service.
                    // Leaving the loop ends the stream, which stops this scan.
                    var found: DiscoveredPeripheral?
                    for await discovered in bluetooth.scan([heartRateService], nil) {
                        found = discovered
                        break
                    }
                    guard let id = found?.peripheral.id else { return }

                    let peripheral = try await bluetooth.connect(id, nil)
                    await send(.connected(peripheral))

                    _ = try await bluetooth.discoverServices(id, [heartRateService])
                    _ = try await bluetooth.discoverCharacteristics(id, heartRateService, [heartRateMeasurement])
                    try await bluetooth.setNotify(true, id, heartRateMeasurement)

                    for try await value in bluetooth.notifications(id, heartRateMeasurement) {
                        await send(.reading(value))
                    }
                } catch: { error, send in
                    await send(.failed("\(error)"))
                }

            case let .connected(peripheral):
                state.deviceName = peripheral.name
                return .none

            case let .reading(data):
                state.lastReading = data
                return .none

            case let .failed(message):
                state.error = message
                return .none
            }
        }
    }
}
```

Characteristics are addressed by peripheral `UUID` plus characteristic `CBUUID`. You must discover a characteristic before you read, write or subscribe to it.

`BluetoothCentralClient` endpoints:

| Group | Endpoints |
|---|---|
| Radio | `state()`, `authorization()`, `events()` |
| Scanning | `scan(services, options)`, `stopScan()` (does nothing; see below) |
| Connections | `connect(id, options)`, `disconnect(id)`, `retrievePeripherals(ids)`, `retrieveConnected(services)` |
| GATT | `discoverServices`, `discoverCharacteristics`, `readValue`, `writeValue`, `setNotify`, `notifications`, `maximumWriteValueLength`, `canSendWriteWithoutResponse` |
| L2CAP | `openL2CAPChannel(id, psm)` |

### Peripheral role: publish a service and advertise

```swift
import ComposableArchitecture
import CoreBluetooth
import FCBComposable

let echoService = CBUUID(string: "6E400001-B5A3-F393-E0A9-E50E24DCCA9E")
let echoCharacteristic = CBUUID(string: "6E400002-B5A3-F393-E0A9-E50E24DCCA9E")

func runEchoPeripheral() async throws {
    @Dependency(\.bluetoothPeripheralClient) var peripheral

    for await radio in peripheral.state() where radio == .poweredOn { break }

    _ = try await peripheral.add(MutableService(
        id: echoService,
        isPrimary: true,
        characteristics: [
            MutableCharacteristic(
                id: echoCharacteristic,
                properties: [.write, .notify],
                permissions: [.writeable],
                value: nil
            )
        ]
    ))
    try await peripheral.startAdvertising(AdvertisementData(localName: "Echo", serviceUUIDs: [echoService]))

    // Answer every write, then notify subscribers with the same bytes.
    for await batch in peripheral.writeRequests() {
        for request in batch {
            await peripheral.respond(request.id, .success)
            if let value = request.value {
                _ = try await peripheral.updateValue(value, echoCharacteristic, nil)
            }
        }
    }
}
```

`BluetoothPeripheralClient` endpoints:

| Group | Endpoints |
|---|---|
| Radio | `state()`, `authorization()`, `events()` |
| Services | `add(service)`, `remove(serviceID)`, `removeAll()` |
| Advertising | `startAdvertising(data)`, `stopAdvertising()`, `isAdvertising()` |
| Requests | `readRequests()`, `writeRequests()`, `subscriptions()`, `respond(requestID, result)`, `updateValue(data, characteristicID, centralIDs)` |
| L2CAP | `publishL2CAPChannel(withEncryption)`, `unpublishL2CAPChannel(psm)`, `l2capConnections()` |

`updateValue` returns CoreBluetooth's `Bool`: `false` means the transmit queue is full; wait for `.isReadyToUpdateSubscribers` on `events()` and try again.

### L2CAP channels

Both roles produce an `L2CAPConnection`, a handle with an `incoming()` byte stream, `send(_:)` and `close()`. A peripheral publishes a channel and receives connections on `l2capConnections()`; a central opens one with `openL2CAPChannel(peripheralID, psm)`. `incoming()` has a single consumer: the first call gets the live stream, later calls get a finished one. When the channel closes from either side, `incoming()` finishes. That is the only signal you get.

### Layer 1: closure delegates without TCA

```swift
import CoreBluetooth
import FCB

final class Scanner {
    private let delegate = FCBCentralManagerDelegate()
    private let manager: CBCentralManager

    init() {
        delegate.onDidUpdateState = { central in
            if central.state == .poweredOn {
                central.scanForPeripherals(withServices: nil)
            }
        }
        delegate.onDidDiscover = { _, peripheral, advertisementData, rssi in
            print(peripheral.identifier, advertisementData[CBAdvertisementDataLocalNameKey] ?? "-", rssi)
        }
        manager = CBCentralManager(delegate: delegate, queue: nil)
    }
}
```

CoreBluetooth holds its delegate weakly, so keep a strong reference to the `FCB...Delegate` object. The classes are `open`, so you can subclass them and override a callback directly.

## Behavior to know about

These rules are enforced by `FCBComposable` and covered by its tests.

- **One scan per client.** A new `scan` replaces the current one and finishes the older stream. To stop a scan, end its stream: cancel the task iterating it, or drop it. `stopScan()` does nothing and exists only for source compatibility. A scan requested while Bluetooth is not powered on finishes immediately.
- **Disconnects fail pending work.** When a peripheral disconnects or fails to connect, every operation still waiting on it throws `BluetoothError.disconnected` (or `.connectionFailed`), and its `notifications` streams finish with that error.
- **Bluetooth turning off fails everything.** When the adapter leaves `.poweredOn`, every pending operation fails (`.poweredOff`, `.unsupported` or `.unauthorized`), all notification and scan streams finish, and the client forgets all peripherals. Discover services and characteristics again after reconnecting.
- **One pending call per slot.** CoreBluetooth cannot tell two concurrent requests for the same thing apart. A second `connect`, `discoverServices`, `discoverCharacteristics`, write-with-response or `setNotify` for the same peripheral, service or characteristic fails the first caller with `.operationCancelled`. A second `readValue` or `openL2CAPChannel` while one is pending is rejected instead. If you need an outcome for each call, serialize your calls.
- **Write-without-response flow control.** Check `canSendWriteWithoutResponse(id)` before writing, and when it returns `false`, wait for `CentralEvent.isReadyToSendWriteWithoutResponse` on `events()`.
- **Shared managers.** Each client's `liveValue` creates one CoreBluetooth manager for the whole process the first time it is accessed. Creating it can trigger the system Bluetooth permission prompt.

Errors are `BluetoothError`, which sorts CoreBluetooth `NSError`s by domain into cases like `.att(CBATTError.Code)` and `.operationCancelled`, with `.underlying(NSError)` for everything else.

## Testing

Each client comes with three values:

- **`testValue`** is generated by `@DependencyClient`. If a test calls an endpoint it hasn't overridden, the test fails (throwing endpoints also throw), so each test overrides only the endpoints it expects to use.
- **`previewValue`** is a canned client for SwiftUI previews. Both roles report `.poweredOn` and succeed at almost every operation. The central finds one "Preview Device", and its `openL2CAPChannel` throws.
- **`BluetoothCentralClient.mocked()`** is the real central implementation running on Nordic's [CoreBluetoothMock](https://github.com/NordicSemiconductor/IOS-CoreBluetooth-Mock) instead of the radio. You describe simulated peripherals with `CBMPeripheralSpec`, and scanning, connecting, discovery, reads, writes and notifications all go through the same actor code that runs on a device. Use it for integration tests, or to run in the iOS Simulator, which has no Bluetooth.

Overriding endpoints in a TCA `TestStore`:

```swift
let device = Peripheral(id: UUID(), name: "Strap", state: .connected)
let store = TestStore(initialState: HeartRateFeature.State()) {
    HeartRateFeature()
} withDependencies: {
    $0.bluetoothCentralClient.state = { AsyncStream { $0.yield(.poweredOn) } }
    $0.bluetoothCentralClient.scan = { _, _ in
        AsyncStream {
            $0.yield(DiscoveredPeripheral(peripheral: device, advertisementData: AdvertisementData(), rssi: -50))
        }
    }
    $0.bluetoothCentralClient.connect = { _, _ in device }
    $0.bluetoothCentralClient.discoverServices = { _, _ in [] }
    $0.bluetoothCentralClient.discoverCharacteristics = { _, _, _ in [] }
    $0.bluetoothCentralClient.setNotify = { _, _, _ in }
    $0.bluetoothCentralClient.notifications = { _, _ in
        AsyncThrowingStream {
            $0.yield(Data([0x00, 72]))
            $0.finish()
        }
    }
}

await store.send(.startTapped)
await store.receive(\.connected) { $0.deviceName = "Strap" }
await store.receive(\.reading) { $0.lastReading = Data([0x00, 72]) }
```

Driving the real central code against a simulated peripheral:

```swift
import CoreBluetoothMock

CBMCentralManagerMock.tearDownSimulation()
CBMCentralManagerMock.simulateInitialState(.poweredOn)
let spec = CBMPeripheralSpec
    .simulatePeripheral(proximity: .near)
    .advertising(
        advertisementData: [
            CBMAdvertisementDataLocalNameKey: "Strap",
            CBMAdvertisementDataServiceUUIDsKey: [CBMUUID(string: "180D")],
            CBMAdvertisementDataIsConnectable: true as NSNumber,
        ],
        withInterval: 0.1
    )
    .build()
CBMCentralManagerMock.simulatePeripherals([spec])

// Set up the simulation before creating the client.
let client = BluetoothCentralClient.mocked()
for await radio in client.state() where radio == .poweredOn { break }

var scan = client.scan([CBUUID(string: "180D")], nil).makeAsyncIterator()
let found = await scan.next()
```

CoreBluetoothMock's simulation is global to the process, so tests that use it must not run in parallel. With Swift Testing, nest them in one `@Suite(.serialized)`, which is what this package does with its own `CBMBackedTests` suite. Add a `.connectable(...)` clause to the spec to simulate services and characteristics. FCB does not wrap CoreBluetoothMock's simulation API; you use it directly.

There is no simulated stack for the peripheral role (CoreBluetoothMock has no peripheral manager), so test peripheral code by overriding `BluetoothPeripheralClient` endpoints.

The package's own tests use Swift Testing and run on macOS:

```sh
swift test
```

## Example app

`Example/` contains FCBDemo, an iOS app built with SwiftUI and TCA that exercises both clients:

- **Central tab:** scan, connect, discover services and characteristics, read, write, and subscribe.
- **Peripheral tab:** build a GATT service, advertise it, and watch a log of incoming read, write and subscription requests.

`Example/FCBDemoFeatures` is a Swift package with the reducers, views and `TestStore` tests, and you can build and test it from the command line:

```sh
swift test --package-path Example/FCBDemoFeatures
```

`Example/FCBDemo.swiftpm` is a Swift Playgrounds app project that wraps it. Open it in Xcode and run it on a physical iPhone or iPad. See [Example/README.md](Example/README.md).

## Permissions and capabilities

FCB does not add any Info.plist keys or entitlements for you.

- **iOS:** `NSBluetoothAlwaysUsageDescription` is required. Your app crashes when it first touches CoreBluetooth if this key is missing.
- **macOS:** `NSBluetoothAlwaysUsageDescription`, plus the `com.apple.security.device.bluetooth` entitlement if the app is sandboxed.
- **Background (iOS):** if you need Bluetooth while the app is in the background, add `bluetooth-central` and/or `bluetooth-peripheral` to `UIBackgroundModes`. FCB doesn't do anything special for background operation. See the state restoration limitation below.

## Known limitations

- **No state restoration in `FCBComposable`.** The live clients create their managers without a restore identifier, so CoreBluetooth never relaunches the app to restore them. The `willRestoreState` cases on `CentralEvent` and `PeripheralManagerEvent` are never emitted. If you need state restoration, create your own manager with the `FCB` delegate wrappers, which do forward `willRestoreState`.
- **Outbound L2CAP is not available on macOS.** On macOS, `openL2CAPChannel` throws `BluetoothError.l2capNotSupported`, because CoreBluetoothMock does not declare that API on macOS. Publishing a channel and accepting inbound connections through the peripheral client works on both iOS and macOS.
- **No L2CAP on the mocked central.** `BluetoothCentralClient.mocked()` throws `.l2capNotSupported` from `openL2CAPChannel`. The outbound central L2CAP path has only been tested on hardware.
- **Read requests can't return a value.** `respond(requestID, result)` only takes an ATT result code, and there is no way to set the response bytes for a `ReadRequest`. For readable characteristics, give `MutableCharacteristic` a static `value`, which CoreBluetooth serves itself and which requires the characteristic to be read-only, or use notifications.
- **Advertising data.** `startAdvertising` sends only `localName` and `serviceUUIDs`, which are the only keys CoreBluetooth allows a peripheral to advertise. Other `AdvertisementData` fields are ignored.
- **iBeacon** advertising is not supported.
- **One live manager per role.** Every use of `liveValue` shares one central manager and one peripheral manager, which is why there is only one scan at a time. Each `mocked()` call creates a separate central.
- **No tagged releases yet**, and the API may still change.

## License

No license is specified in this repository.
