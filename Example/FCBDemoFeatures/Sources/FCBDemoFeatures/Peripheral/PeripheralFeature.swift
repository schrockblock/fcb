import ComposableArchitecture
@preconcurrency import CoreBluetooth
import FCBComposable
import Foundation

@Reducer
public struct PeripheralFeature {
    @ObservableState
    public struct State: Equatable {
        public var gattBuilder: GATTBuilderFeature.State
        public var advertising: AdvertisingFeature.State
        public var requestLog: RequestLogFeature.State
        public var managerState: CBManagerState

        public init(
            gattBuilder: GATTBuilderFeature.State = .init(),
            advertising: AdvertisingFeature.State = .init(),
            requestLog: RequestLogFeature.State = .init(),
            managerState: CBManagerState = .unknown
        ) {
            self.gattBuilder = gattBuilder
            self.advertising = advertising
            self.requestLog = requestLog
            self.managerState = managerState
        }
    }

    public enum Action {
        case onAppear
        case stateStreamUpdate(CBManagerState)
        case gattBuilder(GATTBuilderFeature.Action)
        case advertising(AdvertisingFeature.Action)
        case requestLog(RequestLogFeature.Action)
    }

    @Dependency(\.bluetoothPeripheralClient) var client

    enum CancelID: Hashable { case stateStream }

    public init() {}

    public var body: some ReducerOf<Self> {
        Scope(state: \.gattBuilder, action: \.gattBuilder) { GATTBuilderFeature() }
        Scope(state: \.advertising, action: \.advertising) { AdvertisingFeature() }
        Scope(state: \.requestLog, action: \.requestLog) { RequestLogFeature() }
        Reduce { state, action in
            switch action {
            case .onAppear:
                let state = client.state
                return .run { send in
                    for await s in state() {
                        await send(.stateStreamUpdate(s))
                    }
                }
                .cancellable(id: CancelID.stateStream, cancelInFlight: true)
            case .stateStreamUpdate(let s):
                state.managerState = s
                return .none
            default:
                return .none
            }
        }
    }
}
