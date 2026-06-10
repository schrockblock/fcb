import CoreBluetooth
import Foundation

open class FCBPeripheralManagerDelegate: NSObject, CBPeripheralManagerDelegate {
    public var onDidUpdateState: (@Sendable (CBPeripheralManager) -> Void)?
    public var onWillRestoreState: (@Sendable (CBPeripheralManager, [String: Any]) -> Void)?
    public var onDidStartAdvertising: (@Sendable (CBPeripheralManager, (any Error)?) -> Void)?
    public var onDidAddService: (@Sendable (CBPeripheralManager, CBService, (any Error)?) -> Void)?
    public var onDidSubscribeToCharacteristic: (@Sendable (CBPeripheralManager, CBCentral, CBCharacteristic) -> Void)?
    public var onDidUnsubscribeFromCharacteristic: (@Sendable (CBPeripheralManager, CBCentral, CBCharacteristic) -> Void)?
    public var onDidReceiveRead: (@Sendable (CBPeripheralManager, CBATTRequest) -> Void)?
    public var onDidReceiveWrite: (@Sendable (CBPeripheralManager, [CBATTRequest]) -> Void)?
    public var onIsReadyToUpdateSubscribers: (@Sendable (CBPeripheralManager) -> Void)?
    public var onDidPublishL2CAPChannel: (@Sendable (CBPeripheralManager, CBL2CAPPSM, (any Error)?) -> Void)?
    public var onDidUnpublishL2CAPChannel: (@Sendable (CBPeripheralManager, CBL2CAPPSM, (any Error)?) -> Void)?
    public var onDidOpenL2CAPChannel: (@Sendable (CBPeripheralManager, CBL2CAPChannel?, (any Error)?) -> Void)?

    public override init() { super.init() }

    open func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        onDidUpdateState?(peripheral)
    }
    open func peripheralManager(_ peripheral: CBPeripheralManager, willRestoreState dict: [String: Any]) {
        onWillRestoreState?(peripheral, dict)
    }
    open func peripheralManagerDidStartAdvertising(_ peripheral: CBPeripheralManager, error: (any Error)?) {
        onDidStartAdvertising?(peripheral, error)
    }
    open func peripheralManager(_ peripheral: CBPeripheralManager, didAdd service: CBService, error: (any Error)?) {
        onDidAddService?(peripheral, service, error)
    }
    open func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral, didSubscribeTo characteristic: CBCharacteristic) {
        onDidSubscribeToCharacteristic?(peripheral, central, characteristic)
    }
    open func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral, didUnsubscribeFrom characteristic: CBCharacteristic) {
        onDidUnsubscribeFromCharacteristic?(peripheral, central, characteristic)
    }
    open func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveRead request: CBATTRequest) {
        onDidReceiveRead?(peripheral, request)
    }
    open func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveWrite requests: [CBATTRequest]) {
        onDidReceiveWrite?(peripheral, requests)
    }
    open func peripheralManagerIsReady(toUpdateSubscribers peripheral: CBPeripheralManager) {
        onIsReadyToUpdateSubscribers?(peripheral)
    }
    open func peripheralManager(_ peripheral: CBPeripheralManager, didPublishL2CAPChannel PSM: CBL2CAPPSM, error: (any Error)?) {
        onDidPublishL2CAPChannel?(peripheral, PSM, error)
    }
    open func peripheralManager(_ peripheral: CBPeripheralManager, didUnpublishL2CAPChannel PSM: CBL2CAPPSM, error: (any Error)?) {
        onDidUnpublishL2CAPChannel?(peripheral, PSM, error)
    }
    open func peripheralManager(_ peripheral: CBPeripheralManager, didOpen channel: CBL2CAPChannel?, error: (any Error)?) {
        onDidOpenL2CAPChannel?(peripheral, channel, error)
    }
}
