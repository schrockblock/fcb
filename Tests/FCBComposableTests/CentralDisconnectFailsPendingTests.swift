@preconcurrency import CoreBluetooth
@preconcurrency import CoreBluetoothMock
import Foundation
import Testing
@testable import FCBComposable

// MARK: - Bounded waits

/// Thread-safe one-shot slot for an operation's result.
final class OutcomeBox<T: Sendable>: @unchecked Sendable {
    private let lock = NSLock()
    private var result: Result<T, any Error>?

    func set(_ newValue: Result<T, any Error>) { lock.withLock { result = newValue } }
    func get() -> Result<T, any Error>? { lock.withLock { result } }
}

/// Runs `operation` and waits at most `seconds` for it to finish. Returns its
/// result, or `nil` when the deadline passed first (the operation hung).
///
/// The operation runs in an unstructured task and a task group races a
/// cancellable poll of its result against a sleep, so the wait stays bounded
/// even when the operation awaits a continuation that is never resumed.
func outcome<T: Sendable>(
    within seconds: Double,
    _ operation: @escaping @Sendable () async throws -> T
) async -> Result<T, any Error>? {
    let box = OutcomeBox<T>()
    let worker = Task {
        do { box.set(.success(try await operation())) } catch { box.set(.failure(error)) }
    }
    let first: Result<T, any Error>?? = await withTaskGroup(of: Optional<Result<T, any Error>>.self) { group in
        group.addTask {
            while !Task.isCancelled {
                if let result = box.get() { return result }
                try? await Task.sleep(nanoseconds: 5_000_000)
            }
            return nil
        }
        group.addTask {
            try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            return nil
        }
        let first = await group.next()
        group.cancelAll()
        return first
    }
    let result = first ?? nil
    if result == nil { worker.cancel() }
    return result
}

/// Asserts that `result` is a thrown `BluetoothError.disconnected` for `id`
/// (and not a timeout, a success, or some other error).
func expectDisconnected<T>(
    _ result: Result<T, any Error>?,
    id: UUID,
    sourceLocation: SourceLocation = #_sourceLocation
) {
    guard let result else {
        Issue.record("operation was still pending 2 s after the disconnect", sourceLocation: sourceLocation)
        return
    }
    switch result {
    case .success:
        Issue.record("expected BluetoothError.disconnected, but the operation succeeded", sourceLocation: sourceLocation)
    case .failure(let error):
        guard case .disconnected(let peripheralID, _)? = error as? BluetoothError else {
            Issue.record("expected BluetoothError.disconnected, got \(error)", sourceLocation: sourceLocation)
            return
        }
        #expect(peripheralID == id, sourceLocation: sourceLocation)
    }
}

// MARK: - Simulation rig

/// How long the simulated peripheral takes to answer ANY GATT request. CBM
/// schedules every response (service/characteristic discovery, read, write,
/// set-notify) one connection interval after the request, so this is what
/// keeps an operation genuinely in flight at the peripheral.
let pendingOpsResponseLatency: TimeInterval = 0.5

/// CBM delivers a `.connectionTimeout` disconnection after the spec's
/// supervision timeout (any other reason waits a full connection interval,
/// which would tie with the in-flight response). Much shorter than
/// `pendingOpsResponseLatency`, so the link loss overtakes the response and
/// CBM then drops the response because the peripheral is no longer connected.
let pendingOpsLinkLossDelay: TimeInterval = 0.02

/// Spec delegate that answers every request successfully and counts the
/// read / service-discovery requests that reached the peripheral, so a test
/// can prove the operation is in flight when the link drops.
final class PendingOpsSpecDelegate: CBMPeripheralSpecDelegate, @unchecked Sendable {
    private let lock = NSLock()
    private var _readRequests = 0
    private var _serviceDiscoveryRequests = 0

    var readRequests: Int { lock.withLock { _readRequests } }
    var serviceDiscoveryRequests: Int { lock.withLock { _serviceDiscoveryRequests } }

    func peripheral(_ peripheral: CBMPeripheralSpec,
                    didReceiveServiceDiscoveryRequest serviceUUIDs: [CBMUUID]?) -> Result<Void, any Error> {
        lock.withLock { _serviceDiscoveryRequests += 1 }
        return .success(())
    }

