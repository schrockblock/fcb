import ComposableArchitecture
import FCBComposable
import SwiftUI

public struct AdvertisingView: View {
    @Perception.Bindable public var store: StoreOf<AdvertisingFeature>

    public init(store: StoreOf<AdvertisingFeature>) {
        self.store = store
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Advertising").font(.headline)
            TextField("Local Name", text: Binding(
                get: { store.localName },
                set: { store.send(.localNameChanged($0)) }))
                .textFieldStyle(.roundedBorder)
            TextField("Included Service UUIDs (comma-separated)", text: Binding(
                get: { store.includedServiceUUIDsText },
                set: { store.send(.includedUUIDsChanged($0)) }))
                #if os(iOS)
                .textInputAutocapitalization(.never)
                #endif
                .textFieldStyle(.roundedBorder)
            HStack {
                Button(store.isAdvertising ? "Stop" : "Start") {
                    store.send(store.isAdvertising ? .stopAdvertisingTapped : .startAdvertisingTapped)
                }
                Text(store.isAdvertising ? "Advertising" : "Stopped")
                    .foregroundStyle(.secondary)
            }
            if let err = store.lastError {
                Text(err).foregroundStyle(.red).font(.caption)
            }
        }
        .padding()
    }
}
