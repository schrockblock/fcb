@preconcurrency import CoreBluetooth
import Foundation

protocol PeripheralManaging: AnyObject {
    var state: CBManagerState { get }
    var isAdvertising: Bool { get }
    var delegate: CBPeripheralManagerDelegate? { get set }

    func add(_ service: CBMutableService)
    func remove(_ service: CBMutableService)
    func removeAllServices()
    func startAdvertising(_ advertisementData: [String: Any]?)
    func stopAdvertising()
    func respond(to request: CBATTRequest, withResult result: CBATTError.Code)
    func updateValue(_ value: Data, for characteristic: CBMutableCharacteristic, onSubscribedCentrals centrals: [CBCentral]?) -> Bool
    func publishL2CAPChannel(withEncryption encryptionRequired: Bool)
    func unpublishL2CAPChannel(_ PSM: CBL2CAPPSM)
}

extension CBPeripheralManager: PeripheralManaging {}
