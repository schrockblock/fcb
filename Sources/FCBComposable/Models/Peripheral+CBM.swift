import CoreBluetoothMock
import Foundation

extension Peripheral {
    init(_ p: any CBMPeripheral) {
        self.init(id: p.identifier, name: p.name, state: ConnectionState(p.state))
    }
}
