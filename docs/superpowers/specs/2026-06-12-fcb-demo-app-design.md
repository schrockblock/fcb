# FCB Demo App — Design

**Date:** 2026-06-12
**Status:** Approved (pending spec review)

## Background

`FCB` and `FCBComposable` (commit `568c98a` and prior) ship a CoreBluetooth closure-shim layer plus a TCA-integrated layer with role-based `@DependencyClient`s. There is no demo or example app exercising the published API. This spec defines an iOS SwiftUI + TCA demo app, **FCBDemo**, that exercises the full surface of both clients (central + peripheral roles, GATT server configuration, advertising, request handling) and serves as a reference for consumers.

iBeacon advertising was considered and dropped: the package does not handle iBeacon (it would require a `CLBeaconRegion`-derived advertisement dictionary that bypasses `AdvertisementData`), so adding it to the demo would misrepresent the package's scope.

## Goals

1. Demonstrate the published API of `BluetoothCentralClient` and `BluetoothPeripheralClient` in a way that a consumer can read top to bottom and understand how to wire the package into a TCA app.
2. Cover the major BLE workflows: scan, connect, discover, read, write, notify, advertise, GATT build, respond to read/write requests.
3. Keep the demo self-contained inside the package repo, depending on `FCB` via a local SwiftPM reference. No CocoaPods.
4. Ship every feature with a TCA `TestStore` test using stubbed clients, demonstrating the testability story the package was built for.
5. Target iOS only (iOS 17+).

## Non-goals

- iBeacon advertising or ranging.
- Background-mode BLE.
- Scan filters by service UUID, RSSI graphs, signal-strength meters.
- Persistence of GATT layouts, advertising configurations, or scan history. All state is in-memory and reset on app launch.
- L2CAP channels.
- Bonding / pairing UI.
- A library of preset BLE service definitions (Battery Service, Heart Rate, etc.). User configures GATT layouts from scratch.
- macOS or Mac Catalyst.

## Architecture

### Tech stack

- iOS 17+, SwiftUI, Swift 6 strict concurrency.
- TCA (1.x) via `pointfreeco/swift-composable-architecture` (already a dependency of the `FCBComposable` product).
- `FCBComposable` for all CoreBluetooth interaction (no direct CB usage in the demo).
- Swift Testing for unit tests; TCA `TestStore` for reducer tests.

### Layout

The demo lives inside the FCB package repo at `Example/FCBDemo/`:

```
Example/FCBDemo/
├── FCBDemo.xcodeproj
├── FCBDemo/
│   ├── FCBDemoApp.swift                 # @main entry point
│   ├── App/
│   │   └── AppFeature.swift             # AppFeature reducer + AppView (TabView)
│   ├── Central/
│   │   ├── CentralFeature.swift
│   │   ├── CentralView.swift
│   │   ├── PeripheralDetailFeature.swift
│   │   └── PeripheralDetailView.swift
│   ├── Peripheral/
│   │   ├── PeripheralFeature.swift      # composes the three sub-features
│   │   ├── PeripheralView.swift
│   │   ├── GATTBuilderFeature.swift
│   │   ├── GATTBuilderView.swift
│   │   ├── AdvertisingFeature.swift
│   │   ├── AdvertisingView.swift
│   │   ├── RequestLogFeature.swift
│   │   └── RequestLogView.swift
│   ├── Shared/
│   │   ├── HexCoding.swift              # Data <-> hex String helpers
│   │   ├── CBUUIDParsing.swift          # tolerant CBUUID(string:) wrapper
│   │   └── PreviewDependencies.swift    # .previewBluetooth helper
│   └── Info.plist
└── FCBDemoTests/
    ├── CentralFeatureTests.swift
    ├── PeripheralDetailFeatureTests.swift
    ├── GATTBuilderFeatureTests.swift
    ├── AdvertisingFeatureTests.swift
    └── RequestLogFeatureTests.swift
```

The Xcode project references `../..` as a local SwiftPM package, depending on both the `FCB` and `FCBComposable` products.

### Dependency graph

```
AppFeature
├── Scope → CentralFeature
│   └── NavigationStack: StackState<PeripheralDetailFeature.State>
└── Scope → PeripheralFeature
    ├── Scope → GATTBuilderFeature
    ├── Scope → AdvertisingFeature
    └── Scope → RequestLogFeature
```

