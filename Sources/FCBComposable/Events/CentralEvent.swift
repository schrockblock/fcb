@preconcurrency import CoreBluetooth
import Foundation

extension BluetoothError: Hashable {
    public func hash(into hasher: inout Hasher) {
        switch self {
        case .unauthorized(let auth):
            hasher.combine(0); hasher.combine(auth.rawValue)
        case .poweredOff:
            hasher.combine(1)
        case .unsupported:
            hasher.combine(2)
        case .unknownPeripheral(let id):
            hasher.combine(3); hasher.combine(id)
        case .unknownService(let uuid, let pid):
            hasher.combine(4); hasher.combine(uuid); hasher.combine(pid)
        case .unknownCharacteristic(let uuid, let sid):
            hasher.combine(5); hasher.combine(uuid); hasher.combine(sid)
        case .connectionFailed(let pid, let err):
            hasher.combine(6); hasher.combine(pid); hasher.combine(err)
        case .disconnected(let pid, let err):
            hasher.combine(7); hasher.combine(pid); hasher.combine(err)
        case .att(let code):
            hasher.combine(8); hasher.combine(code.rawValue)
        case .operationCancelled:
            hasher.combine(9)
        case .l2capNotSupported:
            hasher.combine(10)
        case .underlying(let err):
            hasher.combine(11); hasher.combine(err)
        }
    }
}

public enum CentralEvent: Sendable, Hashable {
    case didUpdateState(CBManagerState)
    case willRestoreState(RestorationState)
    case didDiscover(DiscoveredPeripheral)
    case didConnect(Peripheral)
    case didFailToConnect(Peripheral, BluetoothError)
    case didDisconnect(Peripheral, BluetoothError?)
    case didDisconnectWithTimestamp(Peripheral, timestamp: Date, isReconnecting: Bool, BluetoothError?)
    /// The peripheral's write-without-response queue has room again
    /// (`peripheralIsReady(toSendWriteWithoutResponse:)`).
    case isReadyToSendWriteWithoutResponse(Peripheral)
    #if !os(macOS)
    case connectionEventDidOccur(CBConnectionEvent, Peripheral)
    case didUpdateANCSAuthorization(Peripheral)
    #endif
}
