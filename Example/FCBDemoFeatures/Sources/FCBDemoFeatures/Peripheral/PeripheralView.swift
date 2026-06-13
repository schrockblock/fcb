import ComposableArchitecture
@preconcurrency import CoreBluetooth
import FCBComposable
import SwiftUI

public struct PeripheralView: View {
    @Perception.Bindable public var store: StoreOf<PeripheralFeature>

    public init(store: StoreOf<PeripheralFeature>) {
        self.store = store
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading) {
                Text("BLE: \(label(for: store.managerState))")
                    .font(.caption)
                    .padding(.horizontal)
                Divider()
                GATTBuilderView(store: store.scope(state: \.gattBuilder, action: \.gattBuilder))
                Divider()
                AdvertisingView(store: store.scope(state: \.advertising, action: \.advertising))
                Divider()
                RequestLogView(store: store.scope(state: \.requestLog, action: \.requestLog))
            }
        }
        .onAppear { store.send(.onAppear) }
        .disabled(store.managerState != .poweredOn)
    }

    private func label(for s: CBManagerState) -> String {
        switch s {
        case .poweredOn: return "Powered On"
        case .poweredOff: return "Powered Off"
        case .resetting: return "Resetting"
        case .unauthorized: return "Unauthorized"
        case .unsupported: return "Unsupported"
        case .unknown: return "Unknown"
        @unknown default: return "Unknown"
        }
    }
}
