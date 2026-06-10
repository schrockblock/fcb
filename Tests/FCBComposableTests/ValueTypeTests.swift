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

    @Test func discoveredPeripheralBundlesAdAndRSSI() {
        let p = Peripheral(id: UUID(), name: "X", state: .disconnected)
        let ad = AdvertisementData(localName: "X")
        let d = DiscoveredPeripheral(peripheral: p, advertisementData: ad, rssi: -60)
        #expect(d.peripheral == p)
        #expect(d.rssi == -60)
    }

    @Test func readRequestExposesCentralAndCharacteristic() {
        let req = ReadRequest(
            id: UUID(),
            central: Central(id: UUID(), maximumUpdateValueLength: 256),
            characteristic: Characteristic(id: CBUUID(string: "2A19"), serviceID: CBUUID(string: "180F"),
                                           peripheralID: UUID(), properties: [.read], value: nil, isNotifying: false),
            offset: 4
        )
        #expect(req.offset == 4)
    }

    @Test func writeRequestExposesValue() {
        let req = WriteRequest(
            id: UUID(),
            central: Central(id: UUID(), maximumUpdateValueLength: 256),
            characteristic: Characteristic(id: CBUUID(string: "2A19"), serviceID: CBUUID(string: "180F"),
                                           peripheralID: UUID(), properties: [.write], value: nil, isNotifying: false),
            offset: 0,
            value: Data([0xFF])
        )
        #expect(req.value == Data([0xFF]))
    }

    @Test func mutableServiceCarriesCharacteristics() {
        let svc = MutableService(
            id: CBUUID(string: "180F"),
            isPrimary: true,
            characteristics: [MutableCharacteristic(id: CBUUID(string: "2A19"),
                                                    properties: [.read],
                                                    permissions: [.readable],
                                                    value: nil)]
        )
        #expect(svc.characteristics.count == 1)
    }

    @Test func subscriptionEventDistinguishesSubscribeAndUnsubscribe() {
        let central = Central(id: UUID(), maximumUpdateValueLength: 128)
        let char = Characteristic(id: CBUUID(string: "2A19"), serviceID: CBUUID(string: "180F"),
                                  peripheralID: UUID(), properties: [.notify], value: nil, isNotifying: true)
        let a = SubscriptionEvent.subscribed(central: central, characteristic: char)
        let b = SubscriptionEvent.unsubscribed(central: central, characteristic: char)
        #expect(a != b)
    }

    @Test func scanOptionsAllowsDuplicates() {
        let opts = ScanOptions(allowDuplicates: true, solicitedServiceUUIDs: nil)
        #expect(opts.allowDuplicates == true)
    }

    @Test func connectOptionsNotifyOnConnection() {
        let opts = ConnectOptions(notifyOnConnection: true, notifyOnDisconnection: false, notifyOnNotification: false)
        #expect(opts.notifyOnConnection == true)
    }
}