`@Dependency(\.bluetoothCentralClient)` is used by `CentralFeature` and `PeripheralDetailFeature`. `@Dependency(\.bluetoothPeripheralClient)` is used by `PeripheralFeature`, `GATTBuilderFeature`, `AdvertisingFeature`, and `RequestLogFeature`.

## AppFeature

Thin orchestrator. State holds the selected tab and the two child states. Reducer is `Scope` + identity.

```swift
@Reducer
public struct AppFeature {
    public enum Tab: Equatable { case central, peripheral }

    @ObservableState
    public struct State: Equatable {
        var tab: Tab = .central
        var central = CentralFeature.State()
        var peripheral = PeripheralFeature.State()
    }

    public enum Action {
        case tabChanged(Tab)
        case central(CentralFeature.Action)
        case peripheral(PeripheralFeature.Action)
    }

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

`AppView` is a `TabView` bound to `viewStore.tab`, hosting a `CentralView` (wrapped in `NavigationStack`) and a `PeripheralView`.

## Central tab

### `CentralFeature`

Scans, lists discovered peripherals, and pushes a detail view per peripheral.

**State:**
```swift
@ObservableState
public struct State: Equatable {
    var managerState: CBManagerState = .unknown
    var isScanning = false
    var discovered: IdentifiedArrayOf<DiscoveredPeripheral> = []
    var path = StackState<PeripheralDetailFeature.State>()
    var scanError: String?
}
```

**Action:**
```swift
public enum Action {
    case onAppear
    case stateStreamUpdate(CBManagerState)
    case startScanTapped
    case stopScanTapped
    case scanEvent(DiscoveredPeripheral)
    case peripheralTapped(Peripheral.ID)
    case clearListTapped
    case path(StackActionOf<PeripheralDetailFeature>)
}
```

**Reducer behavior:**
- `onAppear` starts a long-running `.run` effect subscribed to `bluetoothCentralClient.state()`, feeding back `stateStreamUpdate`. Cancellable via `CancelID.stateStream`. Idempotent — re-issuing `onAppear` cancels the previous task before starting a new one.
- `startScanTapped` checks `managerState == .poweredOn`; if not, sets `scanError` and stops. Otherwise calls `bluetoothCentralClient.scan(nil, nil)` inside a `.run` effect, feeding `scanEvent` for each `DiscoveredPeripheral`. Sets `isScanning = true`. Task ID `CancelID.scan`.
- `stopScanTapped` calls `await bluetoothCentralClient.stopScan()`, sets `isScanning = false`, cancels the scan task.
- `scanEvent(discovered)` upserts into `discovered`, keyed by `discovered.peripheral.id`. Latest RSSI wins; latest advertisement data wins. The displayed sort is by `rssi` descending.
- `peripheralTapped(id)` looks up the `DiscoveredPeripheral` and pushes a `PeripheralDetailFeature.State(peripheral: discovered.peripheral)` onto `path`.
- `clearListTapped` resets `discovered` to empty.
- `path` delegates to `PeripheralDetailFeature` for stack-pushed detail screens (`.forEach(\.path, action: \.path) { PeripheralDetailFeature() }`).

**View:**

`CentralView` is a `NavigationStack(path:)` containing:
- Top bar: `Text("BLE: \(managerStateLabel)")`, Start/Stop scan toggle button, "Clear" button.
- A scrolling `List(viewStore.discovered.sorted(by: rssiDesc))` with rows showing `Text(name ?? "Unknown")`, `Text(id.uuidString.prefix(8))`, `Text("\(rssi) dBm")`. Each row is a `NavigationLink(value: peripheral.id)` that dispatches `peripheralTapped`.
- `navigationDestination(for: PeripheralDetailFeature.State.self)` renders `PeripheralDetailView`.

### `PeripheralDetailFeature`

Owns the connection lifecycle and post-connect interaction for a single peripheral.

**State:**
```swift
@ObservableState
public struct State: Equatable, Identifiable {
    let peripheral: Peripheral
    public var id: UUID { peripheral.id }
    var connectionState: ConnectionState = .disconnected
    var services: IdentifiedArrayOf<Service> = []
    var characteristics: [CBUUID: IdentifiedArrayOf<Characteristic>] = [:]
    var characteristicValues: [CBUUID: Data] = [:]
    var notifyingCharacteristics: Set<CBUUID> = []
    var connectError: String?
    var operationError: String?
    var pendingWriteText: [CBUUID: String] = [:]
}
```

**Action:**
```swift
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
```

**Reducer behavior:**
- `onAppear` starts a `.run` effect subscribed to `bluetoothCentralClient.events()` filtered to events about `self.peripheral.id`, feeding `eventStreamEvent`. Cancellable on dismiss.
- `connectTapped` sets `connectionState = .connecting`, runs `try await bluetoothCentralClient.connect(peripheral.id, nil)`. On success → `connected(Peripheral)` setting `connectionState = .connected`. On `BluetoothError` → `connectFailed` setting `connectError`.
- `disconnectTapped` → `try await disconnect(peripheral.id)`. On success → `disconnected` resetting `connectionState = .disconnected` and clearing `services`/`characteristics`/`characteristicValues`/`notifyingCharacteristics`.
- `eventStreamEvent(.didDisconnect)` → same reset as `disconnected`.
- `discoverServicesTapped` → `try await discoverServices(peripheral.id, nil)` → `servicesDiscovered([Service])` setting `services`. Error → `servicesDiscoveryFailed`.
- `discoverCharacteristicsTapped(serviceID)` → `try await discoverCharacteristics(peripheral.id, serviceID, nil)` → `characteristicsDiscovered(serviceID, [Characteristic])` populating `characteristics[serviceID]`.
- `readTapped(cid)` → `try await readValue(peripheral.id, cid)` → `valueRead(cid, Data)` updating `characteristicValues[cid]`.
- `writeTextChanged` updates `pendingWriteText[cid]` only.
- `writeTapped(cid, withResponse)` parses `pendingWriteText[cid]` via `HexCoding.decode`. If nil → `operationError = "Invalid hex"`. Else → `try await writeValue(parsedData, peripheral.id, cid, withResponse ? .withResponse : .withoutResponse)` → `writeCompleted(cid)` which clears `pendingWriteText[cid]`.
- `toggleNotifyTapped(cid)`:
  - If `cid` not in `notifyingCharacteristics`: `try await setNotify(true, peripheral.id, cid)`, on success insert `cid`, start a `.run` effect subscribed to `notifications(peripheral.id, cid)` feeding `notifyValueReceived`. Task ID `CancelID.notify(cid)`.
  - If `cid` is in `notifyingCharacteristics`: `try await setNotify(false, peripheral.id, cid)`, remove `cid`, cancel notify task by ID.
- `notifyValueReceived(cid, Data)` updates `characteristicValues[cid]`.
- `operationFailed(err)` sets `operationError = "\(err)"`.

**View (`PeripheralDetailView`):**
- Header: peripheral name + UUID, connection state, Connect/Disconnect button.
- After connection: "Discover Services" button + a list of services with `DisclosureGroup` sections.
- Each service section has "Discover Characteristics" button + a list of characteristic rows.
- Characteristic row: UUID label, property badges (R / W / Wn / N / I), current value as hex, per-row Read button (if `.read` in properties), hex TextField + "Write w/ Response" + "Write w/o Response" buttons (if `.write` / `.writeWithoutResponse`), Notify toggle (if `.notify` / `.indicate`).
- Inline `Text(.red)` for any active error.

## Peripheral tab

### `PeripheralFeature`

Composes the three child reducers. Owns `managerState` and the `bluetoothPeripheralClient.state()` subscription.

**State:**
```swift
@ObservableState
public struct State: Equatable {
    var gattBuilder = GATTBuilderFeature.State()
    var advertising = AdvertisingFeature.State()
    var requestLog = RequestLogFeature.State()
    var managerState: CBManagerState = .unknown
}
```

**Action:**
```swift
public enum Action {
    case onAppear
    case stateStreamUpdate(CBManagerState)
    case gattBuilder(GATTBuilderFeature.Action)
    case advertising(AdvertisingFeature.Action)
    case requestLog(RequestLogFeature.Action)
}
```

**Body:**
```swift
public var body: some ReducerOf<Self> {
    Scope(state: \.gattBuilder, action: \.gattBuilder) { GATTBuilderFeature() }
    Scope(state: \.advertising, action: \.advertising) { AdvertisingFeature() }
    Scope(state: \.requestLog, action: \.requestLog) { RequestLogFeature() }
    Reduce { state, action in
        switch action {
        case .onAppear:
            return .run { send in
                for await s in await bluetoothPeripheralClient.state() {
                    await send(.stateStreamUpdate(s))
                }
            }.cancellable(id: PeripheralFeature.CancelID.stateStream, cancelInFlight: true)
        case .stateStreamUpdate(let s):
            state.managerState = s
            return .none
        default:
            return .none
        }
    }
}
```

**View:**

`PeripheralView` is a `ScrollView` with three sections (GATTBuilderView, AdvertisingView, RequestLogView), plus a top banner showing `managerState`. Operation buttons in child views are disabled until `managerState == .poweredOn`.

### `GATTBuilderFeature`

Lets the user build and publish GATT services.

**Draft model types** (declared in this file; not in FCBComposable):

```swift
public struct DraftService: Equatable, Identifiable {
    public var id: CBUUID
    public var isPrimary: Bool
    public var characteristics: IdentifiedArrayOf<DraftCharacteristic> = []
}

