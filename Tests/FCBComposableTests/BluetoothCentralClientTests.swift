import ComposableArchitecture
@preconcurrency import CoreBluetooth
@preconcurrency import CoreBluetoothMock
import Foundation
import Testing
@testable import FCBComposable

@MainActor
struct BluetoothCentralClientContractTests {
    @Test func testValueDisconnectThrowsUnimplemented() async {
        let client = BluetoothCentralClient.testValue
        await withKnownIssue("disconnect should report unimplemented") {
            _ = try await client.disconnect(UUID())
        }
    }
}

// MARK: - CBM simulation harness

let cbmBatteryServiceUUID = CBMUUID(string: "180F")
let cbmBatteryLevelUUID = CBMUUID(string: "2A19")

/// Spec delegate that answers reads with a canned value and records writes.
final class RecordingSpecDelegate: CBMPeripheralSpecDelegate, @unchecked Sendable {
    var readValue = Data([0x64])
    private(set) var writes: [(characteristicUUID: CBMUUID, data: Data)] = []

    func peripheral(_ peripheral: CBMPeripheralSpec,
                    didReceiveReadRequestFor characteristic: CBMCharacteristicMock) -> Result<Data, any Error> {
        .success(readValue)
    }

    func peripheral(_ peripheral: CBMPeripheralSpec,
                    didReceiveWriteRequestFor characteristic: CBMCharacteristicMock,
                    data: Data) -> Result<Void, any Error> {
        writes.append((characteristic.uuid, data))
        return .success(())
    }
}

struct MockRadioSetup {
    let actor: CentralActor
    let spec: CBMPeripheralSpec
    let specDelegate: RecordingSpecDelegate
    let characteristic: CBMCharacteristicMock
    let id: UUID
}

/// Tears down any previous simulation and stands up one battery-service
/// peripheral behind a fresh mock manager wrapped in a CentralActor.
/// Waits for the manager's async initialization to reach the simulated
/// state (via `waitForManagerState` from FCBMDelegateTests.swift) before
/// wrapping it — otherwise early calls see `.unknown`.
@MainActor
func makeMockRadio(id: UUID = UUID(), state: CBMManagerState = .poweredOn) async -> MockRadioSetup {
    CBMCentralManagerMock.tearDownSimulation()
    CBMCentralManagerMock.simulateInitialState(state)
    let specDelegate = RecordingSpecDelegate()
    let batteryLevel = CBMCharacteristicMock(type: cbmBatteryLevelUUID, properties: [.read, .write, .notify])
    let batteryService = CBMServiceMock(type: cbmBatteryServiceUUID, primary: true, characteristics: batteryLevel)
    let spec = CBMPeripheralSpec
        .simulatePeripheral(identifier: id, proximity: .near)
        .advertising(advertisementData: [
            CBMAdvertisementDataLocalNameKey: "MockDev",
            CBMAdvertisementDataServiceUUIDsKey: [cbmBatteryServiceUUID],
            CBMAdvertisementDataIsConnectable: NSNumber(value: true),
        ], withInterval: 0.05)
        .connectable(name: "MockDev", services: [batteryService], delegate: specDelegate, connectionInterval: 0.01)
        .allowForRetrieval()
        .build()
    CBMCentralManagerMock.simulatePeripherals([spec])
    let manager = CBMCentralManagerFactory.instance(forceMock: true)
    await waitForManagerState(manager, toReach: state)
    let actor = CentralActor(manager: manager)
    return MockRadioSetup(actor: actor, spec: spec, specDelegate: specDelegate, characteristic: batteryLevel, id: id)
}

/// A mock manager with NO simulated peripherals (for unknown-peripheral paths).
@MainActor
func makeEmptyMockActor(state: CBMManagerState = .poweredOn) async -> CentralActor {
    CBMCentralManagerMock.tearDownSimulation()
    CBMCentralManagerMock.simulateInitialState(state)
    CBMCentralManagerMock.simulatePeripherals([])
    let manager = CBMCentralManagerFactory.instance(forceMock: true)
    await waitForManagerState(manager, toReach: state)
    return CentralActor(manager: manager)
}

/// Connects and discovers the battery service + characteristic — the
/// precondition for read/write/notify tests.
@MainActor
func connectAndDiscover(_ setup: MockRadioSetup) async throws {
    _ = try await setup.actor.connect(id: setup.id, options: nil)
    _ = try await setup.actor.discoverServices(peripheralID: setup.id, serviceIDs: [cbmBatteryServiceUUID])
    _ = try await setup.actor.discoverCharacteristics(peripheralID: setup.id, serviceID: cbmBatteryServiceUUID, characteristicIDs: nil)
}

// MARK: - Suites (all inside the serialized CBM parent suite)

extension CBMBackedTests {
    @Suite @MainActor
    struct CentralScanAndStateTests {
        @Test func scanYieldsDiscoveredPeripheral() async {
            let setup = await makeMockRadio()
            let stream = setup.actor.scan(services: [cbmBatteryServiceUUID], options: nil)
            var iter = stream.makeAsyncIterator()
            let discovered = await iter.next()
            #expect(discovered?.advertisementData.localName == "MockDev")
            #expect(discovered?.peripheral.id == setup.id)
        }

