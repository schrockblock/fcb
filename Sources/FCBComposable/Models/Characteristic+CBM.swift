@preconcurrency import CoreBluetooth
import CoreBluetoothMock
import Foundation

extension Characteristic {
    init(_ c: CBMCharacteristic) {
        self.init(
            id: c.uuid,
            serviceID: c.service?.uuid ?? CBUUID(),
            peripheralID: UUID(),
            properties: c.properties,
            value: c.value,
            isNotifying: c.isNotifying
        )
    }
}
