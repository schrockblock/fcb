@preconcurrency import CoreBluetooth
import Foundation

public enum PeripheralEvent: Sendable, Hashable {
    case didUpdateName(Peripheral)
    case didModifyServices(Peripheral, invalidatedServices: [Service])
    case didReadRSSI(Peripheral, rssi: Int, error: BluetoothError?)
    case didDiscoverServices(Peripheral, error: BluetoothError?)
    case didDiscoverIncludedServices(Peripheral, service: Service, error: BluetoothError?)
    case didDiscoverCharacteristics(Peripheral, service: Service, error: BluetoothError?)
    case didDiscoverDescriptors(Peripheral, characteristic: Characteristic, error: BluetoothError?)
    case didUpdateValue(Peripheral, characteristic: Characteristic, error: BluetoothError?)
    case didWriteValue(Peripheral, characteristic: Characteristic, error: BluetoothError?)
    case didUpdateNotificationState(Peripheral, characteristic: Characteristic, error: BluetoothError?)
    case isReadyToSendWriteWithoutResponse(Peripheral)
}
