import ComposableArchitecture
@preconcurrency import CoreBluetooth
import FCBComposable
import Foundation
import Testing
@testable import FCBDemoFeatures

@MainActor
struct GATTBuilderFeatureTests {
    @Test func addServiceWithValidUUIDAppends() async {
        let store = TestStore(
            initialState: GATTBuilderFeature.State(newServiceUUIDInput: "180F")
        ) {
            GATTBuilderFeature()
        }
        await store.send(.addServiceTapped) {
            $0.services = [DraftService(id: CBUUID(string: "180F"), isPrimary: true, characteristics: [])]
            $0.newServiceUUIDInput = ""
        }
    }

    @Test func addServiceWithInvalidUUIDSetsError() async {
        let store = TestStore(
            initialState: GATTBuilderFeature.State(newServiceUUIDInput: "nope")
        ) {
            GATTBuilderFeature()
        }
        await store.send(.addServiceTapped) {
            $0.publishError = "Invalid UUID"
        }
    }

    @Test func togglePropertyAddsOrRemovesBit() async {
        let serviceUUID = CBUUID(string: "180F")
        let charUUID = CBUUID(string: "2A19")
        let store = TestStore(
            initialState: GATTBuilderFeature.State(
                services: [DraftService(id: serviceUUID, isPrimary: true,
                                         characteristics: [DraftCharacteristic(
                                            id: charUUID,
                                            properties: [.read],
                                            permissions: [.readable],
                                            initialValueText: "")])]
            )
        ) {
            GATTBuilderFeature()
        }
        await store.send(.togglePropertyTapped(serviceID: serviceUUID, characteristicID: charUUID, .write)) {
            $0.services[id: serviceUUID]!.characteristics[id: charUUID]!.properties = [.read, .write]
        }
        await store.send(.togglePropertyTapped(serviceID: serviceUUID, characteristicID: charUUID, .write)) {
            $0.services[id: serviceUUID]!.characteristics[id: charUUID]!.properties = [.read]
        }
    }

    @Test func publishSuccessMarksPublishedID() async {
        let serviceUUID = CBUUID(string: "180F")
        let published = Service(id: serviceUUID, peripheralID: UUID(), isPrimary: true)
        let store = TestStore(
            initialState: GATTBuilderFeature.State(
                services: [DraftService(id: serviceUUID, isPrimary: true, characteristics: [])]
            )
        ) {
            GATTBuilderFeature()
        } withDependencies: {
            $0.bluetoothPeripheralClient.add = { _ in published }
        }
        store.exhaustivity = .off
        await store.send(.publishServiceTapped(serviceID: serviceUUID))
        await store.receive(\.servicePublished) {
            $0.publishedServiceIDs = [serviceUUID]
        }
    }

    @Test func publishFailureSurfacesError() async {
        let serviceUUID = CBUUID(string: "180F")
        let store = TestStore(
            initialState: GATTBuilderFeature.State(
                services: [DraftService(id: serviceUUID, isPrimary: true, characteristics: [])]
            )
        ) {
            GATTBuilderFeature()
        } withDependencies: {
            $0.bluetoothPeripheralClient.add = { _ in throw BluetoothError.poweredOff }
        }
        store.exhaustivity = .off
        await store.send(.publishServiceTapped(serviceID: serviceUUID))
        await store.receive(\.publishFailed) {
            $0.publishError = "poweredOff"
        }
    }
}
