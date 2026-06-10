@preconcurrency import CoreBluetooth
import Foundation

extension MutableService {
    func toCB() -> CBMutableService {
        let svc = CBMutableService(type: id, primary: isPrimary)
        svc.characteristics = characteristics.map { c in
            CBMutableCharacteristic(type: c.id, properties: c.properties, value: c.value, permissions: c.permissions)
        }
        return svc
    }
}
