@preconcurrency import CoreBluetooth
import Foundation
@testable import FCBComposable

final class FakePeripheralConnection: NSObject, PeripheralConnection, @unchecked Sendable {
    let identifier: UUID
    var name: String?
    var state: CBPeripheralState = .disconnected
    var services: [CBService]?
    weak var delegate: CBPeripheralDelegate?

    private(set) var discoverServicesCalls: [[CBUUID]?] = []
    private(set) var discoverCharacteristicsCalls: [(uuids: [CBUUID]?, service: CBService)] = []
    private(set) var readCalls: [CBCharacteristic] = []
    private(set) var writeCalls: [(data: Data, characteristic: CBCharacteristic, type: CBCharacteristicWriteType)] = []
    private(set) var notifyCalls: [(enabled: Bool, characteristic: CBCharacteristic)] = []

    init(identifier: UUID = UUID(), name: String? = nil) {
        self.identifier = identifier
        self.name = name
    }

    func discoverServices(_ serviceUUIDs: [CBUUID]?) { discoverServicesCalls.append(serviceUUIDs) }
    func discoverCharacteristics(_ characteristicUUIDs: [CBUUID]?, for service: CBService) {
        discoverCharacteristicsCalls.append((characteristicUUIDs, service))
    }
    func readValue(for characteristic: CBCharacteristic) { readCalls.append(characteristic) }
    func writeValue(_ data: Data, for characteristic: CBCharacteristic, type: CBCharacteristicWriteType) {
        writeCalls.append((data, characteristic, type))
    }
    func setNotifyValue(_ enabled: Bool, for characteristic: CBCharacteristic) {
        notifyCalls.append((enabled, characteristic))
    }

    func simulateDidDiscoverServices(error: NSError? = nil) {
        delegate?.peripheral?(unsafeBitCast(self, to: CBPeripheral.self), didDiscoverServices: error)
    }
    func simulateDidDiscoverCharacteristics(for service: CBService, error: NSError? = nil) {
        delegate?.peripheral?(unsafeBitCast(self, to: CBPeripheral.self), didDiscoverCharacteristicsFor: service, error: error)
    }
    func simulateDidUpdateValue(for characteristic: CBCharacteristic, error: NSError? = nil) {
        delegate?.peripheral?(unsafeBitCast(self, to: CBPeripheral.self), didUpdateValueFor: characteristic, error: error)
    }
    func simulateDidWriteValue(for characteristic: CBCharacteristic, error: NSError? = nil) {
        delegate?.peripheral?(unsafeBitCast(self, to: CBPeripheral.self), didWriteValueFor: characteristic, error: error)
    }
    func simulateDidUpdateNotificationState(for characteristic: CBCharacteristic, error: NSError? = nil) {
        delegate?.peripheral?(unsafeBitCast(self, to: CBPeripheral.self), didUpdateNotificationStateFor: characteristic, error: error)
    }
}
