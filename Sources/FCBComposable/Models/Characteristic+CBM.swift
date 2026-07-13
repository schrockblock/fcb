@preconcurrency import CoreBluetooth
import CoreBluetoothMock
import Foundation

extension Characteristic {
    /// `peripheralID` is explicit for the same reason as `Service`'s CBM
    /// initializer: the service→peripheral back-pointer must not be traversed.
    init(_ c: CBMCharacteristic, peripheralID: UUID) {
        self.init(
            id: c.uuid,
            serviceID: c.service?.uuid ?? CBUUID(),
            peripheralID: peripheralID,
            properties: c.properties,
            value: c.value,
            isNotifying: c.isNotifying
        )
    }
}