public struct DraftCharacteristic: Equatable, Identifiable {
    public var id: CBUUID
    public var properties: CBCharacteristicProperties
    public var permissions: CBAttributePermissions
    public var initialValueText: String   // hex-encoded
}
```

**State:**
```swift
@ObservableState
public struct State: Equatable {
    var services: IdentifiedArrayOf<DraftService> = []
    var publishedServiceIDs: Set<CBUUID> = []
    var newServiceUUIDInput: String = ""
    var publishError: String?
}
```

**Action:**
```swift
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
```

**Reducer behavior:**
- `addServiceTapped` parses `newServiceUUIDInput` via `CBUUIDParsing.parse(_:) -> CBUUID?` (accepts short 4-hex like `180F`, full 128-bit `XXXXXXXX-XXXX-...`). On nil parse → `publishError = "Invalid UUID"`. On success → append `DraftService(id:, isPrimary: true, characteristics: [])`, reset input.
- `isPrimaryToggled` flips `services[id:].isPrimary`. Only effective on un-published services; the view disables the toggle for IDs in `publishedServiceIDs`.
- `removeServiceTapped` removes from `services`. If it was published, also calls `await bluetoothPeripheralClient.remove(serviceID)` and removes from `publishedServiceIDs`.
- `addCharacteristicTapped(sid)` appends a new `DraftCharacteristic(id: CBUUID(), properties: [.read], permissions: [.readable], initialValueText: "")`.
- `togglePropertyTapped(sid, cid, prop)` XORs `prop` into the characteristic's `properties` (works because `CBCharacteristicProperties` is an OptionSet — toggling adds/removes the bit).
- `togglePermissionTapped` same pattern.
- `initialValueChanged` updates the text.
- `removeCharacteristicTapped` removes from the service's `characteristics`.
- `publishServiceTapped(sid)` builds a `MutableService`: for each `DraftCharacteristic`, parses `initialValueText` via `HexCoding.decode` (nil → `Data()`), constructs `MutableCharacteristic(id:, properties:, permissions:, value:)`. Calls `try await bluetoothPeripheralClient.add(service: mutable)`. On success → `servicePublished(sid)` adds to `publishedServiceIDs`. On `BluetoothError` → `publishFailed` sets `publishError`.
- `removeAllPublishedTapped` runs `await bluetoothPeripheralClient.removeAll()` then `servicePublished` for empty set. Dispatches `removeAllPublishedCompleted` which sets `publishedServiceIDs = []`.

**View (`GATTBuilderView`):**
- Top row: `TextField("Service UUID (e.g. 180F)", text: ...)` + "Add Service" button.
- For each `DraftService`: a card with a "Service UUID" header showing the UUID, a "Primary" toggle (disabled if published), a list of `DraftCharacteristic` rows, an "Add Characteristic" button, a "Publish" / "Published ✓" button (latter disabled), a trash icon (with confirmation if published).
- Each `DraftCharacteristic` row: editable UUID `TextField`, property checkbox group (read / write / writeWithoutResponse / notify / indicate), permission checkbox group (readable / writeable), hex value `TextField`, trash icon. All controls disabled if the parent service is in `publishedServiceIDs`.
- `publishError` shown in `Text(.red)` at the bottom of the offending card.
- "Remove All Published" button at the bottom.

### `AdvertisingFeature`

**State:**
```swift
@ObservableState
public struct State: Equatable {
    var isAdvertising = false
    var localName: String = ""
    var includedServiceUUIDsText: String = ""
    var lastError: String?
}
```

**Action:**
```swift
public enum Action {
    case localNameChanged(String)
    case includedUUIDsChanged(String)
    case startAdvertisingTapped
    case stopAdvertisingTapped
    case advertisingStarted
    case advertisingFailed(BluetoothError)
    case stopAdvertisingCompleted
}
```

**Reducer behavior:**
- `startAdvertisingTapped` parses comma-separated UUIDs via `CBUUIDParsing.parseList(_:)`. Invalid entries silently skipped. Builds `AdvertisementData(localName: state.localName.isEmpty ? nil : state.localName, serviceUUIDs: parsed)`. Calls `try await bluetoothPeripheralClient.startAdvertising(ad)`. On success → `advertisingStarted` sets `isAdvertising = true`. On error → `advertisingFailed` sets `lastError`.
- `stopAdvertisingTapped` → `await bluetoothPeripheralClient.stopAdvertising()` → `stopAdvertisingCompleted` sets `isAdvertising = false`.

**View (`AdvertisingView`):**
- `TextField("Local Name", text: ...)`.
- `TextField("Included Service UUIDs (comma-separated)", text: ...)`.
- Start/Stop button (single button toggling based on `isAdvertising`).
- `Text(isAdvertising ? "Advertising" : "Stopped")`.
- `lastError` in red.

### `RequestLogFeature`

**State:**
```swift
@ObservableState
public struct State: Equatable {
    var readRequests: IdentifiedArrayOf<ReadRequest> = []
    var writeRequests: IdentifiedArrayOf<LoggedWriteRequest> = []
    var subscriptions: [LoggedSubscription] = []
    var defaultResultCode: CBATTError.Code = .success
}