    func peripheral(_ peripheral: CBMPeripheralSpec,
                    didReceiveReadRequestFor characteristic: CBMCharacteristicMock) -> Result<Data, any Error> {
        lock.withLock { _readRequests += 1 }
        return .success(Data([0x64]))
    }

    func peripheral(_ peripheral: CBMPeripheralSpec,
                    didReceiveWriteRequestFor characteristic: CBMCharacteristicMock,
                    data: Data) -> Result<Void, any Error> {
        .success(())
    }
}

/// A mock central manager that counts `cancelPeripheralConnection` calls.
final class CountingCentralManagerMock: CBMCentralManagerMock, @unchecked Sendable {
    private let lock = NSLock()
    private var _cancelCount = 0

    var cancelCount: Int { lock.withLock { _cancelCount } }

    override func cancelPeripheralConnection(_ peripheral: CBMPeripheral) {
        lock.withLock { _cancelCount += 1 }
        super.cancelPeripheralConnection(peripheral)
    }
}

struct PendingOpsRig {
    let client: BluetoothCentralClient
    let manager: CBMCentralManager
    let spec: CBMPeripheralSpec
    let specDelegate: PendingOpsSpecDelegate
    let characteristic: CBMCharacteristicMock
    let id: UUID

    /// Connects and discovers the battery service + level characteristic.
    func connectAndDiscover() async throws {
        _ = try await client.connect(id, ConnectOptions?.none)
        _ = try await client.discoverServices(id, [cbmBatteryServiceUUID])
        _ = try await client.discoverCharacteristics(id, cbmBatteryServiceUUID, [CBUUID]?.none)
    }

    /// Simulates the peripheral dropping the link (supervision timeout).
    func simulateLinkLoss() {
        spec.simulateDisconnection(withError: CBMError(.connectionTimeout))
    }
}

/// Stands up one battery-service peripheral with a readable/notifiable
/// characteristic and a slow (`pendingOpsResponseLatency`) GATT response,
/// behind a fresh mock manager wrapped in the live client — the same
/// construction as `BluetoothCentralClient.mocked()`, but with the manager
/// injectable and awaited to `.poweredOn` first.
///
/// `inRange: true` builds the spec as already connected (by "another app"),
/// so `connect` completes immediately without waiting for an advertisement.
/// `inRange: false` puts it out of range: a `connect` then stays pending.
@MainActor
func makePendingOpsRig(
    inRange: Bool = true,
    makeManager: () -> CBMCentralManager = { CBMCentralManagerFactory.instance(forceMock: true) }
) async -> PendingOpsRig {
    CBMCentralManagerMock.tearDownSimulation()
    CBMCentralManagerMock.simulateInitialState(.poweredOn)
    let id = UUID()
    let specDelegate = PendingOpsSpecDelegate()
    let characteristic = CBMCharacteristicMock(type: cbmBatteryLevelUUID, properties: [.read, .write, .writeWithoutResponse, .notify])
    let service = CBMServiceMock(type: cbmBatteryServiceUUID, primary: true, characteristics: characteristic)
    let builder = CBMPeripheralSpec.simulatePeripheral(identifier: id, proximity: inRange ? .near : .outOfRange)
    let spec: CBMPeripheralSpec
    if inRange {
        spec = builder
            .connected(name: "PendingDev", services: [service], delegate: specDelegate,
                       connectionInterval: pendingOpsResponseLatency, supervisionTimeout: pendingOpsLinkLossDelay)
            .build()
    } else {
        spec = builder
            .connectable(name: "PendingDev", services: [service], delegate: specDelegate,
                         connectionInterval: pendingOpsResponseLatency, supervisionTimeout: pendingOpsLinkLossDelay)
            .allowForRetrieval()
            .build()
    }
    CBMCentralManagerMock.simulatePeripherals([spec])
    let manager = makeManager()
    await waitForManagerState(manager, toReach: .poweredOn)
    let client = BluetoothCentralClient.makeClient(actor: CentralActor(manager: manager))
    return PendingOpsRig(client: client, manager: manager, spec: spec, specDelegate: specDelegate,
                         characteristic: characteristic, id: id)
}

/// Counts `.didDisconnect` events for one peripheral on a client's event stream.
final class DisconnectEventCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var _count = 0
    private var task: Task<Void, Never>?

    var count: Int { lock.withLock { _count } }

    init(client: BluetoothCentralClient, id: UUID) {
        let stream = client.events()
        task = Task { [weak self] in
            for await event in stream {
                if case .didDisconnect(let peripheral, _) = event, peripheral.id == id {
                    self?.increment()
                }
            }
        }
    }

    private func increment() { lock.withLock { _count += 1 } }

    func stop() { task?.cancel() }
}

