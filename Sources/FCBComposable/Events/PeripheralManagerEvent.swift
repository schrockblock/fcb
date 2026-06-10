@preconcurrency import CoreBluetooth
import Foundation

public enum PeripheralManagerEvent: Sendable, Hashable {
    case didUpdateState(CBManagerState)
    case willRestoreState(RestorationState)
    case didStartAdvertising(error: BluetoothError?)
    case didAddService(Service, error: BluetoothError?)
    case didSubscribeToCharacteristic(Central, characteristic: Characteristic)
    case didUnsubscribeFromCharacteristic(Central, characteristic: Characteristic)
    case didReceiveRead(ReadRequest)
    case didReceiveWrite([WriteRequest])
    case isReadyToUpdateSubscribers
}
