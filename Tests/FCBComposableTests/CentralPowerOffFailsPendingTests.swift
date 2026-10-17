@preconcurrency import CoreBluetooth
@preconcurrency import CoreBluetoothMock
import ComposableArchitecture
import Foundation
import Testing
@testable import FCBComposable

// MARK: - Power-cycle rig

/// A connectable, advertising, retrievable battery peripheral that answers
/// every GATT request after `pendingOpsResponseLatency`, behind a fresh mock
/// manager wrapped in the live client. Unlike `makePendingOpsRig(inRange: true)`
/// (a peripheral "connected by another app", which does not advertise), this
/// one can be found and connected again after Bluetooth comes back on.
@MainActor
func makePowerCycleRig() async -> PendingOpsRig {
    CBMCentralManagerMock.tearDownSimulation()
    CBMCentralManagerMock.simulateInitialState(.poweredOn)
    let id = UUID()
    let specDelegate = PendingOpsSpecDelegate()
    let characteristic = CBMCharacteristicMock(type: cbmBatteryLevelUUID, properties: [.read, .write, .notify])
    let service = CBMServiceMock(type: cbmBatteryServiceUUID, primary: true, characteristics: characteristic)
    let spec = CBMPeripheralSpec
        .simulatePeripheral(identifier: id, proximity: .near)
        .advertising(advertisementData: [
            CBMAdvertisementDataLocalNameKey: "PowerDev",
            CBMAdvertisementDataServiceUUIDsKey: [cbmBatteryServiceUUID],
            CBMAdvertisementDataIsConnectable: NSNumber(value: true),
        ], withInterval: 0.05)
        .connectable(name: "PowerDev", services: [service], delegate: specDelegate,
                     connectionInterval: pendingOpsResponseLatency)
        .allowForRetrieval()
        .build()
    CBMCentralManagerMock.simulatePeripherals([spec])
    let manager = CBMCentralManagerFactory.instance(forceMock: true)
    await waitForManagerState(manager, toReach: .poweredOn)
    let client = BluetoothCentralClient.makeClient(actor: CentralActor(manager: manager))
    return PendingOpsRig(client: client, manager: manager, spec: spec, specDelegate: specDelegate,
                         characteristic: characteristic, id: id)
}

/// Turns Bluetooth off, waits until FCB itself has handled `.poweredOff`, then
/// turns it on and waits for FCB's `.poweredOn`. Waiting on FCB's state stream
/// (not the manager's `state`) matters: CBM, like CoreBluetooth, reads
/// `central.state` when the delegate callback runs, so an off immediately
/// followed by on is delivered as two `.poweredOn` callbacks and FCB never
/// sees the power-off at all.
@MainActor
func powerCycle(_ client: BluetoothCentralClient) async {
    let cycled = await outcome(within: 3) {
        var states = client.state().makeAsyncIterator()
        _ = await states.next()   // the replayed current state
        CBMCentralManagerMock.simulatePowerOff()
        while let state = await states.next(), state != .poweredOff {}
        CBMCentralManagerMock.simulatePowerOn()
        while let state = await states.next(), state != .poweredOn {}
        return true
    }
    expectCompleted(cycled, "the power cycle")
}

// MARK: - Tests

struct AdapterDownErrorTests {
    @Test func everyStateButPoweredOnMapsToTheErrorPendingOperationsFailWith() {
        #expect(CentralActor.adapterDownError(.poweredOn) == nil)
        #expect(CentralActor.adapterDownError(.poweredOff) == .poweredOff)
        #expect(CentralActor.adapterDownError(.resetting) == .poweredOff)
        #expect(CentralActor.adapterDownError(.unknown) == .poweredOff)
        #expect(CentralActor.adapterDownError(.unsupported) == .unsupported)
        #expect(CentralActor.adapterDownError(.unauthorized) == .unauthorized(CBManager.authorization))
    }
}

extension CBMBackedTests {
    @Suite @MainActor
    struct CentralPowerOffFailsPendingTests {
        @Test func readPendingAtPowerOffThrowsPoweredOff() async throws {
            let rig = await makePendingOpsRig()
            try await rig.connectAndDiscover()
            let client = rig.client, id = rig.id
            let read = Task { await outcome(within: 2) { try await client.readValue(id, cbmBatteryLevelUUID) } }
            try? await Task.sleep(nanoseconds: 50_000_000)
            #expect(rig.specDelegate.readRequests == 1)   // in flight at the peripheral
            CBMCentralManagerMock.simulatePowerOff()
            expectThrows(await read.value, .poweredOff)
        }

