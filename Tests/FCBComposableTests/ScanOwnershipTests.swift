@preconcurrency import CoreBluetooth
@preconcurrency import CoreBluetoothMock
import ComposableArchitecture
import Foundation
import Testing
@testable import FCBComposable

// MARK: - Scan rig

/// Drains one scan stream in the background, counting discoveries and noting
/// when the stream ends (finished by FCB, or cancelled by `cancel()`).
final class ScanConsumer: @unchecked Sendable {
    let discoveries = LockIsolated(0)
    let ended = LockIsolated(false)
    private var task: Task<Void, Never>?

    init(_ stream: AsyncStream<DiscoveredPeripheral>) {
        let discoveries = discoveries
        let ended = ended
        task = Task {
            for await _ in stream { discoveries.withValue { $0 += 1 } }
            ended.setValue(true)
        }
    }

    func cancel() { task?.cancel() }
}

/// Polls `condition` every 10 ms for at most `seconds`.
func eventually(within seconds: Double, _ condition: @Sendable () -> Bool) async -> Bool {
    for _ in 0..<Int(seconds * 100) {
        if condition() { return true }
        try? await Task.sleep(nanoseconds: 10_000_000)
    }
    return condition()
}

struct ScanRig {
    let actor: CentralActor
    let client: BluetoothCentralClient
    let manager: CBMCentralManager
}

/// One battery-service peripheral advertising every 50 ms behind a fresh mock
/// manager wrapped in the live client.
@MainActor
func makeScanRig() async -> ScanRig {
    CBMCentralManagerMock.tearDownSimulation()
    CBMCentralManagerMock.simulateInitialState(.poweredOn)
    let characteristic = CBMCharacteristicMock(type: cbmBatteryLevelUUID, properties: [.read])
    let service = CBMServiceMock(type: cbmBatteryServiceUUID, primary: true, characteristics: characteristic)
    let spec = CBMPeripheralSpec
        .simulatePeripheral(identifier: UUID(), proximity: .near)
        .advertising(advertisementData: [
            CBMAdvertisementDataLocalNameKey: "ScanDev",
            CBMAdvertisementDataServiceUUIDsKey: [cbmBatteryServiceUUID],
            CBMAdvertisementDataIsConnectable: NSNumber(value: true),
        ], withInterval: 0.05)
        .connectable(name: "ScanDev", services: [service], delegate: nil, connectionInterval: 0.01)
        .allowForRetrieval()
        .build()
    CBMCentralManagerMock.simulatePeripherals([spec])
    let manager = CBMCentralManagerFactory.instance(forceMock: true)
    await waitForManagerState(manager, toReach: .poweredOn)
    let actor = CentralActor(manager: manager)
    return ScanRig(actor: actor, client: BluetoothCentralClient.makeClient(actor: actor), manager: manager)
}

extension CentralActor {
    /// Test-only: blocks this actor's executor, so jobs enqueued meanwhile
    /// queue up behind it and then run in priority order.
    func occupyForTesting(seconds: Double) {
        Thread.sleep(forTimeInterval: seconds)
    }
}

// MARK: - Tests

extension CBMBackedTests {
    @Suite @MainActor
    struct ScanOwnershipTests {
        /// Open side of the radio-picker race: a slow owner's late `stopScan()`
        /// used to end whatever scan was current — the picker's.
        @Test func stopScanDoesNotEndAnotherOwnersScan() async {
            let rig = await makeScanRig()
            let options = ScanOptions(allowDuplicates: true)
            let first = ScanConsumer(rig.client.scan([cbmBatteryServiceUUID], options))
            #expect(await eventually(within: 2) { first.discoveries.value > 0 })
            let second = ScanConsumer(rig.client.scan([cbmBatteryServiceUUID], options))
            #expect(await eventually(within: 2) { second.discoveries.value > 0 })

            await rig.client.stopScan()   // the first owner's late, global stop
            try? await Task.sleep(nanoseconds: 100_000_000)

            let before = second.discoveries.value
            #expect(await eventually(within: 1) { second.discoveries.value > before },
                    "the second owner's scan must keep yielding")
            #expect(!second.ended.value)
            #expect(rig.manager.isScanning)
            first.cancel()
            second.cancel()
        }

        /// A newer scan supersedes the radio; the older stream FINISHES so its
        /// owner can tell it lost the scan (it used to go quiet forever).
        @Test func aNewerScanFinishesTheSupersededStream() async {
            let rig = await makeScanRig()
            let options = ScanOptions(allowDuplicates: true)
            let older = ScanConsumer(rig.client.scan([cbmBatteryServiceUUID], options))
            #expect(await eventually(within: 2) { older.discoveries.value > 0 })
            let newer = ScanConsumer(rig.client.scan([cbmBatteryServiceUUID], options))
            #expect(await eventually(within: 2) { newer.discoveries.value > 0 })

            #expect(await eventually(within: 1) { older.ended.value },
                    "the superseded stream must finish")
            let before = newer.discoveries.value
            #expect(await eventually(within: 1) { newer.discoveries.value > before },
                    "the superseded stream's termination must not stop the newer scan")
            older.cancel()
            newer.cancel()
        }

        /// `scan()` starts the radio and its stream's termination stops it in two
        /// separate tasks. When the termination reaches the actor first, the
        /// start must not run a radio scan nobody owns. Deterministic: the actor
        /// is held busy while both jobs queue, the end at a higher priority.
        @Test func aStreamEndedBeforeItsScanStartedNeverStartsTheRadio() async {
            let rig = await makeScanRig()
            let actor = rig.actor
            var ownerlessScans = 0
            for _ in 0..<10 {
                let hold = Task.detached(priority: .high) { await actor.occupyForTesting(seconds: 0.2) }
                try? await Task.sleep(nanoseconds: 50_000_000)
                let stream = await Task.detached(priority: .background) {
                    actor.scan(services: [cbmBatteryServiceUUID], options: nil)
                }.value
                let consumer = Task(priority: .high) { for await _ in stream {} }
                try? await Task.sleep(nanoseconds: 10_000_000)
                consumer.cancel()
                _ = await consumer.value
                await hold.value
                try? await Task.sleep(nanoseconds: 50_000_000)
                if rig.manager.isScanning { ownerlessScans += 1 }
                rig.manager.stopScan()   // reset for the next round
            }
            #expect(ownerlessScans == 0)
        }

        /// CoreBluetooth drops a scan issued while Bluetooth is not powered on;
        /// the stream used to stay open forever, yielding nothing.
        @Test func aScanRequestedWhileBluetoothIsOffFinishesAtOnce() async {
            let actor = await makeEmptyMockActor(state: .poweredOff)
            let scan = ScanConsumer(actor.scan(services: [cbmBatteryServiceUUID], options: nil))
            #expect(await eventually(within: 1) { scan.ended.value })
            scan.cancel()
        }

        /// `stopScan()` is a no-op now, so a consumer that `break`s out of its
        /// scan loop relies on dropping the stream to end its scan (MultiRouter's
        /// LiveMeshtasticOps does exactly this).
        @Test func breakingOutOfTheScanLoopAndDroppingTheStreamStopsTheRadio() async {
            let rig = await makeScanRig()
            let client = rig.client
            func firstDiscovery() async -> UUID? {
                let stream = client.scan([cbmBatteryServiceUUID], nil)
                for await discovered in stream { return discovered.peripheral.id }
                return nil
            }
            #expect(await firstDiscovery() != nil)
            #expect(await eventually(within: 1) { !rig.manager.isScanning })
        }
    }
}
