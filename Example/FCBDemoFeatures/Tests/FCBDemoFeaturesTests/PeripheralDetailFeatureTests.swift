import ComposableArchitecture
@preconcurrency import CoreBluetooth
import FCBComposable
import Foundation
import Testing
@testable import FCBDemoFeatures

@MainActor
struct PeripheralDetailFeatureTests {
    private static let pid = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
    private static let serviceID = CBUUID(string: "180F")
    private static let charID = CBUUID(string: "2A19")

    private static func sampleService() -> Service {
        Service(id: serviceID, peripheralID: pid, isPrimary: true)
    }
    private static func sampleCharacteristic(properties: CBCharacteristicProperties = [.read, .write, .notify]) -> Characteristic {
        Characteristic(id: charID, serviceID: serviceID, peripheralID: pid,
                       properties: properties, value: nil, isNotifying: false)
    }
    private static func samplePeripheral() -> Peripheral {
        Peripheral(id: pid, name: "Sensor", state: .disconnected)
    }

    @Test func connectSuccessPathTransitionsToConnected() async {
        let connected = Peripheral(id: Self.pid, name: "Sensor", state: .connected)
        let store = TestStore(
            initialState: PeripheralDetailFeature.State(peripheral: Self.samplePeripheral())
        ) {
            PeripheralDetailFeature()
        } withDependencies: {
            $0.bluetoothCentralClient.connect = { _, _ in connected }
            $0.bluetoothCentralClient.events = { .never }
        }
        store.exhaustivity = .off
        await store.send(.connectTapped) { $0.connectionState = .connecting }
        await store.receive(\.connected) { $0.connectionState = .connected }
    }

    @Test func connectFailureSurfacesError() async {
        let pid = Self.pid
        let store = TestStore(
            initialState: PeripheralDetailFeature.State(peripheral: Self.samplePeripheral())
        ) {
            PeripheralDetailFeature()
        } withDependencies: {
            $0.bluetoothCentralClient.connect = { _, _ in
                throw BluetoothError.connectionFailed(peripheralID: pid, underlying: nil)
            }
            $0.bluetoothCentralClient.events = { .never }
        }
        store.exhaustivity = .off
        await store.send(.connectTapped) { $0.connectionState = .connecting }
        await store.receive(\.connectFailed) {
            $0.connectError = "connectionFailed(peripheralID: \(pid), underlying: nil)"
            $0.connectionState = .disconnected
        }
    }

    @Test func discoverServicesPopulatesList() async {
        let service = Self.sampleService()
        let store = TestStore(
            initialState: PeripheralDetailFeature.State(
                peripheral: Self.samplePeripheral(),
                connectionState: .connected
            )
        ) {
            PeripheralDetailFeature()
        } withDependencies: {
            $0.bluetoothCentralClient.discoverServices = { _, _ in [service] }
            $0.bluetoothCentralClient.events = { .never }
        }
        store.exhaustivity = .off
        await store.send(.discoverServicesTapped)
        await store.receive(\.servicesDiscovered) {
            $0.services = [ServiceRow(service)]
        }
    }

    @Test func readValueSetsCharacteristicValue() async {
        let store = TestStore(
            initialState: PeripheralDetailFeature.State(
                peripheral: Self.samplePeripheral(),
                connectionState: .connected
            )
        ) {
            PeripheralDetailFeature()
        } withDependencies: {
            $0.bluetoothCentralClient.readValue = { _, _ in Data([0x42]) }
            $0.bluetoothCentralClient.events = { .never }
        }
        store.exhaustivity = .off
        await store.send(.readTapped(characteristicID: Self.charID))
        await store.receive(\.valueRead) {
            $0.characteristicValues[Self.charID] = Data([0x42])
        }
    }

    @Test func writeWithInvalidHexSetsError() async {
        let store = TestStore(
            initialState: PeripheralDetailFeature.State(
                peripheral: Self.samplePeripheral(),
                connectionState: .connected,
                pendingWriteText: [Self.charID: "NOT_HEX"]
            )
        ) {
            PeripheralDetailFeature()
        } withDependencies: {
            $0.bluetoothCentralClient.events = { .never }
            $0.bluetoothCentralClient.writeValue = { _, _, _, _ in
                Issue.record("writeValue should not be called for invalid hex")
            }
        }
        await store.send(.writeTapped(characteristicID: Self.charID, withResponse: true)) {
            $0.operationError = "Invalid hex"
        }
    }

    @Test func disconnectClearsState() async {
        let store = TestStore(
            initialState: PeripheralDetailFeature.State(
                peripheral: Self.samplePeripheral(),
                connectionState: .connected,
                services: [ServiceRow(Self.sampleService())],
                characteristics: [Self.serviceID: [CharacteristicRow(Self.sampleCharacteristic())]],
                characteristicValues: [Self.charID: Data([0xAB])],
                notifyingCharacteristics: [Self.charID]
            )
        ) {
            PeripheralDetailFeature()
        } withDependencies: {
            $0.bluetoothCentralClient.disconnect = { _ in }
            $0.bluetoothCentralClient.events = { .never }
        }
        store.exhaustivity = .off
        await store.send(.disconnectTapped)
        await store.receive(\.disconnected) {
            $0.connectionState = .disconnected
            $0.services = []
            $0.characteristics = [:]
            $0.characteristicValues = [:]
            $0.notifyingCharacteristics = []
        }
    }
}
