import ComposableArchitecture
import SwiftUI

public struct AppView: View {
    @Perception.Bindable public var store: StoreOf<AppFeature>

    public init(store: StoreOf<AppFeature>) {
        self.store = store
    }

    public var body: some View {
        TabView(selection: Binding(
            get: { store.tab },
            set: { store.send(.tabChanged($0)) })) {
            CentralView(store: store.scope(state: \.central, action: \.central))
                .tabItem { Label("Central", systemImage: "antenna.radiowaves.left.and.right") }
                .tag(AppFeature.Tab.central)
            PeripheralView(store: store.scope(state: \.peripheral, action: \.peripheral))
                .tabItem { Label("Peripheral", systemImage: "dot.radiowaves.forward") }
                .tag(AppFeature.Tab.peripheral)
        }
    }
}
