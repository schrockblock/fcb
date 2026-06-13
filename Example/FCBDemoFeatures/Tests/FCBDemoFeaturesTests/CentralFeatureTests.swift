import ComposableArchitecture
@preconcurrency import CoreBluetooth
import FCBComposable
import Foundation
import Testing
@testable import FCBDemoFeatures

@MainActor
struct CentralFeatureTests {
    private static let fixtureID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
    private static func fixture(rssi: Int = -55, name: String? = "Sensor") -> DiscoveredPeripheral {
        DiscoveredPeripheral(
            peripheral: Peripheral(id: fixtureID, name: name, state: .disconnected),
            advertisementData: AdvertisementData(localName: name),
            rssi: rssi
        )
    }

    @Test func onAppearSubscribesToStateStream() async {
        let store = TestStore(initialState: CentralFeature.State()) {
            CentralFeature()
        } withDependencies: {
            $0.bluetoothCentralClient.state = {
                AsyncStream { cont in
                    cont.yield(.poweredOn)
                    cont.finish()
                }
            }
        }
        store.exhaustivity = .off
        await store.send(.onAppear)
        await store.receive(\.stateStreamUpdate) { $0.managerState = .poweredOn }
    }

    @Test func startScanRequiresPoweredOn() async {
        let store = TestStore(initialState: CentralFeature.State()) {
            CentralFeature()
        } withDependencies: {
            $0.bluetoothCentralClient.scan = { _, _ in .never }
            $0.bluetoothCentralClient.stopScan = { }
        }
        await store.send(.startScanTapped) {
            $0.scanError = "Bluetooth is not powered on."
        }
    }

    @Test func startScanYieldsDiscoveredPeripherals() async {
        let store = TestStore(
            initialState: CentralFeature.State(managerState: .poweredOn)
        ) {
            CentralFeature()
        } withDependencies: {
            $0.bluetoothCentralClient.scan = { _, _ in
                AsyncStream { cont in
                    cont.yield(Self.fixture())
                    cont.finish()
                }
            }
            $0.bluetoothCentralClient.stopScan = { }
        }
        await store.send(.startScanTapped) { $0.isScanning = true }
        await store.receive(\.scanEvent) {
            $0.discovered = [DiscoveredPeripheralRow(discovered: Self.fixture())]
        }
        await store.send(.stopScanTapped) { $0.isScanning = false }
    }

    @Test func scanDeduplicatesByPeripheralID() async {
        let store = TestStore(
            initialState: CentralFeature.State(
                managerState: .poweredOn,
                discovered: [DiscoveredPeripheralRow(discovered: Self.fixture(rssi: -80))]
            )
        ) {
            CentralFeature()
        }
        await store.send(.scanEvent(Self.fixture(rssi: -40))) {
            $0.discovered = [DiscoveredPeripheralRow(discovered: Self.fixture(rssi: -40))]
        }
        #expect(store.state.discovered.count == 1)
    }

    @Test func clearListEmptiesDiscovered() async {
        let store = TestStore(
            initialState: CentralFeature.State(
                discovered: [DiscoveredPeripheralRow(discovered: Self.fixture())]
            )
        ) {
            CentralFeature()
        }
        await store.send(.clearListTapped) { $0.discovered = [] }
    }
}
