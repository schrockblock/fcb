@preconcurrency import CoreBluetooth
@preconcurrency import CoreBluetoothMock
import Foundation
import Testing
@testable import FCBComposable

/// Minimal spec delegate: default implementations are enough for this test.
private final class NoopSpecDelegate: CBMPeripheralSpecDelegate {}

extension CBMBackedTests {
    @Suite @MainActor
    struct BluetoothCentralL2CAPTests {
        @Test func mockedCentralThrowsGracefullyInsteadOfCrashing() async throws {
            CBMCentralManagerMock.tearDownSimulation()
            CBMCentralManagerMock.simulateInitialState(.poweredOn)
            let id = UUID()
            let characteristic = CBMCharacteristicMock(type: cbmBatteryLevelUUID, properties: [.read])
            let service = CBMServiceMock(type: cbmBatteryServiceUUID, primary: true, characteristics: characteristic)
            let spec = CBMPeripheralSpec
                .simulatePeripheral(identifier: id, proximity: .near)
                .advertising(advertisementData: [
                    CBMAdvertisementDataLocalNameKey: "L2CAPDev",
                    CBMAdvertisementDataServiceUUIDsKey: [cbmBatteryServiceUUID],
                    CBMAdvertisementDataIsConnectable: true as NSNumber,
                ], withInterval: 0.05)
                .connectable(name: "L2CAPDev", services: [service], delegate: NoopSpecDelegate(), connectionInterval: 0.01)
                .build()
            CBMCentralManagerMock.simulatePeripherals([spec])

            let client = BluetoothCentralClient.mocked()
            var state: CBManagerState = .unknown
            for _ in 0..<200 {
                var stateIterator = client.state().makeAsyncIterator()
                state = await stateIterator.next() ?? .unknown
                if state == .poweredOn { break }
                try? await Task.sleep(nanoseconds: 10_000_000)
            }
            #expect(state == .poweredOn)

            var scanIterator = client.scan([cbmBatteryServiceUUID], ScanOptions?.none).makeAsyncIterator()
            let discovered = await scanIterator.next()
            let pid = try #require(discovered?.peripheral.id)
            _ = try await client.connect(pid, ConnectOptions?.none)

            await #expect(throws: BluetoothError.l2capNotSupported) {
                _ = try await client.openL2CAPChannel(pid, 0x0081)
            }
        }

        @Test func unknownPeripheralThrowsUnknownPeripheral() async throws {
            CBMCentralManagerMock.tearDownSimulation()
            CBMCentralManagerMock.simulateInitialState(.poweredOn)
            let client = BluetoothCentralClient.mocked()
            var state: CBManagerState = .unknown
            for _ in 0..<200 {
                var stateIterator = client.state().makeAsyncIterator()
                state = await stateIterator.next() ?? .unknown
                if state == .poweredOn { break }
                try? await Task.sleep(nanoseconds: 10_000_000)
            }
            let strangerID = UUID()
            await #expect(throws: BluetoothError.unknownPeripheral(strangerID)) {
                _ = try await client.openL2CAPChannel(strangerID, 0x0081)
            }
        }
    }
}
