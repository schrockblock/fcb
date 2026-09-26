import ComposableArchitecture
@preconcurrency import CoreBluetooth
import FCB
import Foundation

/// Thread-safe storage for CBATTRequest objects keyed by UUID.
/// CBATTRequest is not Sendable, so we isolate access behind a lock
/// and declare @unchecked Sendable since all access is synchronized.
private final class ATTRequestStore: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [UUID: CBATTRequest] = [:]

    func store(_ request: CBATTRequest, for id: UUID) {
        lock.withLock { storage[id] = request }
    }

    func remove(for id: UUID) -> CBATTRequest? {
        lock.withLock { storage.removeValue(forKey: id) }
    }
}

extension BluetoothPeripheralClient: DependencyKey {
    public static let liveValue: BluetoothPeripheralClient = {
        let actor = PeripheralRoleActor(manager: CBPeripheralManager(delegate: nil, queue: nil))
        return makeClient(actor: actor)
    }()

    static func makeClient(actor: PeripheralRoleActor) -> BluetoothPeripheralClient {
        BluetoothPeripheralClient(
            state: { actor.stateStream() },
            authorization: { CBManager.authorization },
            add: { service in try await actor.add(service: service) },
            remove: { id in await actor.remove(serviceID: id) },
            removeAll: { await actor.removeAll() },
            startAdvertising: { data in try await actor.startAdvertising(data: data) },
            stopAdvertising: { await actor.stopAdvertising() },
            isAdvertising: { await actor.isAdvertising() },
            respond: { reqID, result in await actor.respond(requestID: reqID, result: result) },
            updateValue: { data, cid, centralIDs in try await actor.updateValue(data: data, characteristicID: cid, centralIDs: centralIDs) },
            publishL2CAPChannel: { encryption in try await actor.publishL2CAPChannel(withEncryption: encryption) },
            unpublishL2CAPChannel: { psm in await actor.unpublishL2CAPChannel(psm: psm) },
            l2capConnections: { actor.l2capConnectionsStream() },
            readRequests: { actor.readRequestsStream() },
            writeRequests: { actor.writeRequestsStream() },
            subscriptions: { actor.subscriptionsStream() },
            events: { actor.eventStream() }
        )
    }
}

