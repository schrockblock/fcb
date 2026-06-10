import CoreBluetooth
import Testing
@testable import FCB

struct FCBPeripheralManagerDelegateTests {
    @Test func forwardsDidUpdateState() {
        let sut = FCBPeripheralManagerDelegate()
        nonisolated(unsafe) var fired = false
        sut.onDidUpdateState = { _ in fired = true }
        sut.peripheralManagerDidUpdateState(BLETestStub.peripheralManager())
        #expect(fired)
    }

    @Test func forwardsWillRestoreState() {
        let sut = FCBPeripheralManagerDelegate()
        nonisolated(unsafe) var capturedKeys: [String]?
        sut.onWillRestoreState = { _, dict in capturedKeys = Array(dict.keys) }
        sut.peripheralManager(BLETestStub.peripheralManager(), willRestoreState: ["k": 1])
        #expect(capturedKeys == ["k"])
    }

    @Test func forwardsDidStartAdvertising() {
        let sut = FCBPeripheralManagerDelegate()
        nonisolated(unsafe) var fired = false
        sut.onDidStartAdvertising = { _, _ in fired = true }
        sut.peripheralManagerDidStartAdvertising(BLETestStub.peripheralManager(), error: nil)
        #expect(fired)
    }

    @Test func forwardsDidAddService() {
        let sut = FCBPeripheralManagerDelegate()
        nonisolated(unsafe) var fired = false
        sut.onDidAddService = { _, _, _ in fired = true }
        sut.peripheralManager(BLETestStub.peripheralManager(),
                              didAdd: BLETestStub.service(),
                              error: nil)
        #expect(fired)
    }

    @Test func forwardsDidSubscribeToCharacteristic() {
        let sut = FCBPeripheralManagerDelegate()
        nonisolated(unsafe) var fired = false
        sut.onDidSubscribeToCharacteristic = { _, _, _ in fired = true }
        sut.peripheralManager(BLETestStub.peripheralManager(),
                              central: BLETestStub.central(),
                              didSubscribeTo: BLETestStub.characteristic())
        #expect(fired)
    }

    @Test func forwardsDidUnsubscribeFromCharacteristic() {
        let sut = FCBPeripheralManagerDelegate()
        nonisolated(unsafe) var fired = false
        sut.onDidUnsubscribeFromCharacteristic = { _, _, _ in fired = true }
        sut.peripheralManager(BLETestStub.peripheralManager(),
                              central: BLETestStub.central(),
                              didUnsubscribeFrom: BLETestStub.characteristic())
        #expect(fired)
    }

    @Test func forwardsDidReceiveRead() {
        let sut = FCBPeripheralManagerDelegate()
        nonisolated(unsafe) var fired = false
        sut.onDidReceiveRead = { _, _ in fired = true }
        sut.peripheralManager(BLETestStub.peripheralManager(),
                              didReceiveRead: BLETestStub.attRequest())
        #expect(fired)
    }

    @Test func forwardsDidReceiveWrite() {
        let sut = FCBPeripheralManagerDelegate()
        nonisolated(unsafe) var count: Int?
        sut.onDidReceiveWrite = { _, requests in count = requests.count }
        sut.peripheralManager(BLETestStub.peripheralManager(),
                              didReceiveWrite: [BLETestStub.attRequest(), BLETestStub.attRequest()])
        #expect(count == 2)
    }

    @Test func forwardsIsReadyToUpdateSubscribers() {
        let sut = FCBPeripheralManagerDelegate()
        nonisolated(unsafe) var fired = false
        sut.onIsReadyToUpdateSubscribers = { _ in fired = true }
        sut.peripheralManagerIsReady(toUpdateSubscribers: BLETestStub.peripheralManager())
        #expect(fired)
    }

    @Test func forwardsDidPublishL2CAPChannel() {
        let sut = FCBPeripheralManagerDelegate()
        nonisolated(unsafe) var fired = false
        sut.onDidPublishL2CAPChannel = { _, _, _ in fired = true }
        sut.peripheralManager(BLETestStub.peripheralManager(),
                              didPublishL2CAPChannel: 1,
                              error: nil)
        #expect(fired)
    }

    @Test func forwardsDidUnpublishL2CAPChannel() {
        let sut = FCBPeripheralManagerDelegate()
        nonisolated(unsafe) var fired = false
        sut.onDidUnpublishL2CAPChannel = { _, _, _ in fired = true }
        sut.peripheralManager(BLETestStub.peripheralManager(),
                              didUnpublishL2CAPChannel: 1,
                              error: nil)
        #expect(fired)
    }

    @Test func forwardsDidOpenL2CAPChannel() {
        let sut = FCBPeripheralManagerDelegate()
        nonisolated(unsafe) var fired = false
        sut.onDidOpenL2CAPChannel = { _, _, _ in fired = true }
        sut.peripheralManager(BLETestStub.peripheralManager(),
                              didOpen: nil,
                              error: nil)
        #expect(fired)
    }
}
