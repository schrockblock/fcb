import ComposableArchitecture
import FCBComposable
import Foundation

@Reducer
public struct AppFeature {
    public enum Tab: Equatable { case central, peripheral }

    @ObservableState
    public struct State: Equatable {
        public var tab: Tab
        public var central: CentralFeature.State
        public var peripheral: PeripheralFeature.State

        public init(
            tab: Tab = .central,
            central: CentralFeature.State = .init(),
            peripheral: PeripheralFeature.State = .init()
        ) {
            self.tab = tab
            self.central = central
            self.peripheral = peripheral
        }
    }

    public enum Action {
        case tabChanged(Tab)
        case central(CentralFeature.Action)
        case peripheral(PeripheralFeature.Action)
    }

    public init() {}

    public var body: some ReducerOf<Self> {
        Scope(state: \.central, action: \.central) { CentralFeature() }
        Scope(state: \.peripheral, action: \.peripheral) { PeripheralFeature() }
        Reduce { state, action in
            switch action {
            case .tabChanged(let tab):
                state.tab = tab
                return .none
            default:
                return .none
            }
        }
    }
}