public struct LoggedWriteRequest: Equatable, Identifiable {
    public var id: UUID    // request.id
    public var request: WriteRequest
}

public struct LoggedSubscription: Equatable, Identifiable {
    public var id: UUID = UUID()
    public var event: SubscriptionEvent
    public var receivedAt: Date
}
```

**Action:**
```swift
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
```

**Reducer behavior:**
- `onAppear` starts three long-running `.run` effects subscribed to `readRequests()`, `writeRequests()`, `subscriptions()` from the peripheral client.
- `readRequestReceived(req)` appends to `readRequests`.
- `writeRequestsReceived(reqs)` appends a `LoggedWriteRequest` per `WriteRequest` in the batch.
- `subscriptionEvent(ev)` prepends a `LoggedSubscription` with `Date()` timestamp. Ring-buffer to 10 entries (drop oldest beyond).
- `respondReadTapped(id, code)` → `await respond(requestID: id, result: code)` → `respondedRead(id)` removes from `readRequests`.
- `respondWriteTapped(id, code)` → same, removes from `writeRequests`.
- `defaultCodeChanged(code)` sets `defaultResultCode`. The UI's per-row Respond button defaults to this code.
- `clearLogTapped` clears all three lists. (Does NOT call `respond` for pending requests — clearing is a UI action only. Note this in the view.)

**View (`RequestLogView`):**
- Top: `Picker("Default Response", selection: defaultResultCode)` with cases for `.success`, `.readNotPermitted`, `.writeNotPermitted`, `.invalidHandle`, `.requestNotSupported`, `.attributeNotFound`.
- Section "Read Requests": list of rows with characteristic UUID + offset + central UUID + Respond button (uses `defaultResultCode`).
- Section "Write Requests": list with characteristic UUID + offset + hex value + Respond button.
- Section "Subscriptions (last 10)": list with `subscribed` / `unsubscribed` label + central UUID + characteristic UUID + timestamp.
- "Clear Log" button. Confirmation alert: "Pending requests will not be responded to; the central may time out."

## Error handling

Per-feature error fields (`scanError`, `connectError`, `operationError`, `publishError`, `lastError`) are rendered inline as red text. No app-global alert. Errors are dismissible by user input (the next successful operation clears them) and by `clearLogTapped`-style actions.

Specific cases:
- **Manager not powered on:** every operation button is disabled when `managerState != .poweredOn`. Buttons render as `.disabled(true)`. The top banner explains the state. Attempting an operation through a disabled button is impossible; if one happens anyway (race), the client throws `.poweredOff` and we display it.
- **Connection lost mid-session:** `PeripheralDetailFeature` subscribes to `bluetoothCentralClient.events()` and listens for `.didDisconnect(self.peripheral, _)`. On receipt → reset state (same as user-initiated disconnect) and set `operationError = "Disconnected"`.
- **Hex parse failure:** invalid hex in a write or initial value → no operation, set error string. No crash.
- **CBUUID parse failure:** ditto.

## Info.plist

- `NSBluetoothAlwaysUsageDescription` — `"FCBDemo uses Bluetooth to scan, connect to, and advertise BLE services."`
- `NSBluetoothPeripheralUsageDescription` — same message (harmless on modern iOS).
- `UIBackgroundModes` — empty. No background BLE.

## Demo dependencies for previews

`Shared/PreviewDependencies.swift` defines:

```swift
extension DependencyValues {
    var previewBluetooth: Self {
        var copy = self
        copy.bluetoothCentralClient = .previewValue
        copy.bluetoothPeripheralClient = .previewValue
        return copy
    }
}
```

`#Preview` blocks in view files use `withDependencies { $0 = $0.previewBluetooth } operation: { AnyView(...) }` to render with the `previewValue` mocks already shipped in FCBComposable.

