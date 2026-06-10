import CoreBluetooth
import ObjectiveC.runtime

/// Test-only helpers for minting `CB*` instances that cannot be initialized publicly.
/// These objects MUST NOT have their methods invoked — they exist only to satisfy
/// type signatures on delegate forwards.
enum BLETestStub {
    static func peripheral() -> CBPeripheral {
        let obj = unsafeBitCast(class_createInstance(CBPeripheral.self, 0)!, to: CBPeripheral.self)
        _ = Unmanaged.passRetained(obj)
        return obj
    }
    static func service() -> CBService {
        let obj = unsafeBitCast(class_createInstance(CBService.self, 0)!, to: CBService.self)
        _ = Unmanaged.passRetained(obj)
        return obj
    }
    static func characteristic() -> CBCharacteristic {
        let obj = unsafeBitCast(class_createInstance(CBCharacteristic.self, 0)!, to: CBCharacteristic.self)
        _ = Unmanaged.passRetained(obj)
        return obj
    }
    static func central() -> CBCentral {
        let obj = unsafeBitCast(class_createInstance(CBCentral.self, 0)!, to: CBCentral.self)
        _ = Unmanaged.passRetained(obj)
        return obj
    }
    static func attRequest() -> CBATTRequest {
        let obj = unsafeBitCast(class_createInstance(CBATTRequest.self, 0)!, to: CBATTRequest.self)
        _ = Unmanaged.passRetained(obj)
        return obj
    }
    static func centralManager() -> CBCentralManager {
        CBCentralManager(delegate: nil, queue: nil)
    }
    static func peripheralManager() -> CBPeripheralManager {
        CBPeripheralManager(delegate: nil, queue: nil)
    }
}
