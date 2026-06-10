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
        // Concrete closures filled in by Tasks 21-23; for now leave as empty placeholders
        // or no-op. The handlers themselves are all stubs below.
    }

    // MARK: - Stubs (filled in by Tasks 21-23)

    nonisolated func stateStream() -> AsyncStream<CBManagerState> { .never }
    nonisolated func eventStream() -> AsyncStream<PeripheralManagerEvent> { .never }
    nonisolated func readRequestsStream() -> AsyncStream<ReadRequest> { .never }
    nonisolated func writeRequestsStream() -> AsyncStream<[WriteRequest]> { .never }
    nonisolated func subscriptionsStream() -> AsyncStream<SubscriptionEvent> { .never }

    nonisolated func add(service: MutableService) async throws -> Service { throw BluetoothError.poweredOff }
    nonisolated func remove(serviceID: CBUUID) async {}
    nonisolated func removeAll() async {}
    nonisolated func startAdvertising(data: AdvertisementData?) async throws { throw BluetoothError.poweredOff }
    nonisolated func stopAdvertising() async {}
    nonisolated func isAdvertising() async -> Bool { false }
    nonisolated func respond(requestID: UUID, result: CBATTError.Code) async {}
    nonisolated func updateValue(data: Data, characteristicID: CBUUID, centralIDs: [UUID]?) async throws { throw BluetoothError.poweredOff }
}
