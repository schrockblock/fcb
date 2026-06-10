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

@MainActor
struct BluetoothCentralClientConnectTests {
    @Test func connectResolvesOnDidConnect() async throws {
        let fake = FakeCentralManager()
        let peripheral = BLETestStubLocal.peripheral()
        fake.registeredPeripherals[peripheral.identifier] = peripheral
        let actor = CentralActor(manager: fake)
        try? await Task.sleep(nanoseconds: 50_000_000)

        let connectTask = Task { try await actor.connect(id: peripheral.identifier, options: nil) }
        try? await Task.sleep(nanoseconds: 50_000_000)
        fake.simulateDidConnect(peripheral)

        let result = try await connectTask.value
        #expect(result.id == peripheral.identifier)
        #expect(fake.connectCalls.count == 1)
    }

    @Test func connectThrowsConnectionFailedOnDidFailToConnect() async {
        let fake = FakeCentralManager()
        let peripheral = BLETestStubLocal.peripheral()
        fake.registeredPeripherals[peripheral.identifier] = peripheral
        let actor = CentralActor(manager: fake)
        try? await Task.sleep(nanoseconds: 50_000_000)

        let task = Task { try await actor.connect(id: peripheral.identifier, options: nil) }
        try? await Task.sleep(nanoseconds: 50_000_000)
        fake.simulateDidFailToConnect(peripheral, error: NSError(domain: "x", code: 1))

        await #expect(throws: BluetoothError.self) {
            _ = try await task.value
        }
    }

    @Test func connectThrowsUnknownPeripheralWhenNotRegistered() async {
        let fake = FakeCentralManager()
        let actor = CentralActor(manager: fake)
        try? await Task.sleep(nanoseconds: 50_000_000)
        await #expect(throws: BluetoothError.self) {
            _ = try await actor.connect(id: UUID(), options: nil)
        }
    }

    @Test func disconnectResolvesOnDidDisconnect() async throws {
        let fake = FakeCentralManager()
        let peripheral = BLETestStubLocal.peripheral()
        fake.registeredPeripherals[peripheral.identifier] = peripheral
        let actor = CentralActor(manager: fake)
        try? await Task.sleep(nanoseconds: 50_000_000)

        // Connect first so the actor knows about this peripheral
        let connectTask = Task { try await actor.connect(id: peripheral.identifier, options: nil) }
        try? await Task.sleep(nanoseconds: 50_000_000)
        fake.simulateDidConnect(peripheral)
        _ = try await connectTask.value

        let disconnectTask = Task { try await actor.disconnect(id: peripheral.identifier) }
        try? await Task.sleep(nanoseconds: 50_000_000)
        fake.simulateDidDisconnect(peripheral, error: nil)
        try await disconnectTask.value
        #expect(fake.cancelCalls.count == 1)
    }
}

@MainActor
struct BluetoothCentralClientDiscoveryTests {
    @Test func discoverServicesThrowsUnknownPeripheral() async {
        let fake = FakeCentralManager()
        let actor = CentralActor(manager: fake)
        try? await Task.sleep(nanoseconds: 50_000_000)
        await #expect(throws: BluetoothError.self) {
            _ = try await actor.discoverServices(peripheralID: UUID(), serviceIDs: nil)
        }
    }

    @Test func discoverServicesResolvesWhenDelegateFires() async throws {
        let fake = FakeCentralManager()
        let actor = CentralActor(manager: fake)
        let pid = UUID()
        let fakeConn = FakePeripheralConnection(identifier: pid)
        await actor.injectPeripheralForTest(id: pid, connection: fakeConn)

        let task = Task { try await actor.discoverServices(peripheralID: pid, serviceIDs: nil) }
        try? await Task.sleep(nanoseconds: 50_000_000)
        #expect(fakeConn.discoverServicesCalls.count == 1)

        // Simulate completion: services empty (real CB conversion would happen here)
        await actor.completeDiscoverServicesForTest(peripheralID: pid, services: [])
        let services = try await task.value
        #expect(services.isEmpty)
    }
}
