import ComposableArchitecture
@preconcurrency import CoreBluetooth
import Foundation

@DependencyClient
public struct BluetoothPeripheralClient: Sendable {
    public var state: @Sendable () -> AsyncStream<CBManagerState> = { .never }
    public var authorization: @Sendable () -> CBManagerAuthorization = { .notDetermined }

    public var add: @Sendable (_ service: MutableService) async throws -> Service
    public var remove: @Sendable (_ serviceID: CBUUID) async -> Void
    public var removeAll: @Sendable () async -> Void

    public var startAdvertising: @Sendable (_ data: AdvertisementData?) async throws -> Void
    public var stopAdvertising: @Sendable () async -> Void
    public var isAdvertising: @Sendable () async -> Bool = { false }

    public var respond: @Sendable (_ requestID: UUID, _ result: CBATTError.Code) async -> Void
    public var updateValue: @Sendable (_ data: Data, _ characteristicID: CBUUID, _ centralIDs: [UUID]?) async throws -> Void

    public var publishL2CAPChannel: @Sendable (_ withEncryption: Bool) async throws -> UInt16
    public var unpublishL2CAPChannel: @Sendable (_ psm: UInt16) async -> Void
    public var l2capConnections: @Sendable () -> AsyncStream<L2CAPConnection> = { .never }

    public var readRequests: @Sendable () -> AsyncStream<ReadRequest> = { .never }
    public var writeRequests: @Sendable () -> AsyncStream<[WriteRequest]> = { .never }
    public var subscriptions: @Sendable () -> AsyncStream<SubscriptionEvent> = { .never }

    public var events: @Sendable () -> AsyncStream<PeripheralManagerEvent> = { .never }
}

extension BluetoothPeripheralClient: TestDependencyKey {
    public static let testValue = BluetoothPeripheralClient()
}

extension DependencyValues {
    public var bluetoothPeripheralClient: BluetoothPeripheralClient {
        get { self[BluetoothPeripheralClient.self] }
        set { self[BluetoothPeripheralClient.self] = newValue }
    }
}