        @Test func writePendingAtPowerOffThrowsPoweredOff() async throws {
            let rig = await makePendingOpsRig()
            try await rig.connectAndDiscover()
            let client = rig.client, id = rig.id
            let write = Task {
                await outcome(within: 2) { try await client.writeValue(Data([0x01]), id, cbmBatteryLevelUUID, .withResponse) }
            }
            try? await Task.sleep(nanoseconds: 50_000_000)
            CBMCentralManagerMock.simulatePowerOff()
            expectThrows(await write.value, .poweredOff)
        }

        @Test func setNotifyPendingAtPowerOffThrowsPoweredOff() async throws {
            let rig = await makePendingOpsRig()
            try await rig.connectAndDiscover()
            let client = rig.client, id = rig.id
            let notify = Task { await outcome(within: 2) { try await client.setNotify(true, id, cbmBatteryLevelUUID) } }
            try? await Task.sleep(nanoseconds: 50_000_000)
            CBMCentralManagerMock.simulatePowerOff()
            expectThrows(await notify.value, .poweredOff)
        }

        @Test func discoverServicesPendingAtPowerOffThrowsPoweredOff() async throws {
            let rig = await makePendingOpsRig()
            _ = try await rig.client.connect(rig.id, ConnectOptions?.none)
            let client = rig.client, id = rig.id
            let discovery = Task { await outcome(within: 2) { try await client.discoverServices(id, [cbmBatteryServiceUUID]) } }
            try? await Task.sleep(nanoseconds: 50_000_000)
            #expect(rig.specDelegate.serviceDiscoveryRequests == 1)
            CBMCentralManagerMock.simulatePowerOff()
            expectThrows(await discovery.value, .poweredOff)
        }

        @Test func discoverCharacteristicsPendingAtPowerOffThrowsPoweredOff() async throws {
            let rig = await makePendingOpsRig()
            _ = try await rig.client.connect(rig.id, ConnectOptions?.none)
            _ = try await rig.client.discoverServices(rig.id, [cbmBatteryServiceUUID])
            let client = rig.client, id = rig.id
            let discovery = Task {
                await outcome(within: 2) { try await client.discoverCharacteristics(id, cbmBatteryServiceUUID, [CBUUID]?.none) }
            }
            try? await Task.sleep(nanoseconds: 50_000_000)
            CBMCentralManagerMock.simulatePowerOff()
            expectThrows(await discovery.value, .poweredOff)
        }

        @Test func connectPendingAtPowerOffThrowsPoweredOff() async {
            // Out of range: CBM never completes the connect (as iOS, no timeout).
            let rig = await makePendingOpsRig(inRange: false)
            let client = rig.client, id = rig.id
            let connect = Task { await outcome(within: 2) { try await client.connect(id, ConnectOptions?.none) } }
            try? await Task.sleep(nanoseconds: 50_000_000)
            CBMCentralManagerMock.simulatePowerOff()
            expectThrows(await connect.value, .poweredOff)
        }

        @Test func notificationStreamEndsWithPoweredOffAtPowerOff() async throws {
            let rig = await makePendingOpsRig()
            try await rig.connectAndDiscover()
            try await rig.client.setNotify(true, rig.id, cbmBatteryLevelUUID)
            let stream = rig.client.notifications(rig.id, cbmBatteryLevelUUID)
            let iteration = Task { await outcome(within: 2) { for try await _ in stream {}; return true } }
            try? await Task.sleep(nanoseconds: 50_000_000)
            CBMCentralManagerMock.simulatePowerOff()
            expectThrows(await iteration.value, .poweredOff)
        }

