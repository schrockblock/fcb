@preconcurrency import CoreBluetooth
import CoreBluetoothMock
import Foundation
import Testing
@testable import FCBComposable

extension CBMBackedTests {
    @Suite @MainActor
    struct CBMMappingTests {
        @Test func serviceMapsUUIDAndPrimary() {
            let pid = UUID()
            let service = CBMServiceMock(type: CBMUUID(string: "180F"), primary: true)
            let mapped = Service(service, peripheralID: pid)
            #expect(mapped.id == CBMUUID(string: "180F"))
            #expect(mapped.peripheralID == pid)
            #expect(mapped.isPrimary)
        }

        @Test func characteristicMapsFields() {
            let pid = UUID()
            let characteristic = CBMCharacteristicMock(type: CBMUUID(string: "2A19"), properties: [.read, .notify])
            let service = CBMServiceMock(type: CBMUUID(string: "180F"), primary: true, characteristics: characteristic)
            let mapped = Characteristic(characteristic, peripheralID: pid)
            #expect(mapped.id == CBMUUID(string: "2A19"))
            #expect(mapped.serviceID == CBMUUID(string: "180F"))
            #expect(mapped.peripheralID == pid)
            #expect(mapped.properties.contains(.notify))
            #expect(mapped.isNotifying == false)
            // The characteristic's service back-pointer is weak; keep the
            // service alive through the assertions.
            withExtendedLifetime(service) {}
        }

        @Test func peripheralMapsIdentifierNameAndState() async {
            CBMCentralManagerMock.tearDownSimulation()
            CBMCentralManagerMock.simulateInitialState(.poweredOn)
            let id = UUID()
            let spec = CBMPeripheralSpec
                .simulatePeripheral(identifier: id)
                .connectable(name: "Mapped", services: [], delegate: nil)
                .allowForRetrieval()
                .build()
            CBMCentralManagerMock.simulatePeripherals([spec])
            let manager = CBMCentralManagerFactory.instance(forceMock: true)
            await waitForManagerState(manager, toReach: .poweredOn)
            let cbm = manager.retrievePeripherals(withIdentifiers: [id]).first!
            let mapped = Peripheral(cbm)
            #expect(mapped.id == id)
            // CBM mock peripherals expose a name only after being scanned or
            // connected; a retrieved-but-never-connected peripheral has none
            // (CBMPeripheralMock.name = wasConnected ? spec name : last ad name).
            #expect(mapped.name == nil)
            #expect(mapped.state == .disconnected)
        }

        @Test func managerStateBridgesAllCases() {
            #expect(CBManagerState(CBMManagerState.unknown) == .unknown)
            #expect(CBManagerState(CBMManagerState.resetting) == .resetting)
            #expect(CBManagerState(CBMManagerState.unsupported) == .unsupported)
            #expect(CBManagerState(CBMManagerState.unauthorized) == .unauthorized)
            #expect(CBManagerState(CBMManagerState.poweredOff) == .poweredOff)
            #expect(CBManagerState(CBMManagerState.poweredOn) == .poweredOn)
        }
    }
}
