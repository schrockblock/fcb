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
        // Capture manager as nonisolated(unsafe) so the @Sendable closure can read
        // `state` synchronously. This is safe: manager is a let, `state` is read-only,
        // and FakeCentralManager sets state before firing the delegate.
        nonisolated(unsafe) let mgr: any CentralManaging = manager
        delegate.onDidUpdateState = { [weak self] _ in
            // Read state from the captured manager reference rather than from the
            // CBCentralManager argument (which may be an unsafeBitCast'd fake in tests).
            let state = mgr.state
            Task { await self?.handleDidUpdateState(state) }
        }
        delegate.onDidDiscover = { [weak self] _, cbPeripheral, ad, rssi in
            let advertisementData = AdvertisementData(dictionary: ad)
            let rssiInt = rssi.intValue
            Task { await self?.recordDiscoveredPeripheral(cbPeripheral: cbPeripheral, ad: advertisementData, rssi: rssiInt) }
        }
        delegate.onDidConnect = { [weak self] _, cbPeripheral in
            Task { await self?.handleDidConnect(cbPeripheral: cbPeripheral) }
        }
        delegate.onDidFailToConnect = { [weak self] _, cbPeripheral, error in
            let nsError = error.map { $0 as NSError }
            Task { await self?.handleDidFailToConnect(cbPeripheral: cbPeripheral, nsError: nsError) }
        }
        delegate.onDidDisconnect = { [weak self] _, cbPeripheral, error in
            let nsError = error.map { $0 as NSError }
            Task { await self?.handleDidDisconnect(cbPeripheral: cbPeripheral, nsError: nsError) }
        }
        peripheralDelegate.onDidDiscoverServices = { [weak self] peripheral, error in
            let id = peripheral.identifier
            let services = peripheral.services?.map(Service.init) ?? []
            let nsError = error.map { $0 as NSError }
            Task { await self?.handleDidDiscoverServices(id: id, services: services, nsError: nsError) }
        }
        peripheralDelegate.onDidDiscoverCharacteristics = { [weak self] peripheral, service, error in
            let pid = peripheral.identifier
            let sid = service.uuid
            let chars = service.characteristics?.map(Characteristic.init) ?? []
            let nsError = error.map { $0 as NSError }
            Task { await self?.handleDidDiscoverCharacteristics(peripheralID: pid, serviceID: sid, characteristics: chars, nsError: nsError) }
        }
        peripheralDelegate.onDidUpdateValueForCharacteristic = { [weak self] peripheral, char, error in
            let pid = peripheral.identifier
            let cid = char.uuid
            let data = char.value
            let nsError = error.map { $0 as NSError }
            Task { await self?.handleDidUpdateValue(peripheralID: pid, characteristicID: cid, data: data, nsError: nsError) }
        }
        peripheralDelegate.onDidWriteValueForCharacteristic = { [weak self] peripheral, char, error in
            let pid = peripheral.identifier
            let cid = char.uuid
            let nsError = error.map { $0 as NSError }
            Task { await self?.handleDidWriteValue(peripheralID: pid, characteristicID: cid, nsError: nsError) }
        }
        peripheralDelegate.onDidUpdateNotificationState = { [weak self] peripheral, char, error in
            let pid = peripheral.identifier
            let cid = char.uuid
            let nsError = error.map { $0 as NSError }
            Task { await self?.handleDidUpdateNotificationState(peripheralID: pid, characteristicID: cid, nsError: nsError) }
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

    nonisolated func notifications(peripheralID: UUID, characteristicID: CBUUID) -> AsyncThrowingStream<Data, any Error> { .finished() }

    func stopScan() async {
        manager.stopScan()
        scanContinuation?.finish()
        scanContinuation = nil
    }

    func connect(id: UUID, options: ConnectOptions?) async throws -> Peripheral {
        try preflightCheck()
        let connection: any PeripheralConnection
        if let existing = peripherals[id] {
            connection = existing
        } else if let lookedUp = lookupPeripheral(id: id) {
            connection = lookedUp
        } else {
            throw BluetoothError.unknownPeripheral(id)
        }
        return try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Peripheral, any Error>) in
            pendingConnect[id] = cont
            if let cbPeripheral = connection as? CBPeripheral {
                manager.connect(cbPeripheral, options: options?.dictionary)
            }
        }
    }

    func disconnect(id: UUID) async throws {
        guard let cb = peripherals[id] as? CBPeripheral else {
            throw BluetoothError.unknownPeripheral(id)
        }
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, any Error>) in
            pendingDisconnect[id] = cont
            manager.cancelPeripheralConnection(cb)
        }
    }

    func retrievePeripherals(ids: [UUID]) async -> [Peripheral] {
        let cbs = manager.retrievePeripherals(withIdentifiers: ids)
        for cb in cbs { peripherals[cb.identifier] = cb }
        return cbs.map(Peripheral.init)
    }

    func retrieveConnected(services: [CBUUID]) async -> [Peripheral] {
        let cbs = manager.retrieveConnectedPeripherals(withServices: services)
        for cb in cbs { peripherals[cb.identifier] = cb }
        return cbs.map(Peripheral.init)
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

    nonisolated func readValue(peripheralID: UUID, characteristicID: CBUUID) async throws -> Data { throw BluetoothError.poweredOff }
    nonisolated func writeValue(data: Data, peripheralID: UUID, characteristicID: CBUUID, type: CBCharacteristicWriteType) async throws { throw BluetoothError.poweredOff }
    nonisolated func setNotify(enabled: Bool, peripheralID: UUID, characteristicID: CBUUID) async throws { throw BluetoothError.poweredOff }

    // Testing helpers — internal access for @testable import. Do not call from production.
    func injectPeripheralForTest(id: UUID, connection: any PeripheralConnection) {
        peripherals[id] = connection
    }

    func completeDiscoverServicesForTest(peripheralID: UUID, services: [Service]) {
        if let cont = pendingDiscoverServices.removeValue(forKey: peripheralID) {
            cont.resume(returning: services)
        }
    }

    // MARK: - Private helpers

    private func preflightCheck() throws {
        nonisolated(unsafe) let mgr: any CentralManaging = manager
        switch mgr.state {
        case .poweredOn: return
        case .poweredOff: throw BluetoothError.poweredOff
        case .unsupported: throw BluetoothError.unsupported
        case .unauthorized: throw BluetoothError.unauthorized(CBManager.authorization)
        case .unknown, .resetting: return
        @unknown default: return
        }
    }

    private func lookupPeripheral(id: UUID) -> (any PeripheralConnection)? {
        let cbs = manager.retrievePeripherals(withIdentifiers: [id])
        if let cb = cbs.first {
            peripherals[id] = cb
            return cb
        }
        return nil
    }

    // MARK: - Private actor-isolated registration helpers

    private func registerStateContinuation(_ token: UUID, continuation: AsyncStream<CBManagerState>.Continuation) {
        stateContinuations[token] = continuation
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

    private func handleDidUpdateState(_ state: CBManagerState) {
        for cont in stateContinuations.values { cont.yield(state) }
        emit(.didUpdateState(state))
    }

    private func recordDiscoveredPeripheral(cbPeripheral: CBPeripheral, ad: AdvertisementData, rssi: Int) {
        let id = cbPeripheral.identifier
        let peripheral = Peripheral(cbPeripheral)
        peripherals[id] = cbPeripheral
        let discovered = DiscoveredPeripheral(peripheral: peripheral, advertisementData: ad, rssi: rssi)
        scanContinuation?.yield(discovered)
        emit(.didDiscover(discovered))
    }

    private func handleDidConnect(cbPeripheral: CBPeripheral) {
        let id = cbPeripheral.identifier
        let peripheral = Peripheral(cbPeripheral)
        peripherals[id] = cbPeripheral
        cbPeripheral.delegate = peripheralDelegate
        emit(.didConnect(peripheral))
        if let cont = pendingConnect.removeValue(forKey: id) {
            cont.resume(returning: peripheral)
        }
    }

    private func handleDidFailToConnect(cbPeripheral: CBPeripheral, nsError: NSError?) {
        let id = cbPeripheral.identifier
        let peripheral = Peripheral(cbPeripheral)
        let err = BluetoothError.connectionFailed(peripheralID: id, underlying: nsError)
        emit(.didFailToConnect(peripheral, err))
        if let cont = pendingConnect.removeValue(forKey: id) {
            cont.resume(throwing: err)
        }
    }

    private func handleDidDisconnect(cbPeripheral: CBPeripheral, nsError: NSError?) {
        let id = cbPeripheral.identifier
        let peripheral = Peripheral(cbPeripheral)
        peripherals.removeValue(forKey: id)
        let btError = nsError.map { BluetoothError.disconnected(peripheralID: id, underlying: $0) }
        emit(.didDisconnect(peripheral, btError))
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

    private func handleDidDiscoverCharacteristics(peripheralID: UUID, serviceID: CBUUID, characteristics: [Characteristic], nsError: NSError?) {
        let key = "\(peripheralID.uuidString):\(serviceID.uuidString)"
        if let cont = pendingDiscoverCharacteristics.removeValue(forKey: key) {
            if let nsError {
                cont.resume(throwing: BluetoothError(nsError))
            } else {
                cont.resume(returning: characteristics)
            }
        }
    }

    private func handleDidUpdateValue(peripheralID: UUID, characteristicID: CBUUID, data: Data?, nsError: NSError?) {
        let key = "\(peripheralID)/\(characteristicID)"
        if let nsError {
            let err = BluetoothError(nsError)
            if let cont = pendingReads.removeValue(forKey: key) {
                cont.resume(throwing: err)
            }
            notificationContinuations[key]?.yield(with: .failure(err))
        } else if let data {
            if let cont = pendingReads.removeValue(forKey: key) {
                cont.resume(returning: data)
            } else {
                notificationContinuations[key]?.yield(data)
            }
        }
    }

    private func handleDidWriteValue(peripheralID: UUID, characteristicID: CBUUID, nsError: NSError?) {
        let key = "\(peripheralID)/\(characteristicID)"
        if let cont = pendingWrites.removeValue(forKey: key) {
            if let nsError {
                cont.resume(throwing: BluetoothError(nsError))
            } else {
                cont.resume()
            }
        }
    }

    private func handleDidUpdateNotificationState(peripheralID: UUID, characteristicID: CBUUID, nsError: NSError?) {
        let key = "\(peripheralID)/\(characteristicID)"
        if let cont = pendingNotify.removeValue(forKey: key) {
            if let nsError {
                cont.resume(throwing: BluetoothError(nsError))
            } else {
                cont.resume()
            }
        }
    }
}
