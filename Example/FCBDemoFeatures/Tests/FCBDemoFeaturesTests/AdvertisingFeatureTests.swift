import ComposableArchitecture
@preconcurrency import CoreBluetooth
import FCBComposable
import Foundation
import Testing
@testable import FCBDemoFeatures

@MainActor
struct AdvertisingFeatureTests {
    @Test func startAdvertisingSuccessSetsFlag() async {
        let store = TestStore(
            initialState: AdvertisingFeature.State(localName: "Hi")
        ) {
            AdvertisingFeature()
        } withDependencies: {
            $0.bluetoothPeripheralClient.startAdvertising = { _ in }
        }
        store.exhaustivity = .off
        await store.send(.startAdvertisingTapped)
        await store.receive(\.advertisingStarted) { $0.isAdvertising = true }
    }

    @Test func startAdvertisingFailureSetsError() async {
        let store = TestStore(initialState: AdvertisingFeature.State()) {
            AdvertisingFeature()
        } withDependencies: {
            $0.bluetoothPeripheralClient.startAdvertising = { _ in throw BluetoothError.poweredOff }
        }
        store.exhaustivity = .off
        await store.send(.startAdvertisingTapped)
        await store.receive(\.advertisingFailed) { $0.lastError = "poweredOff" }
    }

    @Test func stopAdvertisingClearsFlag() async {
        let store = TestStore(
            initialState: AdvertisingFeature.State(isAdvertising: true)
        ) {
            AdvertisingFeature()
        } withDependencies: {
            $0.bluetoothPeripheralClient.stopAdvertising = { }
        }
        store.exhaustivity = .off
        await store.send(.stopAdvertisingTapped)
        await store.receive(\.stopAdvertisingCompleted) { $0.isAdvertising = false }
    }

    @Test func localNameChangedUpdatesState() async {
        let store = TestStore(initialState: AdvertisingFeature.State()) {
            AdvertisingFeature()
        }
        await store.send(.localNameChanged("MyDevice")) { $0.localName = "MyDevice" }
    }
}
