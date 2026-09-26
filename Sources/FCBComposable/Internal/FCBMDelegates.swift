import CoreBluetoothMock
import Foundation

/// Closure-based wrapper around `CBMCentralManagerDelegate`, mirroring Layer 1's
/// `FCBCentralManagerDelegate` pattern but typed on CoreBluetoothMock. Internal:
/// FCBComposable's public surface stays CoreBluetooth-typed. Only the callbacks
/// `CentralActor` consumes are exposed; CBM provides defaults for the rest.
final class FCBMCentralManagerDelegate: NSObject, CBMCentralManagerDelegate {
    var onDidUpdateState: (@Sendable (CBMCentralManager) -> Void)?
    var onDidDiscover: (@Sendable (CBMCentralManager, CBMPeripheral, [String: Any], NSNumber) -> Void)?
    var onDidConnect: (@Sendable (CBMCentralManager, CBMPeripheral) -> Void)?
    var onDidFailToConnect: (@Sendable (CBMCentralManager, CBMPeripheral, Error?) -> Void)?
    var onDidDisconnect: (@Sendable (CBMCentralManager, CBMPeripheral, Error?) -> Void)?

    func centralManagerDidUpdateState(_ central: CBMCentralManager) {
        onDidUpdateState?(central)
    }
    func centralManager(_ central: CBMCentralManager, didDiscover peripheral: CBMPeripheral, advertisementData: [String: Any], rssi RSSI: NSNumber) {
        onDidDiscover?(central, peripheral, advertisementData, RSSI)
    }
    func centralManager(_ central: CBMCentralManager, didConnect peripheral: CBMPeripheral) {
        onDidConnect?(central, peripheral)
    }
    func centralManager(_ central: CBMCentralManager, didFailToConnect peripheral: CBMPeripheral, error: Error?) {
        onDidFailToConnect?(central, peripheral, error)
    }
    func centralManager(_ central: CBMCentralManager, didDisconnectPeripheral peripheral: CBMPeripheral, error: Error?) {
        onDidDisconnect?(central, peripheral, error)
    }
}

final class FCBMPeripheralDelegate: NSObject, CBMPeripheralDelegate {
    var onDidDiscoverServices: (@Sendable (CBMPeripheral, Error?) -> Void)?
    var onDidDiscoverCharacteristics: (@Sendable (CBMPeripheral, CBMService, Error?) -> Void)?
    var onDidUpdateValueForCharacteristic: (@Sendable (CBMPeripheral, CBMCharacteristic, Error?) -> Void)?
    var onDidWriteValueForCharacteristic: (@Sendable (CBMPeripheral, CBMCharacteristic, Error?) -> Void)?
    var onDidUpdateNotificationState: (@Sendable (CBMPeripheral, CBMCharacteristic, Error?) -> Void)?
    var onDidOpenL2CAPChannel: (@Sendable (CBMPeripheral, CBML2CAPChannel?, Error?) -> Void)?
    var onIsReadyToSendWriteWithoutResponse: (@Sendable (CBMPeripheral) -> Void)?

    func peripheral(_ peripheral: CBMPeripheral, didDiscoverServices error: Error?) {
        onDidDiscoverServices?(peripheral, error)
    }
    func peripheral(_ peripheral: CBMPeripheral, didDiscoverCharacteristicsFor service: CBMService, error: Error?) {
        onDidDiscoverCharacteristics?(peripheral, service, error)
    }
    func peripheral(_ peripheral: CBMPeripheral, didUpdateValueFor characteristic: CBMCharacteristic, error: Error?) {
        onDidUpdateValueForCharacteristic?(peripheral, characteristic, error)
    }
    func peripheral(_ peripheral: CBMPeripheral, didWriteValueFor characteristic: CBMCharacteristic, error: Error?) {
        onDidWriteValueForCharacteristic?(peripheral, characteristic, error)
    }
    func peripheral(_ peripheral: CBMPeripheral, didUpdateNotificationStateFor characteristic: CBMCharacteristic, error: Error?) {
        onDidUpdateNotificationState?(peripheral, characteristic, error)
    }

    func peripheral(_ peripheral: CBMPeripheral, didOpen channel: CBML2CAPChannel?, error: Error?) {
        onDidOpenL2CAPChannel?(peripheral, channel, error)
    }

    func peripheralIsReady(toSendWriteWithoutResponse peripheral: CBMPeripheral) {
        onIsReadyToSendWriteWithoutResponse?(peripheral)
    }
}
