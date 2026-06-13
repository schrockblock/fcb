import ComposableArchitecture
@preconcurrency import CoreBluetooth
import FCBComposable
import Foundation

@Reducer
public struct CentralFeature {
    @ObservableState
    public struct State: Equatable {
        public var managerState: CBManagerState
        public var isScanning: Bool
        public var discovered: IdentifiedArrayOf<DiscoveredPeripheralRow>
        public var path: StackState<PeripheralDetailFeature.State>
        public var scanError: String?

        public init(
            managerState: CBManagerState = .unknown,
            isScanning: Bool = false,
            discovered: IdentifiedArrayOf<DiscoveredPeripheralRow> = [],
            path: StackState<PeripheralDetailFeature.State> = .init(),
            scanError: String? = nil
        ) {
            self.managerState = managerState
            self.isScanning = isScanning
            self.discovered = discovered
            self.path = path
            self.scanError = scanError
        }
    }

    public enum Action {
        case onAppear
        case stateStreamUpdate(CBManagerState)
        case startScanTapped
        case stopScanTapped
        case scanEvent(DiscoveredPeripheral)
        case peripheralTapped(UUID)
        case clearListTapped
        case path(StackActionOf<PeripheralDetailFeature>)
    }

    @Dependency(\.bluetoothCentralClient) var client

    enum CancelID: Hashable {
        case stateStream
        case scan
    }

    public init() {}

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                let stateStream = client.state
                return .run { send in
                    for await s in stateStream() {
                        await send(.stateStreamUpdate(s))
                    }
                }
                .cancellable(id: CancelID.stateStream, cancelInFlight: true)

            case .stateStreamUpdate(let s):
                state.managerState = s
                return .none

            case .startScanTapped:
                guard state.managerState == .poweredOn else {
                    state.scanError = "Bluetooth is not powered on."
                    return .none
                }
                state.isScanning = true
                state.scanError = nil
                let scan = client.scan
                return .run { send in
                    for await peripheral in scan(nil, nil) {
                        await send(.scanEvent(peripheral))
                    }
                }
                .cancellable(id: CancelID.scan, cancelInFlight: true)

            case .stopScanTapped:
                state.isScanning = false
                let stopScan = client.stopScan
                return .merge(
                    .run { _ in await stopScan() },
                    .cancel(id: CancelID.scan)
                )

            case .scanEvent(let discovered):
                state.discovered[id: discovered.peripheral.id] =
                    DiscoveredPeripheralRow(discovered: discovered)
                return .none

            case .peripheralTapped(let id):
                guard let row = state.discovered[id: id] else { return .none }
                state.path.append(
                    PeripheralDetailFeature.State(peripheral: row.discovered.peripheral)
                )
                return .none

            case .clearListTapped:
                state.discovered.removeAll()
                return .none

            case .path:
                return .none
            }
        }
        .forEach(\.path, action: \.path) {
            PeripheralDetailFeature()
        }
    }
}

public struct DiscoveredPeripheralRow: Equatable, Identifiable {
    public var id: UUID { discovered.peripheral.id }
    public var discovered: DiscoveredPeripheral

    public init(discovered: DiscoveredPeripheral) {
        self.discovered = discovered
    }
}
