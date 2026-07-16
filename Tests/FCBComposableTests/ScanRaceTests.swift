@preconcurrency import CoreBluetooth
@preconcurrency import CoreBluetoothMock
import ComposableArchitecture
import Foundation
import Testing
@testable import FCBComposable

extension CBMBackedTests {
    @Suite @MainActor
    struct ScanRaceTests {
        /// Terminating an old scan stream must not kill a newer scan stream that
        /// replaced it. Without the token-guard fix, A's onTermination endScan
        /// fires after B has started, clearing the shared scanContinuation and
        /// stopping the manager — B never yields a second discovery.
        ///
        /// Protocol: wait for B's FIRST discovery, THEN terminate A (cancel taskA),
        /// then assert B yields a SECOND discovery. If stale endScan kills B,
        /// the second discovery never arrives (3s timeout → nil → test fails).
        @Test func restartedScanSurvivesStaleTermination() async throws {
            CBMCentralManagerMock.tearDownSimulation()
            CBMCentralManagerMock.simulateInitialState(.poweredOn)

            let id = UUID()
            let characteristic = CBMCharacteristicMock(type: cbmBatteryLevelUUID, properties: [.read, .notify])
            let service = CBMServiceMock(type: cbmBatteryServiceUUID, primary: true, characteristics: characteristic)
            let spec = CBMPeripheralSpec
                .simulatePeripheral(identifier: id, proximity: .near)
                .advertising(advertisementData: [
                    CBMAdvertisementDataLocalNameKey: "RaceDev",
                    CBMAdvertisementDataServiceUUIDsKey: [cbmBatteryServiceUUID],
                    CBMAdvertisementDataIsConnectable: true as NSNumber,
                ], withInterval: 0.05)  // advertises every 50ms
                .connectable(name: "RaceDev", services: [service], delegate: nil, connectionInterval: 0.01)
                .allowForRetrieval()
                .build()
            CBMCentralManagerMock.simulatePeripherals([spec])

            let manager = CBMCentralManagerFactory.instance(forceMock: true)
            await waitForManagerState(manager, toReach: .poweredOn)
            let actor = CentralActor(manager: manager)

            // Use allowDuplicates so the mock reports the peripheral on every
            // advertisement interval (~50ms) — needed for B to receive a
            // SECOND discovery after A is terminated.
            let scanOptions = ScanOptions(allowDuplicates: true)

            // Start scan stream A in a background task that just drains it.
            // Cancelling taskA causes the stream's `for await` to exit, which
            // triggers the stream's onTermination → Task { await actor.endScan() }.
            let taskA = Task { @MainActor in
                let streamA = actor.scan(services: [cbmBatteryServiceUUID], options: scanOptions)
                for await _ in streamA { }
            }

            // Give A's scan time to start.
            try await Task.sleep(nanoseconds: 100_000_000)

            // Start scan stream B. B's startScan replaces A's scanContinuation.
            let streamB = actor.scan(services: [cbmBatteryServiceUUID], options: scanOptions)

            // Collect B's discoveries into a shared box so we can access
            // them from the @MainActor test body without Sendability issues.
            let discoveries = LockIsolated<[UUID]>([])
            let taskB = Task { @MainActor in
                for await d in streamB {
                    discoveries.withValue { $0.append(d.peripheral.id) }
                }
            }

            // Wait for B's first discovery — confirms B is active.
            var waited = 0
            while discoveries.value.isEmpty && waited < 100 {
                try await Task.sleep(nanoseconds: 50_000_000) // 50ms per tick
                waited += 1
            }
            #expect(!discoveries.value.isEmpty, "Stream B must see its first discovery within 5s")
            #expect(discoveries.value.first == id)

            // NOW cancel A. Its Task-wrapped endScan will fire and attempt to
            // clear the continuation. Without token-guard it kills B's scan.
            taskA.cancel()

            // Give A's stale endScan task time to run.
            try await Task.sleep(nanoseconds: 200_000_000)

            // B must still yield at least one MORE discovery (device keeps advertising ~50ms).
            let countAfterA = discoveries.value.count
            var waited2 = 0
            while discoveries.value.count <= countAfterA && waited2 < 100 {
                try await Task.sleep(nanoseconds: 50_000_000)
                waited2 += 1
            }
            taskB.cancel()
            #expect(discoveries.value.count > countAfterA,
                    "Stream B must receive further discoveries after stream A's stale endScan fires — token guard required")
        }
    }
}
