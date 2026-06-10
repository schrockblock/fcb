import CoreBluetooth
import Foundation
import Testing
@testable import FCBComposable

struct ValueTypeTests {
    @Test func peripheralIdentityAndEquality() {
        let id = UUID()
        let a = Peripheral(id: id, name: "X", state: .connected)
        let b = Peripheral(id: id, name: "X", state: .connected)
        #expect(a == b)
        #expect(a.id == id)
    }

    @Test func connectionStateIsExhaustive() {
        let allCases: [ConnectionState] = [.disconnected, .connecting, .connected, .disconnecting]
        #expect(Set(allCases).count == 4)
    }

    @Test func serviceUsesCBUUIDAsID() {
        let uuid = CBUUID(string: "180F")
        let pid = UUID()
        let svc = Service(id: uuid, peripheralID: pid, isPrimary: true)
        #expect(svc.id == uuid)
        #expect(svc.peripheralID == pid)
        #expect(svc.isPrimary == true)
    }

    @Test func characteristicCarriesProperties() {
        let charUUID = CBUUID(string: "2A19")
        let svcUUID = CBUUID(string: "180F")
        let pid = UUID()
        let char = Characteristic(id: charUUID, serviceID: svcUUID, peripheralID: pid,
                                  properties: [.read, .notify], value: Data([0x01]), isNotifying: true)
        #expect(char.properties.contains(.read))
        #expect(char.properties.contains(.notify))
        #expect(char.value == Data([0x01]))
        #expect(char.isNotifying)
    }

    @Test func centralCarriesMaxUpdateLength() {
        let id = UUID()
        let central = Central(id: id, maximumUpdateValueLength: 512)
        #expect(central.id == id)
        #expect(central.maximumUpdateValueLength == 512)
    }
}
