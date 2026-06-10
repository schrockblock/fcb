import ComposableArchitecture
@preconcurrency import CoreBluetooth
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
        // Handlers are nonisolated stubs — call them directly. Tasks 15-18 will
        // replace these with actor-hopping Task { await self?.handle…() } calls
        // once the bodies need actor state.
        delegate.onDidUpdateState = { [weak self] m in
            self?.handleDidUpdateState(m.state)
        }
        delegate.onDidDiscover = { [weak self] _, peripheral, ad, rssi in
            self?.handleDidDiscover(peripheral: peripheral, ad: ad, rssi: rssi)
        }
        delegate.onDidConnect = { [weak self] _, peripheral in
            self?.handleDidConnect(peripheral: peripheral)
        }
        delegate.onDidFailToConnect = { [weak self] _, peripheral, error in
            self?.handleDidFailToConnect(peripheral: peripheral, error: error)
        }
        delegate.onDidDisconnect = { [weak self] _, peripheral, error in
            self?.handleDidDisconnect(peripheral: peripheral, error: error)
        }
        peripheralDelegate.onDidDiscoverServices = { [weak self] peripheral, error in
            self?.handleDidDiscoverServices(peripheral: peripheral, error: error)
        }
        peripheralDelegate.onDidDiscoverCharacteristics = { [weak self] peripheral, service, error in
            self?.handleDidDiscoverCharacteristics(peripheral: peripheral, service: service, error: error)
        }
        peripheralDelegate.onDidUpdateValueForCharacteristic = { [weak self] peripheral, char, error in
            self?.handleDidUpdateValue(peripheral: peripheral, characteristic: char, error: error)
        }
        peripheralDelegate.onDidWriteValueForCharacteristic = { [weak self] peripheral, char, error in
            self?.handleDidWriteValue(peripheral: peripheral, characteristic: char, error: error)
        }
        peripheralDelegate.onDidUpdateNotificationState = { [weak self] peripheral, char, error in
            self?.handleDidUpdateNotificationState(peripheral: peripheral, characteristic: char, error: error)
        }
    }

    // MARK: - Public methods (stubs filled in by later tasks)

    nonisolated func stateStream() -> AsyncStream<CBManagerState> { .never }
    nonisolated func eventStream() -> AsyncStream<CentralEvent> { .never }
    nonisolated func scan(services: [CBUUID]?, options: ScanOptions?) -> AsyncStream<DiscoveredPeripheral> { .never }
    nonisolated func notifications(peripheralID: UUID, characteristicID: CBUUID) -> AsyncThrowingStream<Data, any Error> { .finished() }

    nonisolated func stopScan() async {}
    nonisolated func connect(id: UUID, options: ConnectOptions?) async throws -> Peripheral { throw BluetoothError.poweredOff }
    nonisolated func disconnect(id: UUID) async throws { throw BluetoothError.poweredOff }
    nonisolated func retrievePeripherals(ids: [UUID]) async -> [Peripheral] { [] }
    nonisolated func retrieveConnected(services: [CBUUID]) async -> [Peripheral] { [] }
    nonisolated func discoverServices(peripheralID: UUID, serviceIDs: [CBUUID]?) async throws -> [Service] { throw BluetoothError.poweredOff }
    nonisolated func discoverCharacteristics(peripheralID: UUID, serviceID: CBUUID, characteristicIDs: [CBUUID]?) async throws -> [Characteristic] { throw BluetoothError.poweredOff }
    nonisolated func readValue(peripheralID: UUID, characteristicID: CBUUID) async throws -> Data { throw BluetoothError.poweredOff }
    nonisolated func writeValue(data: Data, peripheralID: UUID, characteristicID: CBUUID, type: CBCharacteristicWriteType) async throws { throw BluetoothError.poweredOff }
    nonisolated func setNotify(enabled: Bool, peripheralID: UUID, characteristicID: CBUUID) async throws { throw BluetoothError.poweredOff }

    // MARK: - Delegate handlers (filled in by later tasks)
    // nonisolated stubs: the bodies are empty and don't access actor state, so
    // nonisolated avoids strict-concurrency errors when bridging non-Sendable
    // CB types from synchronous delegate callbacks. Tasks 15-18 will refactor.

    nonisolated func handleDidUpdateState(_ state: CBManagerState) {}
    nonisolated func handleDidDiscover(peripheral: CBPeripheral, ad: [String: Any], rssi: NSNumber) {}
    nonisolated func handleDidConnect(peripheral: CBPeripheral) {}
    nonisolated func handleDidFailToConnect(peripheral: CBPeripheral, error: (any Error)?) {}
    nonisolated func handleDidDisconnect(peripheral: CBPeripheral, error: (any Error)?) {}
    nonisolated func handleDidDiscoverServices(peripheral: CBPeripheral, error: (any Error)?) {}
    nonisolated func handleDidDiscoverCharacteristics(peripheral: CBPeripheral, service: CBService, error: (any Error)?) {}
    nonisolated func handleDidUpdateValue(peripheral: CBPeripheral, characteristic: CBCharacteristic, error: (any Error)?) {}
    nonisolated func handleDidWriteValue(peripheral: CBPeripheral, characteristic: CBCharacteristic, error: (any Error)?) {}
    nonisolated func handleDidUpdateNotificationState(peripheral: CBPeripheral, characteristic: CBCharacteristic, error: (any Error)?) {}
}
