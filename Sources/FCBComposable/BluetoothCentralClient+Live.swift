import ComposableArchitecture
@preconcurrency import CoreBluetooth
@preconcurrency import CoreBluetoothMock
import Foundation

extension BluetoothCentralClient: DependencyKey {
    public static let liveValue: BluetoothCentralClient = {
        // CBMCentralManagerFactory returns the native passthrough manager on
        // device, or the mock when a simulation is active and mock is forced.
        let actor = CentralActor(manager: CBMCentralManagerFactory.instance())
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
            maximumWriteValueLength: { pid, type in await actor.maximumWriteValueLength(peripheralID: pid, type: type) },
            notifications: { pid, cid in actor.notifications(peripheralID: pid, characteristicID: cid) },
            openL2CAPChannel: { pid, psm in try await actor.openL2CAPChannel(peripheralID: pid, psm: psm) },
            events: { actor.eventStream() }
        )
    }
}

extension BluetoothCentralClient {
    /// A live client backed by `CBMCentralManagerMock`. Configure the simulation
    /// FIRST via `CBMCentralManagerMock.simulateInitialState(_:)` and
    /// `CBMCentralManagerMock.simulatePeripherals(_:)`, then create the client.
    /// Intended for integration tests and Simulator builds; FCB does not wrap
    /// CBM's simulation API — script `CBMPeripheralSpec`s directly.
    public static func mocked() -> BluetoothCentralClient {
        makeClient(actor: CentralActor(manager: CBMCentralManagerFactory.instance(forceMock: true)))
    }
}

