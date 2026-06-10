import CoreBluetooth
import Foundation
import Testing
@testable import FCBComposable

struct AdvertisementDataTests {
    @Test func decodesLocalName() {
        let dict: [String: Any] = [CBAdvertisementDataLocalNameKey: "MyDevice"]
        let ad = AdvertisementData(dictionary: dict)
        #expect(ad.localName == "MyDevice")
    }

    @Test func decodesServiceUUIDs() {
        let uuid = CBUUID(string: "180F")
        let dict: [String: Any] = [CBAdvertisementDataServiceUUIDsKey: [uuid]]
        let ad = AdvertisementData(dictionary: dict)
        #expect(ad.serviceUUIDs == [uuid])
    }

    @Test func decodesManufacturerData() {
        let data = Data([0xDE, 0xAD, 0xBE, 0xEF])
        let dict: [String: Any] = [CBAdvertisementDataManufacturerDataKey: data]
        let ad = AdvertisementData(dictionary: dict)
        #expect(ad.manufacturerData == data)
    }

    @Test func decodesTxPowerLevel() {
        let dict: [String: Any] = [CBAdvertisementDataTxPowerLevelKey: NSNumber(value: -12)]
        let ad = AdvertisementData(dictionary: dict)
        #expect(ad.txPowerLevel == -12)
    }

    @Test func decodesIsConnectable() {
        let dict: [String: Any] = [CBAdvertisementDataIsConnectable: NSNumber(value: true)]
        let ad = AdvertisementData(dictionary: dict)
        #expect(ad.isConnectable == true)
    }

    @Test func decodesServiceData() {
        let uuid = CBUUID(string: "180F")
        let payload = Data([0xAB])
        let dict: [String: Any] = [CBAdvertisementDataServiceDataKey: [uuid: payload]]
        let ad = AdvertisementData(dictionary: dict)
        #expect(ad.serviceData[uuid] == payload)
    }

    @Test func emptyDictionaryProducesEmptyAdvertisementData() {
        let ad = AdvertisementData(dictionary: [:])
        #expect(ad.localName == nil)
        #expect(ad.serviceUUIDs.isEmpty)
        #expect(ad.manufacturerData == nil)
        #expect(ad.txPowerLevel == nil)
        #expect(ad.isConnectable == nil)
        #expect(ad.solicitedServiceUUIDs.isEmpty)
        #expect(ad.overflowServiceUUIDs.isEmpty)
        #expect(ad.serviceData.isEmpty)
    }
}
