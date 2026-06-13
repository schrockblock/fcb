import ComposableArchitecture
@preconcurrency import CoreBluetooth
import FCBComposable
import SwiftUI

public struct GATTBuilderView: View {
    @Perception.Bindable public var store: StoreOf<GATTBuilderFeature>

    public init(store: StoreOf<GATTBuilderFeature>) {
        self.store = store
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("GATT Services").font(.headline)
            uuidEntry
            if let err = store.publishError {
                Text(err).foregroundStyle(.red).font(.caption)
            }
            ForEach(store.services) { draft in
                serviceCard(draft)
            }
            Button("Remove All Published", role: .destructive) {
                store.send(.removeAllPublishedTapped)
            }
            .disabled(store.publishedServiceIDs.isEmpty)
        }
        .padding()
    }

    @ViewBuilder
    private var uuidEntry: some View {
        HStack {
            TextField("Service UUID (e.g. 180F)", text: Binding(
                get: { store.newServiceUUIDInput },
                set: { store.send(.newServiceUUIDChanged($0)) }))
                #if os(iOS)
                .textInputAutocapitalization(.never)
                #endif
                .textFieldStyle(.roundedBorder)
            Button("Add Service") { store.send(.addServiceTapped) }
        }
    }

    @ViewBuilder
    private func serviceCard(_ draft: DraftService) -> some View {
        let isPublished = store.publishedServiceIDs.contains(draft.id)
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(draft.id.uuidString).font(.caption.monospaced())
                Spacer()
                Button(role: .destructive) {
                    store.send(.removeServiceTapped(serviceID: draft.id))
                } label: { Image(systemName: "trash") }
            }
            Toggle("Primary",
                   isOn: Binding(
                        get: { draft.isPrimary },
                        set: { store.send(.isPrimaryToggled(serviceID: draft.id, $0)) }))
                .disabled(isPublished)
            ForEach(draft.characteristics) { char in
                charView(serviceID: draft.id, char: char, disabled: isPublished)
            }
            Button("Add Characteristic") {
                store.send(.addCharacteristicTapped(serviceID: draft.id))
            }
            .disabled(isPublished)
            Button(isPublished ? "Published ✓" : "Publish") {
                store.send(.publishServiceTapped(serviceID: draft.id))
            }
            .disabled(isPublished)
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    @ViewBuilder
    private func charView(serviceID: CBUUID, char: DraftCharacteristic, disabled: Bool) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(char.id.uuidString).font(.caption2.monospaced())
            HStack {
                propCheckbox(label: "R", value: .read, char: char, serviceID: serviceID)
                propCheckbox(label: "W", value: .write, char: char, serviceID: serviceID)
                propCheckbox(label: "Wn", value: .writeWithoutResponse, char: char, serviceID: serviceID)
                propCheckbox(label: "N", value: .notify, char: char, serviceID: serviceID)
                propCheckbox(label: "I", value: .indicate, char: char, serviceID: serviceID)
            }
            HStack {
                permCheckbox(label: "Readable", value: .readable, char: char, serviceID: serviceID)
                permCheckbox(label: "Writeable", value: .writeable, char: char, serviceID: serviceID)
            }
            initialValueField(serviceID: serviceID, char: char)
            Button(role: .destructive) {
                store.send(.removeCharacteristicTapped(serviceID: serviceID, characteristicID: char.id))
            } label: { Image(systemName: "minus.circle") }
        }
        .padding(.vertical, 4)
        .disabled(disabled)
    }

    @ViewBuilder
    private func initialValueField(serviceID: CBUUID, char: DraftCharacteristic) -> some View {
        let binding = Binding(
            get: { char.initialValueText },
            set: { store.send(.initialValueChanged(serviceID: serviceID, characteristicID: char.id, $0)) }
        )
        #if os(iOS)
        TextField("Initial value (hex)", text: binding)
            .textFieldStyle(.roundedBorder)
            .textInputAutocapitalization(.never)
        #else
        TextField("Initial value (hex)", text: binding)
            .textFieldStyle(.roundedBorder)
        #endif
    }

    private func propCheckbox(label: String, value: CBCharacteristicProperties, char: DraftCharacteristic, serviceID: CBUUID) -> some View {
        Toggle(label, isOn: Binding(
            get: { char.properties.contains(value) },
            set: { _ in store.send(.togglePropertyTapped(serviceID: serviceID, characteristicID: char.id, value)) }))
            .toggleStyle(.button)
    }

    private func permCheckbox(label: String, value: CBAttributePermissions, char: DraftCharacteristic, serviceID: CBUUID) -> some View {
        Toggle(label, isOn: Binding(
            get: { char.permissions.contains(value) },
            set: { _ in store.send(.togglePermissionTapped(serviceID: serviceID, characteristicID: char.id, value)) }))
            .toggleStyle(.button)
    }
}
