import ComposableArchitecture
@preconcurrency import CoreBluetooth
import Foundation

@DependencyClient
public struct BluetoothCentralClient: Sendable {
    public var state: @Sendable () -> AsyncStream<CBManagerState> = { .never }
    public var authorization: @Sendable () -> CBManagerAuthorization = { .notDetermined }

    /// Scans for peripherals advertising `services`. One radio scan per central:
    /// a newer `scan` supersedes this one and FINISHES this stream (its owner lost
    /// the radio). The stream also finishes when Bluetooth leaves `.poweredOn`
    /// (CoreBluetooth stops scanning and never resumes), and at once when the scan
    /// is requested while not powered on. Terminating the stream — cancelling the
    /// task iterating it, or dropping it — stops THIS scan only.
    public var scan: @Sendable (_ services: [CBUUID]?, _ options: ScanOptions?) -> AsyncStream<DiscoveredPeripheral> = { _, _ in .never }
    /// Does nothing; kept for source compatibility. A global stop ended whatever
    /// scan was current — another owner's included. Stop your own scan by
    /// terminating its stream (cancel the task iterating it).
    public var stopScan: @Sendable () async -> Void

    public var connect: @Sendable (_ id: UUID, _ options: ConnectOptions?) async throws -> Peripheral
    public var disconnect: @Sendable (_ id: UUID) async throws -> Void
    public var retrievePeripherals: @Sendable (_ ids: [UUID]) async -> [Peripheral] = { _ in [] }
    public var retrieveConnected: @Sendable (_ services: [CBUUID]) async -> [Peripheral] = { _ in [] }

    public var discoverServices: @Sendable (_ peripheralID: UUID, _ serviceIDs: [CBUUID]?) async throws -> [Service]
    public var discoverCharacteristics: @Sendable (_ peripheralID: UUID, _ serviceID: CBUUID, _ characteristicIDs: [CBUUID]?) async throws -> [Characteristic]

    public var readValue: @Sendable (_ peripheralID: UUID, _ characteristicID: CBUUID) async throws -> Data
    public var writeValue: @Sendable (_ data: Data, _ peripheralID: UUID, _ characteristicID: CBUUID, _ type: CBCharacteristicWriteType) async throws -> Void
    public var setNotify: @Sendable (_ enabled: Bool, _ peripheralID: UUID, _ characteristicID: CBUUID) async throws -> Void
    public var maximumWriteValueLength: @Sendable (_ peripheralID: UUID, _ type: CBCharacteristicWriteType) async -> Int = { _, _ in 20 }
    public var notifications: @Sendable (_ peripheralID: UUID, _ characteristicID: CBUUID) -> AsyncThrowingStream<Data, any Error> = { _, _ in .finished() }
    public var openL2CAPChannel: @Sendable (_ peripheralID: UUID, _ psm: UInt16) async throws -> L2CAPConnection

    public var events: @Sendable () -> AsyncStream<CentralEvent> = { .never }

    /// Whether the peripheral can accept a write-without-response right now
    /// (CoreBluetooth's `canSendWriteWithoutResponse`); `false` for an unknown
    /// peripheral. When it is `false`, wait for
    /// `CentralEvent.isReadyToSendWriteWithoutResponse` on `events`.
    /// Kept LAST so memberwise call sites only append one argument.
    public var canSendWriteWithoutResponse: @Sendable (_ peripheralID: UUID) async -> Bool = { _ in true }
}

extension BluetoothCentralClient: TestDependencyKey {
    public static let testValue = BluetoothCentralClient()
}

extension DependencyValues {
    public var bluetoothCentralClient: BluetoothCentralClient {
        get { self[BluetoothCentralClient.self] }
        set { self[BluetoothCentralClient.self] = newValue }
    }
}
