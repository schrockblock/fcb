import CoreBluetooth
import Testing
@testable import FCB

struct FCBCentralManagerDelegateTests {
    @Test func forwardsDidUpdateState() {
        let sut = FCBCentralManagerDelegate()
        nonisolated(unsafe) var fired = false
        sut.onDidUpdateState = { _ in fired = true }
        sut.centralManagerDidUpdateState(BLETestStub.centralManager())
        #expect(fired)
    }

    @Test func forwardsWillRestoreState() {
        let sut = FCBCentralManagerDelegate()
        nonisolated(unsafe) var capturedKeys: [String]?
        sut.onWillRestoreState = { _, dict in capturedKeys = Array(dict.keys) }
        sut.centralManager(BLETestStub.centralManager(), willRestoreState: ["k": 1])
        #expect(capturedKeys == ["k"])
    }

    @Test func forwardsDidDiscover() {
        let sut = FCBCentralManagerDelegate()
        nonisolated(unsafe) var capturedRSSI: NSNumber?
        sut.onDidDiscover = { _, _, _, rssi in capturedRSSI = rssi }
        sut.centralManager(BLETestStub.centralManager(),
                           didDiscover: BLETestStub.peripheral(),
                           advertisementData: [:],
                           rssi: NSNumber(value: -42))
        #expect(capturedRSSI?.intValue == -42)
    }

    @Test func forwardsDidConnect() {
        let sut = FCBCentralManagerDelegate()
        nonisolated(unsafe) var fired = false
        sut.onDidConnect = { _, _ in fired = true }
        sut.centralManager(BLETestStub.centralManager(), didConnect: BLETestStub.peripheral())
        #expect(fired)
    }

    @Test func forwardsDidFailToConnect() {
        let sut = FCBCentralManagerDelegate()
        nonisolated(unsafe) var capturedError: (any Error)?
        sut.onDidFailToConnect = { _, _, err in capturedError = err }
        let nsError = NSError(domain: "x", code: 1)
        sut.centralManager(BLETestStub.centralManager(),
                           didFailToConnect: BLETestStub.peripheral(),
                           error: nsError)
        #expect((capturedError as? NSError)?.code == 1)
    }

    @Test func forwardsDidDisconnect() {
        let sut = FCBCentralManagerDelegate()
        nonisolated(unsafe) var fired = false
        sut.onDidDisconnect = { _, _, _ in fired = true }
        sut.centralManager(BLETestStub.centralManager(),
                           didDisconnectPeripheral: BLETestStub.peripheral(),
                           error: nil)
        #expect(fired)
    }

    @Test func forwardsDidDisconnectWithTimestamp() {
        let sut = FCBCentralManagerDelegate()
        nonisolated(unsafe) var capturedReconnecting: Bool?
        sut.onDidDisconnectWithTimestamp = { _, _, _, isReconnecting, _ in
            capturedReconnecting = isReconnecting
        }
        sut.centralManager(BLETestStub.centralManager(),
                           didDisconnectPeripheral: BLETestStub.peripheral(),
                           timestamp: 0,
                           isReconnecting: true,
                           error: nil)
        #expect(capturedReconnecting == true)
    }

    #if !os(macOS)
    @Test func forwardsConnectionEventDidOccur() {
        let sut = FCBCentralManagerDelegate()
        nonisolated(unsafe) var fired = false
        sut.onConnectionEventDidOccur = { _, _, _ in fired = true }
        sut.centralManager(BLETestStub.centralManager(),
                           connectionEventDidOccur: .peerConnected,
                           for: BLETestStub.peripheral())
        #expect(fired)
    }

    @Test func forwardsDidUpdateANCSAuthorization() {
        let sut = FCBCentralManagerDelegate()
        nonisolated(unsafe) var fired = false
        sut.onDidUpdateANCSAuthorization = { _, _ in fired = true }
        sut.centralManager(BLETestStub.centralManager(),
                           didUpdateANCSAuthorizationFor: BLETestStub.peripheral())
        #expect(fired)
    }
    #endif
}