// MARK: - Tests

extension CBMBackedTests {
    @Suite @MainActor
    struct CentralDisconnectFailsPendingTests {
        @Test func readPendingWhenPeripheralDisconnectsThrowsDisconnected() async throws {
            let rig = await makePendingOpsRig()
            try await rig.connectAndDiscover()
            let client = rig.client
            let id = rig.id

            let read = Task { await outcome(within: 2) { try await client.readValue(id, cbmBatteryLevelUUID) } }
            try? await Task.sleep(nanoseconds: 50_000_000)
            // The read reached the peripheral; its response is still in flight.
            #expect(rig.specDelegate.readRequests == 1)
            rig.simulateLinkLoss()

            expectDisconnected(await read.value, id: id)
        }

        @Test func notificationStreamEndsWhenPeripheralDisconnects() async throws {
            let rig = await makePendingOpsRig()
            try await rig.connectAndDiscover()
            let client = rig.client
            let id = rig.id
            try await client.setNotify(true, id, cbmBatteryLevelUUID)
            let stream = client.notifications(id, cbmBatteryLevelUUID)

            let iteration = Task {
                await outcome(within: 2) {
                    for try await _ in stream {}
                    return true
                }
            }
            // Let the stream register with the actor before the link drops.
            try? await Task.sleep(nanoseconds: 50_000_000)
            rig.simulateLinkLoss()

            expectDisconnected(await iteration.value, id: id)
        }

        @Test func discoverServicesPendingWhenPeripheralDisconnectsThrows() async throws {
            let rig = await makePendingOpsRig()
            _ = try await rig.client.connect(rig.id, ConnectOptions?.none)
            let client = rig.client
            let id = rig.id

            let discovery = Task { await outcome(within: 2) { try await client.discoverServices(id, [cbmBatteryServiceUUID]) } }
            try? await Task.sleep(nanoseconds: 50_000_000)
            // The discovery reached the peripheral; its response is still in flight.
            #expect(rig.specDelegate.serviceDiscoveryRequests == 1)
            rig.simulateLinkLoss()

            expectDisconnected(await discovery.value, id: id)
        }

        @Test func twoConcurrentDisconnectsBothReturn() async throws {
            let rig = await makePendingOpsRig(makeManager: { CountingCentralManagerMock() })
            let manager = try #require(rig.manager as? CountingCentralManagerMock)
            let client = rig.client
            let id = rig.id
            _ = try await client.connect(id, ConnectOptions?.none)
            let counter = DisconnectEventCounter(client: client, id: id)
            defer { counter.stop() }
            // Let the event stream register with the actor.
            try? await Task.sleep(nanoseconds: 50_000_000)

            let both = await outcome(within: 2) {
                async let first: Void = client.disconnect(id)
                async let second: Void = client.disconnect(id)
                _ = try await (first, second)
                return true
            }

            switch both {
            case .none:
                Issue.record("a concurrent disconnect was still pending after 2 s")
            case .failure(let error)?:
                Issue.record("a concurrent disconnect threw \(error)")
            case .success?:
                break
            }
            // Give any second (erroneous) disconnection time to be delivered.
            try? await Task.sleep(nanoseconds: UInt64((pendingOpsResponseLatency + 0.2) * 1_000_000_000))
            #expect(manager.cancelCount == 1)
            #expect(counter.count == 1)
        }

        @Test func disconnectDuringConnectFailsTheConnect() async throws {
            // Out of range: CBM never completes the connect (no timeout, as on
            // iOS); cancelling it reports didDisconnect for the peripheral.
            let rig = await makePendingOpsRig(inRange: false)
            let client = rig.client
            let id = rig.id

            let connect = Task { await outcome(within: 2) { try await client.connect(id, ConnectOptions?.none) } }
            try? await Task.sleep(nanoseconds: 50_000_000)
            let disconnect = await outcome(within: 2) { try await client.disconnect(id) }

            switch disconnect {
            case .none:
                Issue.record("disconnect was still pending after 2 s")
            case .failure(let error)?:
                Issue.record("disconnect threw \(error)")
            case .success?:
                break
            }
            expectDisconnected(await connect.value, id: id)
        }
    }
}
