import ComposableArchitecture
@preconcurrency import CoreBluetooth
import FCBComposable
import SwiftUI

public struct CentralView: View {
    @Perception.Bindable public var store: StoreOf<CentralFeature>

    public init(store: StoreOf<CentralFeature>) {
        self.store = store
    }

    public var body: some View {
        NavigationStack(path: $store.scope(state: \.path, action: \.path)) {
            VStack(spacing: 0) {
                banner
                controls
                List {
                    ForEach(sortedDiscovered) { row in
                        Button {
                            store.send(.peripheralTapped(row.id))
                        } label: {
                            rowView(row)
                        }
                    }
                }
                if let err = store.scanError {
                    Text(err).foregroundStyle(.red).padding(.horizontal)
                }
            }
            .navigationTitle("Central")
            .onAppear { store.send(.onAppear) }
        } destination: { detailStore in
            PeripheralDetailView(store: detailStore)
        }
    }

    private var banner: some View {
        Text("BLE: \(label(for: store.managerState))")
            .font(.caption)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(8)
            .background(.thinMaterial)
    }

    private var controls: some View {
        HStack {
            Button(store.isScanning ? "Stop Scan" : "Start Scan") {
                store.send(store.isScanning ? .stopScanTapped : .startScanTapped)
            }
            .disabled(!store.isScanning && store.managerState != .poweredOn)
            Spacer()
            Button("Clear", role: .destructive) {
                store.send(.clearListTapped)
            }
            .disabled(store.discovered.isEmpty)
        }
        .padding(.horizontal)
    }

    private var sortedDiscovered: [DiscoveredPeripheralRow] {
        store.discovered.elements.sorted { $0.discovered.rssi > $1.discovered.rssi }
    }

    @ViewBuilder
    private func rowView(_ row: DiscoveredPeripheralRow) -> some View {
        VStack(alignment: .leading) {
            Text(row.discovered.peripheral.name ?? "Unknown")
                .font(.body)
            HStack {
                Text(row.id.uuidString.prefix(8))
                    .font(.caption2.monospaced())
                Spacer()
                Text("\(row.discovered.rssi) dBm")
                    .font(.caption.monospaced())
            }
            .foregroundStyle(.secondary)
        }
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

#Preview {
    CentralView(
        store: Store(initialState: CentralFeature.State()) {
            CentralFeature()
        } withDependencies: {
            $0.previewBluetooth()
        }
    )
}
