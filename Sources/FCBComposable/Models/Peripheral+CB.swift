@preconcurrency import CoreBluetooth
import Foundation

extension Peripheral {
    init(_ cb: CBPeripheral) {
        self.init(id: cb.identifier, name: cb.name, state: ConnectionState(cb.state))
    }
}

extension ConnectionState {
    init(_ cb: CBPeripheralState) {
        switch cb {
        case .disconnected: self = .disconnected
        case .connecting: self = .connecting
        case .connected: self = .connected
        case .disconnecting: self = .disconnecting
        @unknown default: self = .disconnected
        }
    }
}
