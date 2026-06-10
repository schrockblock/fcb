@preconcurrency import CoreBluetooth
import Foundation
@testable import FCBComposable

final class FakePeripheralManager: NSObject, PeripheralManaging, @unchecked Sendable {
    var state: CBManagerState = .poweredOn
    var isAdvertising: Bool = false
    weak var delegate: CBPeripheralManagerDelegate?

    private(set) var addedServices: [CBMutableService] = []
    private(set) var removedServices: [CBMutableService] = []
    private(set) var removeAllCount = 0
    private(set) var startAdvertisingCalls: [[String: Any]?] = []
    private(set) var stopAdvertisingCount = 0
    private(set) var respondCalls: [(request: CBATTRequest, code: CBATTError.Code)] = []
    private(set) var updateValueCalls: [(data: Data, characteristic: CBMutableCharacteristic, centrals: [CBCentral]?)] = []

    func add(_ service: CBMutableService) { addedServices.append(service) }
    func remove(_ service: CBMutableService) { removedServices.append(service) }
    func removeAllServices() { removeAllCount += 1 }
    func startAdvertising(_ advertisementData: [String: Any]?) {
        startAdvertisingCalls.append(advertisementData)
        isAdvertising = true
    }
    func stopAdvertising() {
        stopAdvertisingCount += 1
        isAdvertising = false
    }
    func respond(to request: CBATTRequest, withResult result: CBATTError.Code) {
        respondCalls.append((request, result))
    }
    func updateValue(_ value: Data, for characteristic: CBMutableCharacteristic, onSubscribedCentrals centrals: [CBCentral]?) -> Bool {
        updateValueCalls.append((value, characteristic, centrals))
        return true
    }

    func simulateDidUpdateState(_ newState: CBManagerState) {
        state = newState
        delegate?.peripheralManagerDidUpdateState(unsafeBitCast(self, to: CBPeripheralManager.self))
    }
    func simulateDidStartAdvertising(error: NSError? = nil) {
        delegate?.peripheralManagerDidStartAdvertising?(unsafeBitCast(self, to: CBPeripheralManager.self), error: error)
    }
    func simulateDidAddService(_ service: CBService, error: NSError? = nil) {
        delegate?.peripheralManager?(unsafeBitCast(self, to: CBPeripheralManager.self), didAdd: service, error: error)
    }
    func simulateDidReceiveRead(_ request: CBATTRequest) {
        delegate?.peripheralManager?(unsafeBitCast(self, to: CBPeripheralManager.self), didReceiveRead: request)
    }
    func simulateDidReceiveWrite(_ requests: [CBATTRequest]) {
        delegate?.peripheralManager?(unsafeBitCast(self, to: CBPeripheralManager.self), didReceiveWrite: requests)
    }
    func simulateDidSubscribe(central: CBCentral, characteristic: CBCharacteristic) {
        delegate?.peripheralManager?(unsafeBitCast(self, to: CBPeripheralManager.self), central: central, didSubscribeTo: characteristic)
    }
}
