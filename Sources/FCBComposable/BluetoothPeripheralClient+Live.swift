import ComposableArchitecture
@preconcurrency import CoreBluetooth
import FCB
import Foundation

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

    private var services: [CBUUID: CBMutableService] = [:]
    private var characteristics: [CBUUID: CBMutableCharacteristic] = [:]
    private var pendingRequests: [UUID: CBATTRequest] = [:]
    private var centrals: [UUID: CBCentral] = [:]

    private var stateContinuations: [UUID: AsyncStream<CBManagerState>.Continuation] = [:]
    private var eventContinuations: [UUID: AsyncStream<PeripheralManagerEvent>.Continuation] = [:]
    private var readRequestContinuations: [UUID: AsyncStream<ReadRequest>.Continuation] = [:]
    private var writeRequestContinuations: [UUID: AsyncStream<[WriteRequest]>.Continuation] = [:]
    private var subscriptionContinuations: [UUID: AsyncStream<SubscriptionEvent>.Continuation] = [:]

    private var pendingAddService: [CBUUID: CheckedContinuation<Service, any Error>] = [:]
    private var pendingStartAdvertising: CheckedContinuation<Void, any Error>?

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

    // MARK: - Read/write/subscription streams (stubs for Tasks 22-23)

    nonisolated func readRequestsStream() -> AsyncStream<ReadRequest> { .never }
    nonisolated func writeRequestsStream() -> AsyncStream<[WriteRequest]> { .never }
    nonisolated func subscriptionsStream() -> AsyncStream<SubscriptionEvent> { .never }

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

    // MARK: - Advertising / other stubs (filled in by Tasks 22-23)

    nonisolated func startAdvertising(data: AdvertisementData?) async throws { throw BluetoothError.poweredOff }
    nonisolated func stopAdvertising() async {}
    nonisolated func isAdvertising() async -> Bool { false }
    nonisolated func respond(requestID: UUID, result: CBATTError.Code) async {}
    nonisolated func updateValue(data: Data, characteristicID: CBUUID, centralIDs: [UUID]?) async throws { throw BluetoothError.poweredOff }

    // MARK: - Private registration helpers

    private func registerStateContinuation(_ token: UUID, continuation: AsyncStream<CBManagerState>.Continuation) {
        stateContinuations[token] = continuation
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

    // MARK: - Test support

    func injectServiceForTest(id: CBUUID, service: CBMutableService) {
        services[id] = service
    }
}