        @Test func stateStreamReplaysCurrentStateOnSubscribe() async {
            let setup = await makeMockRadio()
            var iter = setup.actor.stateStream().makeAsyncIterator()
            let first = await iter.next()
            #expect(first == .poweredOn)
        }

        @Test func stateStreamYieldsPowerOff() async {
            let setup = await makeMockRadio()
            var iter = setup.actor.stateStream().makeAsyncIterator()
            let first = await iter.next()
            #expect(first == .poweredOn)
            CBMCentralManagerMock.simulatePowerOff()
            let next = await iter.next()
            #expect(next == .poweredOff)
        }

        @Test func eventStreamYieldsDidConnect() async throws {
            let setup = await makeMockRadio()
            let stream = setup.actor.eventStream()
            let connectTask = Task { try await setup.actor.connect(id: setup.id, options: nil) }
            var connectedID: UUID?
            for await event in stream {
                if case .didConnect(let p) = event {
                    connectedID = p.id
                    break
                }
            }
            _ = try await connectTask.value
            #expect(connectedID == setup.id)
        }
    }

    @Suite @MainActor
    struct CentralConnectTests {
        @Test func connectResolvesViaRetrieval() async throws {
            let setup = await makeMockRadio()
            let peripheral = try await setup.actor.connect(id: setup.id, options: nil)
            #expect(peripheral.id == setup.id)
            #expect(peripheral.state == .connected)
        }

        @Test func connectThrowsUnknownPeripheral() async {
            let actor = await makeEmptyMockActor()
            await #expect(throws: BluetoothError.self) {
                _ = try await actor.connect(id: UUID(), options: nil)
            }
        }

        @Test func connectThrowsWhenPoweredOff() async {
            let actor = await makeEmptyMockActor(state: .poweredOff)
            await #expect(throws: BluetoothError.poweredOff) {
                _ = try await actor.connect(id: UUID(), options: nil)
            }
        }

        @Test func disconnectResolves() async throws {
            let setup = await makeMockRadio()
            _ = try await setup.actor.connect(id: setup.id, options: nil)
            try await setup.actor.disconnect(id: setup.id)
        }
    }

    @Suite @MainActor
    struct CentralDiscoveryTests {
        @Test func discoverServicesThrowsUnknownPeripheral() async {
            let actor = await makeEmptyMockActor()
            await #expect(throws: BluetoothError.self) {
                _ = try await actor.discoverServices(peripheralID: UUID(), serviceIDs: nil)
            }
        }

        @Test func discoverServicesReturnsMappedService() async throws {
            let setup = await makeMockRadio()
            _ = try await setup.actor.connect(id: setup.id, options: nil)
            let services = try await setup.actor.discoverServices(peripheralID: setup.id, serviceIDs: [cbmBatteryServiceUUID])
            #expect(services.map(\.id) == [cbmBatteryServiceUUID])
            #expect(services.first?.isPrimary == true)
        }

        @Test func discoverCharacteristicsReturnsMappedCharacteristic() async throws {
            let setup = await makeMockRadio()
            _ = try await setup.actor.connect(id: setup.id, options: nil)
            _ = try await setup.actor.discoverServices(peripheralID: setup.id, serviceIDs: [cbmBatteryServiceUUID])
            let characteristics = try await setup.actor.discoverCharacteristics(peripheralID: setup.id, serviceID: cbmBatteryServiceUUID, characteristicIDs: nil)
            #expect(characteristics.contains { $0.id == cbmBatteryLevelUUID })
            #expect(characteristics.first?.properties.contains(.notify) == true)
        }
    }

    @Suite @MainActor
    struct CentralReadWriteNotifyTests {
        @Test func readValueReturnsSpecDelegateValue() async throws {
            let setup = await makeMockRadio()
            try await connectAndDiscover(setup)
            let value = try await setup.actor.readValue(peripheralID: setup.id, characteristicID: cbmBatteryLevelUUID)
            #expect(value == Data([0x64]))
        }

        @Test func writeValueDeliversDataToSpecDelegate() async throws {
            let setup = await makeMockRadio()
            try await connectAndDiscover(setup)
            try await setup.actor.writeValue(data: Data([0x01]), peripheralID: setup.id, characteristicID: cbmBatteryLevelUUID, type: .withResponse)
            #expect(setup.specDelegate.writes.count == 1)
            #expect(setup.specDelegate.writes.first?.data == Data([0x01]))
        }

        @Test func notificationsStreamYieldsSimulatedUpdate() async throws {
            let setup = await makeMockRadio()
            try await connectAndDiscover(setup)
            try await setup.actor.setNotify(enabled: true, peripheralID: setup.id, characteristicID: cbmBatteryLevelUUID)
            let stream = setup.actor.notifications(peripheralID: setup.id, characteristicID: cbmBatteryLevelUUID)
            var iter = stream.makeAsyncIterator()
            try? await Task.sleep(nanoseconds: 50_000_000)
            setup.spec.simulateValueUpdate(Data([0xAA]), for: setup.characteristic)
            let next = try await iter.next()
            #expect(next == Data([0xAA]))
        }
    }
}
