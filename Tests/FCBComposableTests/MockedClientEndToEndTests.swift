@preconcurrency import CoreBluetooth
@preconcurrency import CoreBluetoothMock
import Foundation
import Testing
@testable import FCBComposable

extension CBMBackedTests {
    @Suite @MainActor
    struct MockedClientEndToEndTests {
        @Test func fullRoundTripThroughMockedClient() async throws {
            CBMCentralManagerMock.tearDownSimulation()
            CBMCentralManagerMock.simulateInitialState(.poweredOn)
            let id = UUID()
            let characteristic = CBMCharacteristicMock(type: cbmBatteryLevelUUID, properties: [.read, .write, .notify])
            let service = CBMServiceMock(type: cbmBatteryServiceUUID, primary: true, characteristics: characteristic)
            let specDelegate = RecordingSpecDelegate()
            let spec = CBMPeripheralSpec
                .simulatePeripheral(identifier: id, proximity: .near)
                .advertising(advertisementData: [
                    CBMAdvertisementDataLocalNameKey: "E2EDev",
                    CBMAdvertisementDataServiceUUIDsKey: [cbmBatteryServiceUUID],
                    CBMAdvertisementDataIsConnectable: true as NSNumber,
                ], withInterval: 0.05)
                .connectable(name: "E2EDev", services: [service], delegate: specDelegate, connectionInterval: 0.01)
                .build()
            CBMCentralManagerMock.simulatePeripherals([spec])

            let client = BluetoothCentralClient.mocked()

            // The mock manager powers on asynchronously. Poll through the
            // public state stream — each new subscription replays the
            // manager's current state.
            var state: CBManagerState = .unknown
            for _ in 0..<200 {
                var stateIter = client.state().makeAsyncIterator()
                state = await stateIter.next() ?? .unknown
                if state == .poweredOn { break }
                try? await Task.sleep(nanoseconds: 10_000_000)
            }
            #expect(state == .poweredOn)

            // Scan
            var scanIter = client.scan([cbmBatteryServiceUUID], ScanOptions?.none).makeAsyncIterator()
            let discovered = await scanIter.next()
            #expect(discovered?.advertisementData.localName == "E2EDev")
            let pid = try #require(discovered?.peripheral.id)

            // Connect + discover
            let connected = try await client.connect(pid, ConnectOptions?.none)
            #expect(connected.id == id)
            let services = try await client.discoverServices(pid, [cbmBatteryServiceUUID])
            #expect(services.map { $0.id } == [cbmBatteryServiceUUID])
            let characteristics = try await client.discoverCharacteristics(pid, cbmBatteryServiceUUID, [CBUUID]?.none)
            #expect(characteristics.contains { $0.id == cbmBatteryLevelUUID })

            // Write with response reaches the spec delegate
            try await client.writeValue(Data([0x2A]), pid, cbmBatteryLevelUUID, CBCharacteristicWriteType.withResponse)
            #expect(specDelegate.writes.first?.data == Data([0x2A]))

            // Notifications round-trip
            try await client.setNotify(true, pid, cbmBatteryLevelUUID)
            var notifIter = client.notifications(pid, cbmBatteryLevelUUID).makeAsyncIterator()
            try? await Task.sleep(nanoseconds: 50_000_000)
            spec.simulateValueUpdate(Data([0xAA]), for: characteristic)
            let value = try await notifIter.next()
            #expect(value == Data([0xAA]))
        }
    }
}
