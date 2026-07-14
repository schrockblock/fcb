import CoreBluetoothMock
import Foundation

extension Peripheral {
    init(_ p: any CBMPeripheral) {
        self.init(id: p.identifier, name: p.name, state: ConnectionState(p.state))
    }
}

extension ConnectionState {
    init(_ cb: CBMPeripheralState) {
        switch cb {
        case .disconnected: self = .disconnected
        case .connecting: self = .connecting
        case .connected: self = .connected
        case .disconnecting: self = .disconnecting
        @unknown default: self = .disconnected
        }
    }
}
