import CoreBluetooth
import Testing
@testable import FCB

struct FCBPeripheralDelegateTests {
    @Test func forwardsDidUpdateName() {
        let sut = FCBPeripheralDelegate()
        nonisolated(unsafe) var fired = false
        sut.onDidUpdateName = { _ in fired = true }
        sut.peripheralDidUpdateName(BLETestStub.peripheral())
        #expect(fired)
    }

    @Test func forwardsDidModifyServices() {
        let sut = FCBPeripheralDelegate()
        nonisolated(unsafe) var count: Int?
        sut.onDidModifyServices = { _, services in count = services.count }
        sut.peripheral(BLETestStub.peripheral(), didModifyServices: [BLETestStub.service()])
        #expect(count == 1)
    }

    @Test func forwardsDidReadRSSI() {
        let sut = FCBPeripheralDelegate()
        nonisolated(unsafe) var capturedRSSI: NSNumber?
        sut.onDidReadRSSI = { _, rssi, _ in capturedRSSI = rssi }
        sut.peripheral(BLETestStub.peripheral(), didReadRSSI: NSNumber(value: -55), error: nil)
        #expect(capturedRSSI?.intValue == -55)
    }

    @Test func forwardsDidDiscoverServices() {
        let sut = FCBPeripheralDelegate()
        nonisolated(unsafe) var fired = false
        sut.onDidDiscoverServices = { _, _ in fired = true }
        sut.peripheral(BLETestStub.peripheral(), didDiscoverServices: nil)
        #expect(fired)
    }

    @Test func forwardsDidDiscoverIncludedServices() {
        let sut = FCBPeripheralDelegate()
        nonisolated(unsafe) var fired = false
        sut.onDidDiscoverIncludedServices = { _, _, _ in fired = true }
        sut.peripheral(BLETestStub.peripheral(),
                       didDiscoverIncludedServicesFor: BLETestStub.service(),
                       error: nil)
        #expect(fired)
    }

    @Test func forwardsDidDiscoverCharacteristics() {
        let sut = FCBPeripheralDelegate()
        nonisolated(unsafe) var fired = false
        sut.onDidDiscoverCharacteristics = { _, _, _ in fired = true }
        sut.peripheral(BLETestStub.peripheral(),
                       didDiscoverCharacteristicsFor: BLETestStub.service(),
                       error: nil)
        #expect(fired)
    }

    @Test func forwardsDidDiscoverDescriptors() {
        let sut = FCBPeripheralDelegate()
        nonisolated(unsafe) var fired = false
        sut.onDidDiscoverDescriptors = { _, _, _ in fired = true }
        sut.peripheral(BLETestStub.peripheral(),
                       didDiscoverDescriptorsFor: BLETestStub.characteristic(),
                       error: nil)
        #expect(fired)
    }

    @Test func forwardsDidUpdateValueForCharacteristic() {
        let sut = FCBPeripheralDelegate()
        nonisolated(unsafe) var fired = false
        sut.onDidUpdateValueForCharacteristic = { _, _, _ in fired = true }
        sut.peripheral(BLETestStub.peripheral(),
                       didUpdateValueFor: BLETestStub.characteristic(),
                       error: nil)
        #expect(fired)
    }

    @Test func forwardsDidWriteValueForCharacteristic() {
        let sut = FCBPeripheralDelegate()
        nonisolated(unsafe) var fired = false
        sut.onDidWriteValueForCharacteristic = { _, _, _ in fired = true }
        sut.peripheral(BLETestStub.peripheral(),
                       didWriteValueFor: BLETestStub.characteristic(),
                       error: nil)
        #expect(fired)
    }

    @Test func forwardsDidUpdateNotificationState() {
        let sut = FCBPeripheralDelegate()
        nonisolated(unsafe) var fired = false
        sut.onDidUpdateNotificationState = { _, _, _ in fired = true }
        sut.peripheral(BLETestStub.peripheral(),
                       didUpdateNotificationStateFor: BLETestStub.characteristic(),
                       error: nil)
        #expect(fired)
    }

    @Test func forwardsIsReadyToSendWriteWithoutResponse() {
        let sut = FCBPeripheralDelegate()
        nonisolated(unsafe) var fired = false
        sut.onIsReadyToSendWriteWithoutResponse = { _ in fired = true }
        sut.peripheralIsReady(toSendWriteWithoutResponse: BLETestStub.peripheral())
        #expect(fired)
    }
}
