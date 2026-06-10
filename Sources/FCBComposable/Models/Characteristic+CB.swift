@preconcurrency import CoreBluetooth
import Foundation

extension Characteristic {
    init(_ cb: CBCharacteristic) {
        self.init(
            id: cb.uuid,
            serviceID: cb.service?.uuid ?? CBUUID(),
            peripheralID: cb.service?.peripheral?.identifier ?? UUID(),
            properties: cb.properties,
            value: cb.value,
            isNotifying: cb.isNotifying
        )
    }
}
