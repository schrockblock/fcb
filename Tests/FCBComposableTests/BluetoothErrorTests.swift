import CoreBluetooth
import Foundation
import Testing
@testable import FCBComposable

struct BluetoothErrorTests {
    @Test func mapsCBErrorOperationCancelled() {
        let nsError = NSError(domain: CBErrorDomain, code: CBError.operationCancelled.rawValue)
        let mapped = BluetoothError(nsError)
        #expect(mapped == .operationCancelled)
    }

    @Test func mapsCBATTErrorToATTCase() {
        let nsError = NSError(domain: CBATTErrorDomain, code: CBATTError.readNotPermitted.rawValue)
        let mapped = BluetoothError(nsError)
        #expect(mapped == .att(.readNotPermitted))
    }

    @Test func mapsUnknownDomainToUnderlying() {
        let nsError = NSError(domain: "com.example.weird", code: 42)
        let mapped = BluetoothError(nsError)
        if case .underlying(let underlying) = mapped {
            #expect(underlying.domain == "com.example.weird")
            #expect(underlying.code == 42)
        } else {
            Issue.record("expected .underlying, got \(mapped)")
        }
    }

    @Test func equatability() {
        #expect(BluetoothError.poweredOff == BluetoothError.poweredOff)
        #expect(BluetoothError.unknownPeripheral(UUID()) != BluetoothError.unknownPeripheral(UUID()))
    }
}
