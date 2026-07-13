import CoreBluetoothMock
import Foundation
import Testing
@testable import FCBComposable

/// CBM mock managers initialize asynchronously — `state` stays `.unknown`
/// until a queue hop after creation completes. Poll until the expected
/// state lands (also used by later tasks' test files).
@MainActor
func waitForManagerState(_ manager: CBMCentralManager, toReach state: CBMManagerState) async {
    for _ in 0..<200 {
        if manager.state == state { return }
        try? await Task.sleep(nanoseconds: 10_000_000)
    }
}

extension CBMBackedTests {
    @Suite @MainActor
    struct FCBMDelegateTests {
        @Test func centralDelegateForwardsDidUpdateState() async {
            CBMCentralManagerMock.tearDownSimulation()
            CBMCentralManagerMock.simulateInitialState(.poweredOn)
            let delegate = FCBMCentralManagerDelegate()
            nonisolated(unsafe) var received: CBMManagerState?
            delegate.onDidUpdateState = { central in received = central.state }
            // Attach the wrapper at creation so CBM's own initialization
            // callback exercises the real forwarding path.
            let manager = CBMCentralManagerFactory.instance(delegate: delegate, queue: nil, forceMock: true)
            await waitForManagerState(manager, toReach: .poweredOn)
            #expect(received == .poweredOn)
        }

        @Test func peripheralDelegateForwardsDidUpdateValue() async {
            CBMCentralManagerMock.tearDownSimulation()
            CBMCentralManagerMock.simulateInitialState(.poweredOn)
            let id = UUID()
            let spec = CBMPeripheralSpec
                .simulatePeripheral(identifier: id)
                .connectable(name: "WrapperDev", services: [], delegate: nil)
                .allowForRetrieval()
                .build()
            CBMCentralManagerMock.simulatePeripherals([spec])
            let manager = CBMCentralManagerFactory.instance(forceMock: true)
            await waitForManagerState(manager, toReach: .poweredOn)
            let peripheral = manager.retrievePeripherals(withIdentifiers: [id]).first!
            let characteristic = CBMCharacteristicMock(type: CBMUUID(string: "2A19"), properties: [.read])
            let delegate = FCBMPeripheralDelegate()
            nonisolated(unsafe) var receivedID: CBMUUID?
            delegate.onDidUpdateValueForCharacteristic = { _, c, _ in receivedID = c.uuid }
            delegate.peripheral(peripheral, didUpdateValueFor: characteristic, error: nil)
            #expect(receivedID == CBMUUID(string: "2A19"))
        }
    }
}
