@preconcurrency import CoreBluetooth
@preconcurrency import CoreBluetoothMock
import Foundation
import Testing
@testable import FCBComposable

/// Each of these operations keeps ONE continuation per slot (peripheral, or
/// peripheral + attribute). A second call for an occupied slot used to
/// overwrite the first caller's continuation, which then never resumed. Now
/// the newer call supersedes: the older caller throws `operationCancelled`.
extension CBMBackedTests {
    @Suite @MainActor
    struct CentralOccupiedSlotTests {
        @Test func aSecondConnectFailsTheFirstInsteadOfLeakingIt() async {
            // Out of range: neither connect can complete on its own.
            let rig = await makePendingOpsRig(inRange: false)
            let client = rig.client, id = rig.id
            let first = Task { await outcome(within: 2) { try await client.connect(id, ConnectOptions?.none) } }
            try? await Task.sleep(nanoseconds: 50_000_000)
            let second = Task { await outcome(within: 2) { try await client.connect(id, ConnectOptions?.none) } }
            try? await Task.sleep(nanoseconds: 50_000_000)
            expectThrows(await first.value, .operationCancelled)
            _ = await outcome(within: 2) { try await client.disconnect(id) }
            expectDisconnected(await second.value, id: id)
        }

        @Test func aSecondDiscoverServicesFailsTheFirstInsteadOfLeakingIt() async throws {
            let rig = await makePendingOpsRig()
            _ = try await rig.client.connect(rig.id, ConnectOptions?.none)
            let client = rig.client, id = rig.id
            let first = Task { await outcome(within: 2) { try await client.discoverServices(id, [cbmBatteryServiceUUID]) } }
            try? await Task.sleep(nanoseconds: 50_000_000)
            let second = Task { await outcome(within: 2) { try await client.discoverServices(id, [cbmBatteryServiceUUID]) } }
            expectThrows(await first.value, .operationCancelled)
            expectCompleted(await second.value, "the superseding discoverServices")
        }

        @Test func aSecondDiscoverCharacteristicsFailsTheFirstInsteadOfLeakingIt() async throws {
            let rig = await makePendingOpsRig()
            _ = try await rig.client.connect(rig.id, ConnectOptions?.none)
            _ = try await rig.client.discoverServices(rig.id, [cbmBatteryServiceUUID])
            let client = rig.client, id = rig.id
            let first = Task {
                await outcome(within: 2) { try await client.discoverCharacteristics(id, cbmBatteryServiceUUID, [CBUUID]?.none) }
            }
            try? await Task.sleep(nanoseconds: 50_000_000)
            let second = Task {
                await outcome(within: 2) { try await client.discoverCharacteristics(id, cbmBatteryServiceUUID, [CBUUID]?.none) }
            }
            expectThrows(await first.value, .operationCancelled)
            expectCompleted(await second.value, "the superseding discoverCharacteristics")
        }

        @Test func aSecondWriteWithResponseFailsTheFirstInsteadOfLeakingIt() async throws {
            let rig = await makePendingOpsRig()
            try await rig.connectAndDiscover()
            let client = rig.client, id = rig.id
            let first = Task {
                await outcome(within: 2) { try await client.writeValue(Data([0x01]), id, cbmBatteryLevelUUID, .withResponse) }
            }
            try? await Task.sleep(nanoseconds: 50_000_000)
            let second = Task {
                await outcome(within: 2) { try await client.writeValue(Data([0x02]), id, cbmBatteryLevelUUID, .withResponse) }
            }
            expectThrows(await first.value, .operationCancelled)
            expectCompleted(await second.value, "the superseding write")
        }

        @Test func aSecondSetNotifyFailsTheFirstInsteadOfLeakingIt() async throws {
            let rig = await makePendingOpsRig()
            try await rig.connectAndDiscover()
            let client = rig.client, id = rig.id
            let first = Task { await outcome(within: 2) { try await client.setNotify(true, id, cbmBatteryLevelUUID) } }
            try? await Task.sleep(nanoseconds: 50_000_000)
            let second = Task { await outcome(within: 2) { try await client.setNotify(true, id, cbmBatteryLevelUUID) } }
            expectThrows(await first.value, .operationCancelled)
            expectCompleted(await second.value, "the superseding setNotify")
        }
    }
}
