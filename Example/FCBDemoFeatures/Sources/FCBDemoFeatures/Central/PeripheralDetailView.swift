import ComposableArchitecture
@preconcurrency import CoreBluetooth
import FCBComposable
import SwiftUI

public struct PeripheralDetailView: View {
    @Perception.Bindable public var store: StoreOf<PeripheralDetailFeature>

    public init(store: StoreOf<PeripheralDetailFeature>) {
        self.store = store
    }

    public var body: some View {
        List {
            Section("Peripheral") {
                LabeledContent("Name", value: store.peripheral.name ?? "Unknown")
                LabeledContent("UUID", value: store.peripheral.id.uuidString)
                    .font(.caption.monospaced())
                LabeledContent("State", value: stateLabel)
                connectButtons
                if let err = store.connectError {
                    Text(err).foregroundStyle(.red)
                }
                if let err = store.operationError {
                    Text(err).foregroundStyle(.red)
                }
            }

            if store.connectionState == .connected {
                Section("Services") {
                    Button("Discover Services") {
                        store.send(.discoverServicesTapped)
                    }
                    ForEach(store.services) { row in
                        DisclosureGroup(row.id.uuidString) {
                            serviceCharacteristics(row.id)
                        }
                    }
                }
            }
        }
        .navigationTitle(store.peripheral.name ?? "Peripheral")
        .onAppear { store.send(.onAppear) }
    }

    @ViewBuilder private var connectButtons: some View {
        switch store.connectionState {
        case .disconnected:
            Button("Connect") { store.send(.connectTapped) }
        case .connecting:
            ProgressView("Connecting…")
        case .connected:
            Button("Disconnect", role: .destructive) { store.send(.disconnectTapped) }
        case .disconnecting:
            ProgressView("Disconnecting…")
        }
    }

    private var stateLabel: String {
        switch store.connectionState {
        case .disconnected: return "Disconnected"
        case .connecting: return "Connecting"
        case .connected: return "Connected"
        case .disconnecting: return "Disconnecting"
        }
    }

    @ViewBuilder
    private func serviceCharacteristics(_ serviceID: CBUUID) -> some View {
        Button("Discover Characteristics") {
            store.send(.discoverCharacteristicsTapped(serviceID: serviceID))
        }
        if let chars = store.characteristics[serviceID] {
            ForEach(chars) { row in
                characteristicView(row.characteristic)
            }
        }
    }

    @ViewBuilder
    private func characteristicView(_ c: Characteristic) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(c.id.uuidString).font(.caption.monospaced())
            HStack(spacing: 6) {
                if c.properties.contains(.read) { badge("R") }
                if c.properties.contains(.write) { badge("W") }
                if c.properties.contains(.writeWithoutResponse) { badge("Wn") }
                if c.properties.contains(.notify) { badge("N") }
                if c.properties.contains(.indicate) { badge("I") }
            }
            if let data = store.characteristicValues[c.id] {
                Text("Value: \(HexCoding.encode(data))").font(.caption.monospaced())
            }
            if c.properties.contains(.read) {
                Button("Read") {
                    store.send(.readTapped(characteristicID: c.id))
                }
            }
            if c.properties.contains(.write) || c.properties.contains(.writeWithoutResponse) {
                TextField("Hex to write", text: bindingFor(c.id))
                    #if os(iOS)
                    .textInputAutocapitalization(.never)
                    #endif
                HStack {
                    if c.properties.contains(.write) {
                        Button("Write w/ Response") {
                            store.send(.writeTapped(characteristicID: c.id, withResponse: true))
                        }
                    }
                    if c.properties.contains(.writeWithoutResponse) {
                        Button("Write w/o Response") {
                            store.send(.writeTapped(characteristicID: c.id, withResponse: false))
                        }
                    }
                }
            }
            if c.properties.contains(.notify) || c.properties.contains(.indicate) {
                Toggle("Notify",
                       isOn: Binding(
                            get: { store.notifyingCharacteristics.contains(c.id) },
                            set: { _ in store.send(.toggleNotifyTapped(characteristicID: c.id)) }))
            }
        }
        .padding(.vertical, 6)
    }

    private func badge(_ text: String) -> some View {
        Text(text)
            .font(.caption2.bold())
            .padding(.horizontal, 6).padding(.vertical, 2)
            .background(Color.accentColor.opacity(0.2))
            .clipShape(Capsule())
    }

    private func bindingFor(_ cid: CBUUID) -> Binding<String> {
        Binding(
            get: { store.pendingWriteText[cid] ?? "" },
            set: { store.send(.writeTextChanged(characteristicID: cid, $0)) }
        )
    }
}