        @Test func disconnectPendingAtPowerOffReturns() async throws {
            // The cancel is counted but never answered, so only the power-off can
            // release the waiting disconnect: the link is down, which is what it wanted.
            let rig = await makePendingOpsRig(makeManager: { CountingCentralManagerMock() })
            let manager = try #require(rig.manager as? CountingCentralManagerMock)
            _ = try await rig.client.connect(rig.id, ConnectOptions?.none)
            manager.ignoresCancel = true
            let client = rig.client, id = rig.id
            let disconnect = Task { await outcome(within: 2) { try await client.disconnect(id) } }
            try? await Task.sleep(nanoseconds: 50_000_000)
            #expect(manager.cancelCount == 1)
            CBMCentralManagerMock.simulatePowerOff()
            expectCompleted(await disconnect.value, "disconnect pending at power-off")
        }

        @Test func scanStreamFinishesAtPowerOff() async {
            let rig = await makeScanRig()
            let scan = ScanConsumer(rig.client.scan([cbmBatteryServiceUUID], ScanOptions(allowDuplicates: true)))
            #expect(await eventually(within: 2) { scan.discoveries.value > 0 })
            CBMCentralManagerMock.simulatePowerOff()
            #expect(await eventually(within: 1) { scan.ended.value },
                    "CoreBluetooth stopped the scan and never resumes it: the stream must finish")
            scan.cancel()
        }

        // MARK: After power-on

        /// A read in flight at power-off used to stay in `pendingReads`, so the
        /// first read after reconnecting threw `operationCancelled`.
        @Test func firstReadAfterAPowerCycleAndReconnectSucceeds() async throws {
            let rig = await makePowerCycleRig()
            try await rig.connectAndDiscover()
            let client = rig.client, id = rig.id
            let stranded = Task { await outcome(within: 2) { try await client.readValue(id, cbmBatteryLevelUUID) } }
            try? await Task.sleep(nanoseconds: 50_000_000)
            #expect(rig.specDelegate.readRequests == 1)
            await powerCycle(rig.client)
            _ = await stranded.value

            _ = await client.retrievePeripherals([id])   // fresh peripheral object (see connectAfterAPowerCycleNeedsNoRetrieve)
            expectCompleted(await outcome(within: 3) { try await rig.connectAndDiscover() }, "reconnect")
            let read = await outcome(within: 3) { try await client.readValue(id, cbmBatteryLevelUUID) }
            switch read {
            case .success(let value)?: #expect(value == Data([0x64]))
            case .failure(let error)?: Issue.record("first read after the power cycle threw \(error)")
            case .none: Issue.record("first read after the power cycle was still pending after 3 s")
            }
        }

        /// The characteristic cache belongs to the invalidated peripheral objects:
        /// like a disconnect, a power-off drops it, so an operation on a reconnected
        /// link that skipped rediscovery fails fast instead of using a dead object.
        @Test func aReadAfterAPowerCycleWithoutRediscoveryThrowsUnknownCharacteristic() async throws {
            let rig = await makePowerCycleRig()
            try await rig.connectAndDiscover()
            await powerCycle(rig.client)
            let client = rig.client, id = rig.id
            _ = await client.retrievePeripherals([id])
            expectCompleted(await outcome(within: 3) { _ = try await client.connect(id, ConnectOptions?.none) }, "reconnect")
            let read = await outcome(within: 2) { try await client.readValue(id, cbmBatteryLevelUUID) }
            switch read {
            case .failure(let error)?:
                guard case .unknownCharacteristic? = error as? BluetoothError else {
                    Issue.record("expected unknownCharacteristic, got \(error)"); return
                }
            case .success?: Issue.record("a read through the pre-power-off characteristic succeeded")
            case .none: Issue.record("a read through the pre-power-off characteristic hung")
            }
        }

        /// Every peripheral object is invalid after Bluetooth leaves `.poweredOn`
        /// (CBM forgets them, as iOS does). A connect that reused FCB's cached
        /// object was silently ignored by the manager and hung forever.
        @Test func connectAfterAPowerCycleNeedsNoRetrieve() async throws {
            let rig = await makePowerCycleRig()
            _ = await rig.client.retrievePeripherals([rig.id])
            _ = try await rig.client.connect(rig.id, ConnectOptions?.none)
            await powerCycle(rig.client)
            let client = rig.client, id = rig.id
            expectCompleted(await outcome(within: 3) { _ = try await client.connect(id, ConnectOptions?.none) },
                            "connect after the power cycle")
        }
    }
}
