import ComposableArchitecture
@preconcurrency import CoreBluetooth
import Foundation
import Testing
@testable import FCBComposable
import ObjectiveC.runtime

@MainActor
struct BluetoothCentralClientContractTests {
    @Test func testValueDisconnectThrowsUnimplemented() async {
        let client = BluetoothCentralClient.testValue
        await withKnownIssue("disconnect should report unimplemented") {
            _ = try await client.disconnect(UUID())
        }
    }
}

// Local stub for creating CBPeripheral instances that cannot be initialized publicly.
// BLETestStub lives in FCBTests which is a separate test target not accessible here.
// We use `class_createInstance` + manual NSUUID ivar injection so `.identifier`
// returns a stable, non-nil UUID (required on macOS 26+/Swift 6.3).
private enum BLETestStubLocal {
    static func peripheral(id: UUID = UUID()) -> CBPeripheral {
        let obj = class_createInstance(CBPeripheral.self, 0)!
        let cb = unsafeDowncast(obj as AnyObject, to: CBPeripheral.self)
        _ = Unmanaged.passRetained(cb)
        // Inject the identifier via the private `_identifier` ivar.
        // CBPeripheral stores the UUID as NSUUID* in `_identifier`.
        let nsuuid = id as NSUUID
        if let ivar = class_getInstanceVariable(CBPeripheral.self, "_identifier") {
            object_setIvar(cb, ivar, nsuuid)
        }
        return cb
    }
}

@MainActor
struct BluetoothCentralClientScanTests {
    @Test func scanStartsScanCallOnManager() async {
        let fake = FakeCentralManager()
        let actor = CentralActor(manager: fake)
        // Call scan and discard the stream — the startScan actor call is queued on creation.
        _ = actor.scan(services: [CBUUID(string: "180F")], options: ScanOptions(allowDuplicates: true))
        try? await Task.sleep(nanoseconds: 50_000_000)
        #expect(fake.scanCalls.count == 1)
        #expect(fake.scanCalls.first?.services == [CBUUID(string: "180F")])
    }

    @Test func scanYieldsDiscoveredPeripherals() async {
        let fake = FakeCentralManager()
        let actor = CentralActor(manager: fake)
        let stream = actor.scan(services: nil, options: nil)
        var iter = stream.makeAsyncIterator()

        let peripheral = BLETestStubLocal.peripheral()
        try? await Task.sleep(nanoseconds: 50_000_000)
        fake.simulateDidDiscover(peripheral, ad: [CBAdvertisementDataLocalNameKey: "MyDev"], rssi: NSNumber(value: -50))

        let discovered = await iter.next()
        #expect(discovered?.advertisementData.localName == "MyDev")
        #expect(discovered?.rssi == -50)
    }

    @Test func stopScanCallsStopOnManager() async {
        let fake = FakeCentralManager()
        let actor = CentralActor(manager: fake)
        try? await Task.sleep(nanoseconds: 50_000_000)
        await actor.stopScan()
        #expect(fake.stopScanCallCount == 1)
    }

    @Test func stateStreamYieldsStateUpdates() async {
        let fake = FakeCentralManager()
        let actor = CentralActor(manager: fake)
        let stream = actor.stateStream()
        var iter = stream.makeAsyncIterator()
        try? await Task.sleep(nanoseconds: 50_000_000)
        fake.simulateDidUpdateState(.poweredOn)
        let next = await iter.next()
        #expect(next == .poweredOn)
    }

    @Test func eventStreamYieldsDidConnect() async {
        let fake = FakeCentralManager()
        let actor = CentralActor(manager: fake)
        let stream = actor.eventStream()
        var iter = stream.makeAsyncIterator()
        try? await Task.sleep(nanoseconds: 50_000_000)
        let peripheral = BLETestStubLocal.peripheral()
        fake.simulateDidConnect(peripheral)
        let event = await iter.next()
        if case .didConnect(let p) = event {
            #expect(p.id == peripheral.identifier)
        } else {
            Issue.record("expected .didConnect, got \(String(describing: event))")
        }
    }
}
