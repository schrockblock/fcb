import CoreBluetooth
import Foundation

open class FCBCentralManagerDelegate: NSObject, CBCentralManagerDelegate {
    public var onDidUpdateState: (@Sendable (CBCentralManager) -> Void)?
    public var onWillRestoreState: (@Sendable (CBCentralManager, [String: Any]) -> Void)?
    public var onDidDiscover: (@Sendable (CBCentralManager, CBPeripheral, [String: Any], NSNumber) -> Void)?
    public var onDidConnect: (@Sendable (CBCentralManager, CBPeripheral) -> Void)?
    public var onDidFailToConnect: (@Sendable (CBCentralManager, CBPeripheral, (any Error)?) -> Void)?
    public var onDidDisconnect: (@Sendable (CBCentralManager, CBPeripheral, (any Error)?) -> Void)?
    public var onDidDisconnectWithTimestamp: (@Sendable (CBCentralManager, CBPeripheral, CFAbsoluteTime, Bool, (any Error)?) -> Void)?
    #if !os(macOS)
    public var onConnectionEventDidOccur: (@Sendable (CBCentralManager, CBConnectionEvent, CBPeripheral) -> Void)?
    public var onDidUpdateANCSAuthorization: (@Sendable (CBCentralManager, CBPeripheral) -> Void)?
    #endif

    public override init() { super.init() }

    open func centralManagerDidUpdateState(_ central: CBCentralManager) {
        onDidUpdateState?(central)
    }
    open func centralManager(_ central: CBCentralManager, willRestoreState dict: [String: Any]) {
        onWillRestoreState?(central, dict)
    }
    open func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String: Any], rssi RSSI: NSNumber) {
        onDidDiscover?(central, peripheral, advertisementData, RSSI)
    }
    open func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        onDidConnect?(central, peripheral)
    }
    open func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: (any Error)?) {
        onDidFailToConnect?(central, peripheral, error)
    }
    open func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: (any Error)?) {
        onDidDisconnect?(central, peripheral, error)
    }
    open func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, timestamp: CFAbsoluteTime, isReconnecting: Bool, error: (any Error)?) {
        onDidDisconnectWithTimestamp?(central, peripheral, timestamp, isReconnecting, error)
    }
    #if !os(macOS)
    open func centralManager(_ central: CBCentralManager, connectionEventDidOccur event: CBConnectionEvent, for peripheral: CBPeripheral) {
        onConnectionEventDidOccur?(central, event, peripheral)
    }
    open func centralManager(_ central: CBCentralManager, didUpdateANCSAuthorizationFor peripheral: CBPeripheral) {
        onDidUpdateANCSAuthorization?(central, peripheral)
    }
    #endif
}
