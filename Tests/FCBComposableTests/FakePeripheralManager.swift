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

    // MARK: - L2CAP simulation

    private(set) var publishL2CAPCalls: [Bool] = []
    private(set) var unpublishL2CAPCalls: [CBL2CAPPSM] = []
    var nextPublishPSM: CBL2CAPPSM = 0x0081
    var nextPublishError: NSError?

    func publishL2CAPChannel(withEncryption encryptionRequired: Bool) {
        publishL2CAPCalls.append(encryptionRequired)
        delegate?.peripheralManager?(
            unsafeBitCast(self, to: CBPeripheralManager.self),
            didPublishL2CAPChannel: nextPublishPSM, error: nextPublishError)
    }

    func unpublishL2CAPChannel(_ PSM: CBL2CAPPSM) {
        unpublishL2CAPCalls.append(PSM)
        delegate?.peripheralManager?(
            unsafeBitCast(self, to: CBPeripheralManager.self),
            didUnpublishL2CAPChannel: PSM, error: nil)
    }
}
