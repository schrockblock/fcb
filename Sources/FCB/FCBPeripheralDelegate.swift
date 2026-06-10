import CoreBluetooth
import Foundation

open class FCBPeripheralDelegate: NSObject, CBPeripheralDelegate {
    public var onDidUpdateName: (@Sendable (CBPeripheral) -> Void)?
    public var onDidModifyServices: (@Sendable (CBPeripheral, [CBService]) -> Void)?
    public var onDidReadRSSI: (@Sendable (CBPeripheral, NSNumber, (any Error)?) -> Void)?
    public var onDidDiscoverServices: (@Sendable (CBPeripheral, (any Error)?) -> Void)?
    public var onDidDiscoverIncludedServices: (@Sendable (CBPeripheral, CBService, (any Error)?) -> Void)?
    public var onDidDiscoverCharacteristics: (@Sendable (CBPeripheral, CBService, (any Error)?) -> Void)?
    public var onDidDiscoverDescriptors: (@Sendable (CBPeripheral, CBCharacteristic, (any Error)?) -> Void)?
    public var onDidUpdateValueForCharacteristic: (@Sendable (CBPeripheral, CBCharacteristic, (any Error)?) -> Void)?
    public var onDidUpdateValueForDescriptor: (@Sendable (CBPeripheral, CBDescriptor, (any Error)?) -> Void)?
    public var onDidWriteValueForCharacteristic: (@Sendable (CBPeripheral, CBCharacteristic, (any Error)?) -> Void)?
    public var onDidWriteValueForDescriptor: (@Sendable (CBPeripheral, CBDescriptor, (any Error)?) -> Void)?
    public var onDidUpdateNotificationState: (@Sendable (CBPeripheral, CBCharacteristic, (any Error)?) -> Void)?
    public var onIsReadyToSendWriteWithoutResponse: (@Sendable (CBPeripheral) -> Void)?
    public var onDidOpenL2CAPChannel: (@Sendable (CBPeripheral, CBL2CAPChannel?, (any Error)?) -> Void)?

    public override init() { super.init() }

    open func peripheralDidUpdateName(_ peripheral: CBPeripheral) {
        onDidUpdateName?(peripheral)
    }
    open func peripheral(_ peripheral: CBPeripheral, didModifyServices invalidatedServices: [CBService]) {
        onDidModifyServices?(peripheral, invalidatedServices)
    }
    open func peripheral(_ peripheral: CBPeripheral, didReadRSSI RSSI: NSNumber, error: (any Error)?) {
        onDidReadRSSI?(peripheral, RSSI, error)
    }
    open func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: (any Error)?) {
        onDidDiscoverServices?(peripheral, error)
    }
    open func peripheral(_ peripheral: CBPeripheral, didDiscoverIncludedServicesFor service: CBService, error: (any Error)?) {
        onDidDiscoverIncludedServices?(peripheral, service, error)
    }
    open func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: (any Error)?) {
        onDidDiscoverCharacteristics?(peripheral, service, error)
    }
    open func peripheral(_ peripheral: CBPeripheral, didDiscoverDescriptorsFor characteristic: CBCharacteristic, error: (any Error)?) {
        onDidDiscoverDescriptors?(peripheral, characteristic, error)
    }
    open func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: (any Error)?) {
        onDidUpdateValueForCharacteristic?(peripheral, characteristic, error)
    }
    open func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor descriptor: CBDescriptor, error: (any Error)?) {
        onDidUpdateValueForDescriptor?(peripheral, descriptor, error)
    }
    open func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: (any Error)?) {
        onDidWriteValueForCharacteristic?(peripheral, characteristic, error)
    }
    open func peripheral(_ peripheral: CBPeripheral, didWriteValueFor descriptor: CBDescriptor, error: (any Error)?) {
        onDidWriteValueForDescriptor?(peripheral, descriptor, error)
    }
    open func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: (any Error)?) {
        onDidUpdateNotificationState?(peripheral, characteristic, error)
    }
    open func peripheralIsReady(toSendWriteWithoutResponse peripheral: CBPeripheral) {
        onIsReadyToSendWriteWithoutResponse?(peripheral)
    }
    open func peripheral(_ peripheral: CBPeripheral, didOpen channel: CBL2CAPChannel?, error: (any Error)?) {
        onDidOpenL2CAPChannel?(peripheral, channel, error)
    }
}