final actor CentralActor {
    private let manager: CBMCentralManager
    private let delegate = FCBMCentralManagerDelegate()
    private var peripheralDelegate = FCBMPeripheralDelegate()

    private var peripherals: [UUID: any CBMPeripheral] = [:]
    private var characteristics: [String: CBMCharacteristic] = [:]

    // Stream continuations
    private var stateContinuations: [UUID: AsyncStream<CBManagerState>.Continuation] = [:]
    private var eventContinuations: [UUID: AsyncStream<CentralEvent>.Continuation] = [:]
    private var scanContinuation: AsyncStream<DiscoveredPeripheral>.Continuation?
    /// Token identifying the current active scan. A stale `endScan(token:)` call
    /// from a superseded scan stream is ignored when its token no longer matches.
    private var currentScanToken: UUID?
    private var notificationContinuations: [String: AsyncThrowingStream<Data, any Error>.Continuation] = [:]

    // Pending operation continuations
    private var pendingConnect: [UUID: CheckedContinuation<Peripheral, any Error>] = [:]
    /// Every caller waiting on a disconnect of that peripheral; all resume on
    /// the one `didDisconnect`.
    private var pendingDisconnect: [UUID: [CheckedContinuation<Void, any Error>]] = [:]
    private var pendingDiscoverServices: [UUID: CheckedContinuation<[Service], any Error>] = [:]
    private var pendingDiscoverCharacteristics: [String: CheckedContinuation<[Characteristic], any Error>] = [:]
    private var pendingReads: [String: CheckedContinuation<Data, any Error>] = [:]
    private var pendingWrites: [String: CheckedContinuation<Void, any Error>] = [:]
    private var pendingNotify: [String: CheckedContinuation<Void, any Error>] = [:]
    private var pendingOpenL2CAP: [UUID: CheckedContinuation<L2CAPConnection, any Error>] = [:]

    init(manager: CBMCentralManager) {
        self.manager = manager
        // Wire delegates synchronously so manager.delegate (and all closures)
        // are set before any public method can be called from the outside.
        // This avoids a race where connect() fires CBM's manager.connect() before
        // the delegate assignment has run, causing callbacks to be dropped.
        manager.delegate = delegate
        nonisolated(unsafe) let weakDelegate = delegate
        nonisolated(unsafe) let weakPeriphDelegate = peripheralDelegate
        // Each closure captures [weak self] to break the actor→delegate→closure→actor
        // retain cycle. All handlers re-enter the actor via Task { await self?.handle... }
        // so there is no concurrent access to actor state from these captures.
        weakDelegate.onDidUpdateState = { [weak self] central in
            let state = central.state
            Task { await self?.handleDidUpdateState(state) }
        }
        weakDelegate.onDidDiscover = { [weak self] _, peripheral, ad, rssi in
            let advertisementData = AdvertisementData(dictionary: ad)
            let rssiInt = rssi.intValue
            nonisolated(unsafe) let p = peripheral
            Task { await self?.recordDiscoveredPeripheral(peripheral: p, ad: advertisementData, rssi: rssiInt) }
        }
        weakDelegate.onDidConnect = { [weak self] _, peripheral in
            nonisolated(unsafe) let p = peripheral
            Task { await self?.handleDidConnect(peripheral: p) }
        }
        weakDelegate.onDidFailToConnect = { [weak self] _, peripheral, error in
            let nsError = error.map { $0 as NSError }
            nonisolated(unsafe) let p = peripheral
            Task { await self?.handleDidFailToConnect(peripheral: p, nsError: nsError) }
        }
        weakDelegate.onDidDisconnect = { [weak self] _, peripheral, error in
            let nsError = error.map { $0 as NSError }
            nonisolated(unsafe) let p = peripheral
            Task { await self?.handleDidDisconnect(peripheral: p, nsError: nsError) }
        }
        weakPeriphDelegate.onDidDiscoverServices = { [weak self] peripheral, error in
            let id = peripheral.identifier
            let services = peripheral.services?.map { Service($0, peripheralID: id) } ?? []
            let nsError = error.map { $0 as NSError }
            Task { await self?.handleDidDiscoverServices(id: id, services: services, nsError: nsError) }
        }
        weakPeriphDelegate.onDidDiscoverCharacteristics = { [weak self] peripheral, service, error in
            let pid = peripheral.identifier
            let serviceID = service.uuid
            nonisolated(unsafe) let cbmChars: [CBMCharacteristic] = service.characteristics ?? []
            let valueTypes = cbmChars.map { Characteristic($0, peripheralID: pid) }
            let nsError = error.map { $0 as NSError }
            Task { await self?.handleDidDiscoverCharacteristics(peripheralID: pid, serviceID: serviceID, cbmCharacteristics: cbmChars, characteristics: valueTypes, error: nsError) }
        }
        weakPeriphDelegate.onDidUpdateValueForCharacteristic = { [weak self] peripheral, characteristic, error in
            let pid = peripheral.identifier
            let cid = characteristic.uuid
            let value = characteristic.value ?? Data()
            let nsError = error as NSError?
            Task { await self?.handleDidUpdateValue(peripheralID: pid, characteristicID: cid, value: value, error: nsError) }
        }
        weakPeriphDelegate.onDidWriteValueForCharacteristic = { [weak self] peripheral, characteristic, error in
            let pid = peripheral.identifier
            let cid = characteristic.uuid
            let nsError = error as NSError?
            Task { await self?.handleDidWriteValue(peripheralID: pid, characteristicID: cid, error: nsError) }
        }
        weakPeriphDelegate.onDidUpdateNotificationState = { [weak self] peripheral, characteristic, error in
            let pid = peripheral.identifier
            let cid = characteristic.uuid
            let nsError = error as NSError?
            Task { await self?.handleDidUpdateNotificationState(peripheralID: pid, characteristicID: cid, error: nsError) }
        }
        weakPeriphDelegate.onDidOpenL2CAPChannel = { [weak self] peripheral, channel, error in
            let pid = peripheral.identifier
            let nsError = error as NSError?
            if let channel, nsError == nil {
                let peerID = channel.peer.identifier
                let psm = UInt16(channel.psm)
                nonisolated(unsafe) let input: InputStream = channel.inputStream
                nonisolated(unsafe) let output: OutputStream = channel.outputStream
                Task { await self?.handleDidOpenL2CAP(peripheralID: pid, peerID: peerID, psm: psm, input: input, output: output) }
            } else {
                Task { await self?.handleDidFailOpenL2CAP(peripheralID: pid, nsError: nsError) }
            }
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
        let optionsCopy = options
        // Generate a unique token for this scan instance. The token is passed
        // to startScan (which records it as the current scan) and captured in
        // onTermination. endScan(token:) checks that the token still matches
        // the current scan before stopping — a stale termination from a
        // superseded stream cannot kill a newer scan.
        let token = UUID()
        return AsyncStream<DiscoveredPeripheral> { continuation in
            Task { await self.startScan(services: servicesCopy, options: optionsCopy, continuation: continuation, token: token) }
            continuation.onTermination = { _ in
                Task { await self.endScan(token: token) }
            }
        }
    }

    nonisolated func notifications(peripheralID: UUID, characteristicID: CBUUID) -> AsyncThrowingStream<Data, any Error> {
        AsyncThrowingStream<Data, any Error> { continuation in
            let key = "\(peripheralID.uuidString):\(characteristicID.uuidString)"
            Task { await self.registerNotificationContinuation(key: key, continuation: continuation) }
            continuation.onTermination = { _ in
                Task { await self.unregisterNotificationContinuation(key: key) }
            }
        }
    }

    func stopScan() async {
        manager.stopScan()
        scanContinuation?.finish()
        scanContinuation = nil
        currentScanToken = nil
    }

    func connect(id: UUID, options: ConnectOptions?) async throws -> Peripheral {
        try preflightCheck()
        let connection: any CBMPeripheral
        if let existing = peripherals[id] {
            connection = existing
        } else if let lookedUp = lookupPeripheral(id: id) {
            connection = lookedUp
        } else {
            throw BluetoothError.unknownPeripheral(id)
        }
        return try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Peripheral, any Error>) in
            pendingConnect[id] = cont
            manager.connect(connection, options: options?.dictionary)
        }
    }

    func disconnect(id: UUID) async throws {
        guard let connection = peripherals[id] else {
            throw BluetoothError.unknownPeripheral(id)
        }
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, any Error>) in
            // A concurrent second caller joins the in-flight disconnect and
            // shares its outcome; only the first caller cancels the connection.
            let isFirstCaller = pendingDisconnect[id, default: []].isEmpty
            pendingDisconnect[id, default: []].append(cont)
            if isFirstCaller {
                manager.cancelPeripheralConnection(connection)
            }
        }
    }

    func retrievePeripherals(ids: [UUID]) async -> [Peripheral] {
        let found = manager.retrievePeripherals(withIdentifiers: ids)
        for p in found { peripherals[p.identifier] = p }
        return found.map { Peripheral($0) }
    }

    func retrieveConnected(services: [CBUUID]) async -> [Peripheral] {
        let found = manager.retrieveConnectedPeripherals(withServices: services)
        for p in found { peripherals[p.identifier] = p }
        return found.map { Peripheral($0) }
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

    func readValue(peripheralID: UUID, characteristicID: CBUUID) async throws -> Data {
        try preflightCheck()
        let (connection, characteristic) = try resolve(peripheralID: peripheralID, characteristicID: characteristicID)
        let key = "\(peripheralID.uuidString):\(characteristicID.uuidString)"
        if pendingReads[key] != nil {
            throw BluetoothError.operationCancelled
        }
        return try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Data, any Error>) in
            pendingReads[key] = cont
            connection.readValue(for: characteristic)
        }
    }

    func writeValue(data: Data, peripheralID: UUID, characteristicID: CBUUID, type: CBCharacteristicWriteType) async throws {
        try preflightCheck()
        let (connection, characteristic) = try resolve(peripheralID: peripheralID, characteristicID: characteristicID)
        let key = "\(peripheralID.uuidString):\(characteristicID.uuidString)"
        if type == .withoutResponse {
            connection.writeValue(data, for: characteristic, type: .withoutResponse)
            return
        }
        return try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, any Error>) in
            pendingWrites[key] = cont
            connection.writeValue(data, for: characteristic, type: .withResponse)
        }
    }

    func setNotify(enabled: Bool, peripheralID: UUID, characteristicID: CBUUID) async throws {
        try preflightCheck()
        let (connection, characteristic) = try resolve(peripheralID: peripheralID, characteristicID: characteristicID)
        let key = "\(peripheralID.uuidString):\(characteristicID.uuidString)"
        return try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, any Error>) in
            pendingNotify[key] = cont
            connection.setNotifyValue(enabled, for: characteristic)
        }
    }

    func maximumWriteValueLength(peripheralID: UUID, type: CBCharacteristicWriteType) -> Int {
        guard let connection = peripherals[peripheralID] else { return 0 }
        return connection.maximumWriteValueLength(for: type)
    }

    func openL2CAPChannel(peripheralID: UUID, psm: UInt16) async throws -> L2CAPConnection {
        try preflightCheck()
        guard let connection = peripherals[peripheralID] else {
            throw BluetoothError.unknownPeripheral(peripheralID)
        }
        // CoreBluetoothMock cannot simulate L2CAP — its openL2CAPChannel is a
        // fatalError. Fail loudly-but-gracefully instead of crashing the process.
        guard !(connection is CBMPeripheralMock) else {
            throw BluetoothError.l2capNotSupported
        }
        if pendingOpenL2CAP[peripheralID] != nil {
            throw BluetoothError.operationCancelled
        }
        #if os(macOS)
        // openL2CAPChannel is unavailable on macOS (not part of CBMPeripheral on
        // this platform). Non-mock peripherals on macOS fall through here; throw
        // l2capNotSupported rather than crash or leave the continuation dangling.
        throw BluetoothError.l2capNotSupported
        #else
        return try await withCheckedThrowingContinuation { (cont: CheckedContinuation<L2CAPConnection, any Error>) in
            pendingOpenL2CAP[peripheralID] = cont
            connection.openL2CAPChannel(CBML2CAPPSM(psm))
        }
        #endif
    }

    private func handleDidOpenL2CAP(peripheralID: UUID, peerID: UUID, psm: UInt16, input: InputStream, output: OutputStream) {
        guard let cont = pendingOpenL2CAP.removeValue(forKey: peripheralID) else { return }
        let pump = L2CAPChannelPump(input: input, output: output)
        cont.resume(returning: L2CAPConnection.make(pump: pump, peerID: peerID, psm: psm))
    }

    private func handleDidFailOpenL2CAP(peripheralID: UUID, nsError: NSError?) {
        guard let cont = pendingOpenL2CAP.removeValue(forKey: peripheralID) else { return }
        if let nsError {
            cont.resume(throwing: BluetoothError(nsError))
        } else {
            cont.resume(throwing: BluetoothError.operationCancelled)
        }
    }

    // MARK: - Private helpers

    private func preflightCheck() throws {
        switch manager.state {
        case .poweredOn: return
        case .poweredOff: throw BluetoothError.poweredOff
        case .unsupported: throw BluetoothError.unsupported
        case .unauthorized: throw BluetoothError.unauthorized(CBManager.authorization)
        case .unknown, .resetting: return
        }
    }

    private func resolve(peripheralID: UUID, characteristicID: CBUUID) throws -> (any CBMPeripheral, CBMCharacteristic) {
        guard let connection = peripherals[peripheralID] else {
            throw BluetoothError.unknownPeripheral(peripheralID)
        }
        let key = "\(peripheralID.uuidString):\(characteristicID.uuidString)"
        guard let characteristic = characteristics[key] else {
            throw BluetoothError.unknownCharacteristic(characteristicID, serviceID: CBUUID())
        }
        return (connection, characteristic)
    }

    private func lookupPeripheral(id: UUID) -> (any CBMPeripheral)? {
        let found = manager.retrievePeripherals(withIdentifiers: [id])
        if let p = found.first {
            peripherals[id] = p
            return p
        }
        return nil
    }

    // MARK: - Private actor-isolated registration helpers

    private func registerStateContinuation(_ token: UUID, continuation: AsyncStream<CBManagerState>.Continuation) {
        stateContinuations[token] = continuation
        // Replay the manager's current state so subscribers that attach AFTER a
        // state transition (e.g. .poweredOn fired during app init, long before
        // the consumer's for-await began) don't wait forever for an event that
        // already happened.
        continuation.yield(CBManagerState(manager.state))
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

    private func registerNotificationContinuation(key: String, continuation: AsyncThrowingStream<Data, any Error>.Continuation) {
        notificationContinuations[key] = continuation
    }

    private func unregisterNotificationContinuation(key: String) {
        notificationContinuations.removeValue(forKey: key)
    }

    private func startScan(services: [CBUUID]?, options: ScanOptions?, continuation: AsyncStream<DiscoveredPeripheral>.Continuation, token: UUID) {
        scanContinuation = continuation
        currentScanToken = token
        manager.scanForPeripherals(withServices: services, options: options?.dictionary)
    }

    /// Stops the scan and clears the continuation ONLY when the token matches
    /// the current scan. A stale `endScan` from a superseded stream's
    /// `onTermination` is ignored — it must not kill a newer active scan.
    private func endScan(token: UUID) {
        guard currentScanToken == token else { return }
        manager.stopScan()
        scanContinuation = nil
        currentScanToken = nil
    }

    private func emit(_ event: CentralEvent) {
        for cont in eventContinuations.values { cont.yield(event) }
    }

    // MARK: - Delegate handlers (actor-isolated)

    private func handleDidUpdateState(_ state: CBMManagerState) {
        let bridged = CBManagerState(state)
        for cont in stateContinuations.values { cont.yield(bridged) }
        emit(.didUpdateState(bridged))
    }

    private func recordDiscoveredPeripheral(peripheral: any CBMPeripheral, ad: AdvertisementData, rssi: Int) {
        let id = peripheral.identifier
        let mapped = Peripheral(peripheral)
        peripherals[id] = peripheral
        let discovered = DiscoveredPeripheral(peripheral: mapped, advertisementData: ad, rssi: rssi)
        scanContinuation?.yield(discovered)
        emit(.didDiscover(discovered))
    }

    private func handleDidConnect(peripheral: any CBMPeripheral) {
        let id = peripheral.identifier
        let mapped = Peripheral(peripheral)
        peripherals[id] = peripheral
        peripheral.delegate = peripheralDelegate
        emit(.didConnect(mapped))
        if let cont = pendingConnect.removeValue(forKey: id) {
            cont.resume(returning: mapped)
        }
    }

    private func handleDidFailToConnect(peripheral: any CBMPeripheral, nsError: NSError?) {
        let id = peripheral.identifier
        let mapped = Peripheral(peripheral)
        let err = BluetoothError.connectionFailed(peripheralID: id, underlying: nsError)
        emit(.didFailToConnect(mapped, err))
        failPending(for: id, with: err)
    }

    private func handleDidDisconnect(peripheral: any CBMPeripheral, nsError: NSError?) {
        let id = peripheral.identifier
        let mapped = Peripheral(peripheral)
        peripherals.removeValue(forKey: id)
        let btError = nsError.map { BluetoothError.disconnected(peripheralID: id, underlying: $0) }
        emit(.didDisconnect(mapped, btError))
        failPending(for: id, with: .disconnected(peripheralID: id, underlying: nsError))
        for cont in pendingDisconnect.removeValue(forKey: id) ?? [] {
            if let btError {
                cont.resume(throwing: btError)
            } else {
                cont.resume()
            }
        }
    }

    /// The peripheral is gone: fail every operation still waiting on it with
    /// `error`, end its notification streams, and drop its cached
    /// characteristics (stale after a reconnect; discovery re-populates them).
    /// Nothing may stay suspended for a peripheral that is no longer connected.
    /// `pendingDisconnect` is not touched — `handleDidDisconnect` resolves it.
    private func failPending(for id: UUID, with error: BluetoothError) {
        let prefix = "\(id.uuidString):"
        pendingConnect.removeValue(forKey: id)?.resume(throwing: error)
        pendingDiscoverServices.removeValue(forKey: id)?.resume(throwing: error)
        pendingOpenL2CAP.removeValue(forKey: id)?.resume(throwing: error)
        for key in pendingDiscoverCharacteristics.keys where key.hasPrefix(prefix) {
            pendingDiscoverCharacteristics.removeValue(forKey: key)?.resume(throwing: error)
        }
        for key in pendingReads.keys where key.hasPrefix(prefix) {
            pendingReads.removeValue(forKey: key)?.resume(throwing: error)
        }
        for key in pendingWrites.keys where key.hasPrefix(prefix) {
            pendingWrites.removeValue(forKey: key)?.resume(throwing: error)
        }
        for key in pendingNotify.keys where key.hasPrefix(prefix) {
            pendingNotify.removeValue(forKey: key)?.resume(throwing: error)
        }
        for key in notificationContinuations.keys where key.hasPrefix(prefix) {
            notificationContinuations.removeValue(forKey: key)?.finish(throwing: error)
        }
        for key in characteristics.keys where key.hasPrefix(prefix) {
            characteristics.removeValue(forKey: key)
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

    private func handleDidDiscoverCharacteristics(peripheralID: UUID, serviceID: CBUUID, cbmCharacteristics: [CBMCharacteristic], characteristics newChars: [Characteristic], error: NSError?) {
        for c in cbmCharacteristics {
            let charKey = "\(peripheralID.uuidString):\(c.uuid.uuidString)"
            characteristics[charKey] = c
        }
        let key = "\(peripheralID.uuidString):\(serviceID.uuidString)"
        if let cont = pendingDiscoverCharacteristics.removeValue(forKey: key) {
            if let error {
                cont.resume(throwing: BluetoothError(error))
            } else {
                cont.resume(returning: newChars)
            }
        }
    }

    private func handleDidUpdateValue(peripheralID: UUID, characteristicID: CBUUID, value: Data, error: NSError?) {
        let key = "\(peripheralID.uuidString):\(characteristicID.uuidString)"
        if let cont = pendingReads.removeValue(forKey: key) {
            if let error {
                cont.resume(throwing: BluetoothError(error))
            } else {
                cont.resume(returning: value)
            }
        }
        if let notifCont = notificationContinuations[key] {
            if let error {
                notifCont.finish(throwing: BluetoothError(error))
            } else {
                notifCont.yield(value)
            }
        }
    }

    private func handleDidWriteValue(peripheralID: UUID, characteristicID: CBUUID, error: NSError?) {
        let key = "\(peripheralID.uuidString):\(characteristicID.uuidString)"
        if let cont = pendingWrites.removeValue(forKey: key) {
            if let error {
                cont.resume(throwing: BluetoothError(error))
            } else {
                cont.resume(returning: ())
            }
        }
    }

    private func handleDidUpdateNotificationState(peripheralID: UUID, characteristicID: CBUUID, error: NSError?) {
        let key = "\(peripheralID.uuidString):\(characteristicID.uuidString)"
        if let cont = pendingNotify.removeValue(forKey: key) {
            if let error {
                cont.resume(throwing: BluetoothError(error))
            } else {
                cont.resume(returning: ())
            }
        }
    }
}