## Testing strategy

Every feature ships with a TCA `TestStore` test file under `FCBDemoTests/`. The pattern uses dependency overrides on the `@DependencyClient` witness:

```swift
@MainActor
@Test func centralStartsScanAndReceivesPeripherals() async {
    let fixture = DiscoveredPeripheral(
        peripheral: Peripheral(id: UUID(), name: "Sensor", state: .disconnected),
        advertisementData: AdvertisementData(localName: "Sensor"),
        rssi: -55
    )
    let store = TestStore(initialState: CentralFeature.State()) {
        CentralFeature()
    } withDependencies: {
        $0.bluetoothCentralClient.state = { AsyncStream { c in c.yield(.poweredOn); c.finish() } }
        $0.bluetoothCentralClient.scan = { _, _ in
            AsyncStream { c in c.yield(fixture); c.finish() }
        }
        $0.bluetoothCentralClient.stopScan = { }
    }
    await store.send(.onAppear)
    await store.receive(\.stateStreamUpdate) { $0.managerState = .poweredOn }
    await store.send(.startScanTapped) { $0.isScanning = true }
    await store.receive(\.scanEvent) { $0.discovered = [fixture] }
    await store.send(.stopScanTapped) { $0.isScanning = false }
}
```

Coverage per feature:

- **CentralFeature** — scan start/stop, dedupe-on-rediscover (second `scanEvent` with same id updates row in place), state-stream wiring, `startScanTapped` blocked when not poweredOn.
- **PeripheralDetailFeature** — connect success path, connect failure (`BluetoothError.connectionFailed`), services discovery, characteristic read returns `Data`, write with response, write with invalid hex → `operationError` set, no `writeValue` call made, notify subscribe + value delivery + unsubscribe, mid-session `.didDisconnect` event from the events stream resets state.
- **GATTBuilderFeature** — add service with valid UUID, add service with invalid UUID sets error, toggle property/permission bits via XOR semantics, add+remove characteristic, publish success marks ID in `publishedServiceIDs`, publish failure surfaces `publishError` and does NOT add to set, `removeAllPublishedTapped` calls `removeAll()`.
- **AdvertisingFeature** — start with valid local name + UUIDs, start failure surfaces `lastError`, stop transitions back.
- **RequestLogFeature** — read request arrival + respond removes from list, write batch arrival adds N rows, respond to one row removes only that row, subscription ring-buffer drops oldest beyond 10, `defaultCodeChanged` updates state.

Tests use `TestStore` exhaustively (no `.send` without `state` mutation closures). All clients are overridden to deterministic stubs. No real CB. No `liveValue` invoked.

Mutation-testing protocol (from user-level CLAUDE.md) applies to every test set added or modified.

## Out of scope (explicit)

- Background-mode BLE.
- Scan filters / RSSI graph / signal-strength indicators.
- Persistence of GATT layouts, advertising configs, or scan history.
- L2CAP channels.
- Bonding / pairing UI.
- iBeacon advertising or ranging.
- A library of preset services (Battery, Heart Rate, etc.).
- macOS or Mac Catalyst.
- TestStore tests of `AppFeature` itself beyond tab switching (the composition is trivial).

## Open decisions deferred to implementation

- Exact Xcode project settings (deployment target, signing) — set during scaffolding.
- Whether `PreviewDependencies.previewBluetooth` lives on `DependencyValues` or as a free helper — cosmetic.
- Hex input UX (uppercase normalization, space-stripping, prefix `0x` accepted): default to accepting all reasonable inputs, normalize internally.
- Whether `LoggedSubscription` uses the receive timestamp or the event's own timestamp (CBPeripheralManager doesn't surface one) — use `Date()` at receive time.
