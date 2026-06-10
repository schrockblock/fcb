@preconcurrency import CoreBluetooth
import Foundation
@testable import FCBComposable

final class FakeCentralManager: NSObject, CentralManaging, @unchecked Sendable {
    var state: CBManagerState = .poweredOn
    weak var delegate: CBCentralManagerDelegate?

    private(set) var scanCalls: [(services: [CBUUID]?, options: [String: Any]?)] = []
    private(set) var stopScanCallCount = 0
    private(set) var connectCalls: [(peripheral: CBPeripheral, options: [String: Any]?)] = []
    private(set) var cancelCalls: [CBPeripheral] = []
    var registeredPeripherals: [UUID: CBPeripheral] = [:]

    func scanForPeripherals(withServices serviceUUIDs: [CBUUID]?, options: [String: Any]?) {
        scanCalls.append((serviceUUIDs, options))
    }
    func stopScan() { stopScanCallCount += 1 }
    func connect(_ peripheral: CBPeripheral, options: [String: Any]?) {
        connectCalls.append((peripheral, options))
    }
    func cancelPeripheralConnection(_ peripheral: CBPeripheral) { cancelCalls.append(peripheral) }
    func retrievePeripherals(withIdentifiers identifiers: [UUID]) -> [CBPeripheral] {
        identifiers.compactMap { registeredPeripherals[$0] }
    }
    func retrieveConnectedPeripherals(withServices serviceUUIDs: [CBUUID]) -> [CBPeripheral] { [] }

    // Test driver methods — simulate delegate callbacks
    func simulateDidUpdateState(_ newState: CBManagerState) {
        state = newState
        delegate?.centralManagerDidUpdateState(unsafeBitCast(self, to: CBCentralManager.self))
    }
    func simulateDidConnect(_ peripheral: CBPeripheral) {
        delegate?.centralManager?(unsafeBitCast(self, to: CBCentralManager.self), didConnect: peripheral)
    }
    func simulateDidFailToConnect(_ peripheral: CBPeripheral, error: NSError) {
        delegate?.centralManager?(unsafeBitCast(self, to: CBCentralManager.self), didFailToConnect: peripheral, error: error)
    }
    func simulateDidDisconnect(_ peripheral: CBPeripheral, error: NSError?) {
        delegate?.centralManager?(unsafeBitCast(self, to: CBCentralManager.self), didDisconnectPeripheral: peripheral, error: error)
    }
    func simulateDidDiscover(_ peripheral: CBPeripheral, ad: [String: Any], rssi: NSNumber) {
        delegate?.centralManager?(unsafeBitCast(self, to: CBCentralManager.self), didDiscover: peripheral, advertisementData: ad, rssi: rssi)
    }
}