final actor PeripheralRoleActor {
    private let manager: any PeripheralManaging
    private let delegate = FCBPeripheralManagerDelegate()
    // CBATTRequest is not Sendable; we store it outside actor isolation in a
    // lock-protected store so it can be captured safely across task boundaries.
    private let attRequestStore = ATTRequestStore()

    private var services: [CBUUID: CBMutableService] = [:]
    private var characteristics: [CBUUID: CBMutableCharacteristic] = [:]
    private var centrals: [UUID: CBCentral] = [:]

    private var stateContinuations: [UUID: AsyncStream<CBManagerState>.Continuation] = [:]
    private var eventContinuations: [UUID: AsyncStream<PeripheralManagerEvent>.Continuation] = [:]
    private var readRequestContinuations: [UUID: AsyncStream<ReadRequest>.Continuation] = [:]
    private var writeRequestContinuations: [UUID: AsyncStream<[WriteRequest]>.Continuation] = [:]
    private var subscriptionContinuations: [UUID: AsyncStream<SubscriptionEvent>.Continuation] = [:]

    private var pendingAddService: [CBUUID: CheckedContinuation<Service, any Error>] = [:]
    private var pendingStartAdvertising: CheckedContinuation<Void, any Error>?
    private var pendingPublishL2CAP: CheckedContinuation<UInt16, any Error>?
    private var l2capConnectionContinuations: [UUID: AsyncStream<L2CAPConnection>.Continuation] = [:]

    init(manager: any PeripheralManaging) {
        self.manager = manager
        Task { await self.wireDelegate() }
    }

    private func wireDelegate() {
        manager.delegate = delegate
        // Capture manager as nonisolated(unsafe) so the @Sendable closure can read
        // `state` synchronously. This is safe: manager is a let, `state` is read-only,
        // and FakePeripheralManager sets state before firing the delegate.
        nonisolated(unsafe) let mgr: any PeripheralManaging = manager
        delegate.onDidUpdateState = { [weak self] _ in
            // Read state from the captured manager reference rather than from the
            // CBPeripheralManager argument (which may be an unsafeBitCast'd fake in tests).
            let state = mgr.state
            Task { await self?.handleDidUpdateState(state) }
        }
        delegate.onDidAddService = { [weak self] _, cbService, error in
            let mappedService = Service(cbService)
            let nsError = error as NSError?
            let svcID = cbService.uuid
            Task { await self?.handleDidAddService(serviceID: svcID, service: mappedService, error: nsError) }
        }
        delegate.onDidStartAdvertising = { [weak self] _, error in
            let nsError = error as NSError?
            Task { await self?.handleDidStartAdvertising(error: nsError) }
        }
        delegate.onDidReceiveRead = { [weak self] _, cbReq in
            guard let self else { return }
            let id = UUID()
            self.attRequestStore.store(cbReq, for: id)
            let centralValue = Central(cbReq.central)
            let characteristicValue = Characteristic(cbReq.characteristic)
            let offset = cbReq.offset
            Task { await self.handleDidReceiveRead(id: id, central: centralValue, characteristic: characteristicValue, offset: offset) }
        }
        delegate.onDidReceiveWrite = { [weak self] _, cbRequests in
            guard let self else { return }
            var items: [(id: UUID, central: Central, characteristic: Characteristic, offset: Int, value: Data?)] = []
            for req in cbRequests {
                let id = UUID()
                self.attRequestStore.store(req, for: id)
                items.append((id, Central(req.central), Characteristic(req.characteristic), req.offset, req.value))
            }
            Task { await self.handleDidReceiveWrite(items: items) }
        }
        delegate.onDidSubscribeToCharacteristic = { [weak self] _, cbCentral, cbCharacteristic in
            let central = Central(cbCentral)
            let characteristic = Characteristic(cbCharacteristic)
            let centralID = central.id
            Task { await self?.handleDidSubscribe(centralID: centralID, cbCentral: cbCentral, central: central, characteristic: characteristic) }
        }
        delegate.onDidUnsubscribeFromCharacteristic = { [weak self] _, cbCentral, cbCharacteristic in
            let central = Central(cbCentral)
            let characteristic = Characteristic(cbCharacteristic)
            Task { await self?.handleDidUnsubscribe(central: central, characteristic: characteristic) }
        }
        delegate.onIsReadyToUpdateSubscribers = { [weak self] _ in
            Task { await self?.handleIsReadyToUpdateSubscribers() }
        }
        delegate.onDidPublishL2CAPChannel = { [weak self] _, psm, error in
            let nsError = error as NSError?
            let value = UInt16(psm)
            Task { await self?.handleDidPublishL2CAP(psm: value, error: nsError) }
        }
        delegate.onDidOpenL2CAPChannel = { [weak self] _, channel, error in
            // Extraction shim: pull Sendable metadata + the stream pair out of the
            // non-instantiable CBL2CAPChannel here; the actor path takes raw pieces
            // so tests can inject bound pairs directly.
            guard error == nil, let channel else { return }
            let peerID = channel.peer.identifier
            let psm = UInt16(channel.psm)
            nonisolated(unsafe) let input: InputStream = channel.inputStream
            nonisolated(unsafe) let output: OutputStream = channel.outputStream
            // The channel object must outlive the streams: CoreBluetooth closes
            // the channel when it is deallocated. The pump owns it.
            let owner = RetainedObject(channel)
            Task { await self?.handleInboundL2CAPChannel(peerID: peerID, psm: psm, input: input, output: output, retaining: owner) }
        }
    }

    // MARK: - State and event streams

    nonisolated func stateStream() -> AsyncStream<CBManagerState> {
        AsyncStream<CBManagerState> { continuation in
            let token = UUID()
            Task { await self.registerStateContinuation(token, continuation: continuation) }
            continuation.onTermination = { _ in Task { await self.unregisterStateContinuation(token) } }
        }
    }

    nonisolated func eventStream() -> AsyncStream<PeripheralManagerEvent> {
        AsyncStream<PeripheralManagerEvent> { continuation in
            let token = UUID()
            Task { await self.registerEventContinuation(token, continuation: continuation) }
            continuation.onTermination = { _ in Task { await self.unregisterEventContinuation(token) } }
        }
    }

    // MARK: - Read/write/subscription streams

    nonisolated func readRequestsStream() -> AsyncStream<ReadRequest> {
        AsyncStream<ReadRequest> { continuation in
            let token = UUID()
            Task { await self.registerReadRequestContinuation(token, continuation: continuation) }
            continuation.onTermination = { _ in Task { await self.unregisterReadRequestContinuation(token) } }
        }
    }

    nonisolated func writeRequestsStream() -> AsyncStream<[WriteRequest]> {
        AsyncStream<[WriteRequest]> { continuation in
            let token = UUID()
            Task { await self.registerWriteRequestContinuation(token, continuation: continuation) }
            continuation.onTermination = { _ in Task { await self.unregisterWriteRequestContinuation(token) } }
        }
    }

    nonisolated func subscriptionsStream() -> AsyncStream<SubscriptionEvent> {
        AsyncStream<SubscriptionEvent> { continuation in
            let token = UUID()
            Task { await self.registerSubscriptionContinuation(token, continuation: continuation) }
            continuation.onTermination = { _ in Task { await self.unregisterSubscriptionContinuation(token) } }
        }
    }

    // MARK: - Service management

    func add(service: MutableService) async throws -> Service {
        try preflightCheck()
        let cb = service.toCB()
        services[service.id] = cb
        if let chars = cb.characteristics {
            for char in chars {
                if let mc = char as? CBMutableCharacteristic {
                    characteristics[char.uuid] = mc
                }
            }
        }
        return try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Service, any Error>) in
            pendingAddService[service.id] = cont
            manager.add(cb)
        }
    }

    func remove(serviceID: CBUUID) async {
        guard let cb = services.removeValue(forKey: serviceID) else { return }
        manager.remove(cb)
    }

    func removeAll() async {
        services.removeAll()
        characteristics.removeAll()
        manager.removeAllServices()
    }

    // MARK: - Advertising

    func startAdvertising(data: AdvertisementData?) async throws {
        try preflightCheck()
        let dict = advertisementDictionary(from: data)
        return try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, any Error>) in
            pendingStartAdvertising = cont
            manager.startAdvertising(dict)
        }
    }

    func stopAdvertising() async {
        manager.stopAdvertising()
    }

    func isAdvertising() async -> Bool {
        nonisolated(unsafe) let mgr: any PeripheralManaging = manager
        return mgr.isAdvertising
    }

    private func advertisementDictionary(from data: AdvertisementData?) -> [String: Any]? {
        guard let data else { return nil }
        var dict: [String: Any] = [:]
        if let localName = data.localName { dict[CBAdvertisementDataLocalNameKey] = localName }
        if !data.serviceUUIDs.isEmpty { dict[CBAdvertisementDataServiceUUIDsKey] = data.serviceUUIDs }
        return dict
    }

    // MARK: - Respond and updateValue

    func respond(requestID: UUID, result: CBATTError.Code) async {
        guard let cbReq = attRequestStore.remove(for: requestID) else { return }
        manager.respond(to: cbReq, withResult: result)
    }

    func updateValue(data: Data, characteristicID: CBUUID, centralIDs: [UUID]?) async throws -> Bool {
        try preflightCheck()
        guard let char = characteristics[characteristicID] else {
            throw BluetoothError.unknownCharacteristic(characteristicID, serviceID: CBUUID())
        }
        let cbCentrals: [CBCentral]? = centralIDs?.compactMap { centrals[$0] }
        return manager.updateValue(data, for: char, onSubscribedCentrals: cbCentrals)
    }

    // MARK: - Private registration helpers

    private func registerStateContinuation(_ token: UUID, continuation: AsyncStream<CBManagerState>.Continuation) {
        stateContinuations[token] = continuation
        // Replay the manager's current state so late subscribers don't wait
        // forever for a transition that fired before they attached.
        continuation.yield(manager.state)
    }
    private func unregisterStateContinuation(_ token: UUID) {
        stateContinuations.removeValue(forKey: token)
    }
    private func registerEventContinuation(_ token: UUID, continuation: AsyncStream<PeripheralManagerEvent>.Continuation) {
        eventContinuations[token] = continuation
    }
    private func unregisterEventContinuation(_ token: UUID) {
        eventContinuations.removeValue(forKey: token)
    }
    private func registerReadRequestContinuation(_ token: UUID, continuation: AsyncStream<ReadRequest>.Continuation) {
        readRequestContinuations[token] = continuation
    }
    private func unregisterReadRequestContinuation(_ token: UUID) {
        readRequestContinuations.removeValue(forKey: token)
    }
    private func registerWriteRequestContinuation(_ token: UUID, continuation: AsyncStream<[WriteRequest]>.Continuation) {
        writeRequestContinuations[token] = continuation
    }
    private func unregisterWriteRequestContinuation(_ token: UUID) {
        writeRequestContinuations.removeValue(forKey: token)
    }
    private func registerSubscriptionContinuation(_ token: UUID, continuation: AsyncStream<SubscriptionEvent>.Continuation) {
        subscriptionContinuations[token] = continuation
    }
    private func unregisterSubscriptionContinuation(_ token: UUID) {
        subscriptionContinuations.removeValue(forKey: token)
    }
    private func emit(_ event: PeripheralManagerEvent) {
        for cont in eventContinuations.values { cont.yield(event) }
    }
    private func preflightCheck() throws {
        nonisolated(unsafe) let mgr: any PeripheralManaging = manager
        switch mgr.state {
        case .poweredOn: return
        case .poweredOff: throw BluetoothError.poweredOff
        case .unsupported: throw BluetoothError.unsupported
        case .unauthorized: throw BluetoothError.unauthorized(CBManager.authorization)
        case .unknown, .resetting: return
        @unknown default: return
        }
    }

    // MARK: - Delegate handlers

    func handleDidUpdateState(_ state: CBManagerState) {
        for cont in stateContinuations.values { cont.yield(state) }
        emit(.didUpdateState(state))
    }

    func handleDidAddService(serviceID: CBUUID, service: Service, error: NSError?) {
        let mappedError = error.map { BluetoothError($0) }
        emit(.didAddService(service, error: mappedError))
        if let cont = pendingAddService.removeValue(forKey: serviceID) {
            if let err = mappedError {
                cont.resume(throwing: err)
            } else {
                cont.resume(returning: service)
            }
        }
    }

    func handleDidStartAdvertising(error: NSError?) {
        let mappedError = error.map { BluetoothError($0) }
        emit(.didStartAdvertising(error: mappedError))
        if let cont = pendingStartAdvertising {
            pendingStartAdvertising = nil
            if let err = mappedError {
                cont.resume(throwing: err)
            } else {
                cont.resume(returning: ())
            }
        }
    }

    func handleDidReceiveRead(id: UUID, central: Central, characteristic: Characteristic, offset: Int) {
        let mapped = ReadRequest(id: id, central: central, characteristic: characteristic, offset: offset)
        for cont in readRequestContinuations.values { cont.yield(mapped) }
        emit(.didReceiveRead(mapped))
    }

    func handleDidReceiveWrite(items: [(id: UUID, central: Central, characteristic: Characteristic, offset: Int, value: Data?)]) {
        let mapped: [WriteRequest] = items.map { item in
            WriteRequest(id: item.id, central: item.central, characteristic: item.characteristic, offset: item.offset, value: item.value)
        }
        for cont in writeRequestContinuations.values { cont.yield(mapped) }
        emit(.didReceiveWrite(mapped))
    }

    func handleDidSubscribe(centralID: UUID, cbCentral: CBCentral, central: Central, characteristic: Characteristic) {
        centrals[centralID] = cbCentral
        let event = SubscriptionEvent.subscribed(central: central, characteristic: characteristic)
        for cont in subscriptionContinuations.values { cont.yield(event) }
        emit(.didSubscribeToCharacteristic(central, characteristic: characteristic))
    }

    func handleDidUnsubscribe(central: Central, characteristic: Characteristic) {
        let event = SubscriptionEvent.unsubscribed(central: central, characteristic: characteristic)
        for cont in subscriptionContinuations.values { cont.yield(event) }
        emit(.didUnsubscribeFromCharacteristic(central, characteristic: characteristic))
    }

    func handleIsReadyToUpdateSubscribers() {
        emit(.isReadyToUpdateSubscribers)
    }

    // MARK: - L2CAP publish/unpublish + inbound connections

    nonisolated func l2capConnectionsStream() -> AsyncStream<L2CAPConnection> {
        AsyncStream<L2CAPConnection> { continuation in
            let token = UUID()
            Task { await self.registerL2CAPContinuation(token, continuation: continuation) }
            continuation.onTermination = { _ in Task { await self.unregisterL2CAPContinuation(token) } }
        }
    }

    func publishL2CAPChannel(withEncryption encryptionRequired: Bool) async throws -> UInt16 {
        try preflightCheck()
        return try await withCheckedThrowingContinuation { (cont: CheckedContinuation<UInt16, any Error>) in
            pendingPublishL2CAP = cont
            manager.publishL2CAPChannel(withEncryption: encryptionRequired)
        }
    }

    func unpublishL2CAPChannel(psm: UInt16) async {
        manager.unpublishL2CAPChannel(CBL2CAPPSM(psm))
    }

    private func registerL2CAPContinuation(_ token: UUID, continuation: AsyncStream<L2CAPConnection>.Continuation) {
        l2capConnectionContinuations[token] = continuation
    }

    private func unregisterL2CAPContinuation(_ token: UUID) {
        l2capConnectionContinuations.removeValue(forKey: token)
    }

    func handleDidPublishL2CAP(psm: UInt16, error: NSError?) {
        if let cont = pendingPublishL2CAP {
            pendingPublishL2CAP = nil
            if let error {
                cont.resume(throwing: BluetoothError(error))
            } else {
                cont.resume(returning: psm)
            }
        }
    }

    func handleInboundL2CAPChannel(peerID: UUID, psm: UInt16, input: InputStream, output: OutputStream,
                                   retaining owner: RetainedObject? = nil) {
        let pump = L2CAPChannelPump(input: input, output: output, retaining: owner)
        let connection = L2CAPConnection.make(pump: pump, peerID: peerID, psm: psm)
        for cont in l2capConnectionContinuations.values { cont.yield(connection) }
    }

    func simulateInboundL2CAPChannelForTest(peerID: UUID, psm: UInt16, input: InputStream, output: OutputStream) {
        handleInboundL2CAPChannel(peerID: peerID, psm: psm, input: input, output: output)
    }

    // MARK: - Test support

    func injectServiceForTest(id: CBUUID, service: CBMutableService) {
        services[id] = service
    }

    func injectRequestForTest(id: UUID, request: CBATTRequest) {
        attRequestStore.store(request, for: id)
    }
}
