import ComposableArchitecture
@preconcurrency import CoreBluetooth
import FCBComposable
import SwiftUI

public struct RequestLogView: View {
    @Perception.Bindable public var store: StoreOf<RequestLogFeature>

    public init(store: StoreOf<RequestLogFeature>) {
        self.store = store
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Request Log").font(.headline)
            Picker("Default Response", selection: Binding(
                get: { store.defaultResultCode },
                set: { store.send(.defaultCodeChanged($0)) })) {
                Text("Success").tag(CBATTError.Code.success)
                Text("Read Not Permitted").tag(CBATTError.Code.readNotPermitted)
                Text("Write Not Permitted").tag(CBATTError.Code.writeNotPermitted)
                Text("Invalid Handle").tag(CBATTError.Code.invalidHandle)
                Text("Request Not Supported").tag(CBATTError.Code.requestNotSupported)
                Text("Attribute Not Found").tag(CBATTError.Code.attributeNotFound)
            }
            Text("Read Requests (\(store.readRequests.count))").font(.subheadline)
            ForEach(store.readRequests) { req in
                HStack {
                    VStack(alignment: .leading) {
                        Text(req.characteristic.id.uuidString).font(.caption.monospaced())
                        Text("offset \(req.offset)").font(.caption2)
                    }
                    Spacer()
                    Button("Respond") {
                        store.send(.respondReadTapped(requestID: req.id, code: store.defaultResultCode))
                    }
                }
            }
            Text("Write Requests (\(store.writeRequests.count))").font(.subheadline)
            ForEach(store.writeRequests) { logged in
                HStack {
                    VStack(alignment: .leading) {
                        Text(logged.request.characteristic.id.uuidString).font(.caption.monospaced())
                        Text("hex \(HexCoding.encode(logged.request.value ?? Data()))").font(.caption2)
                    }
                    Spacer()
                    Button("Respond") {
                        store.send(.respondWriteTapped(requestID: logged.id, code: store.defaultResultCode))
                    }
                }
            }
            Text("Subscriptions (last 10)").font(.subheadline)
            ForEach(store.subscriptions) { sub in
                Text(label(for: sub)).font(.caption)
            }
            Button("Clear Log", role: .destructive) {
                store.send(.clearLogTapped)
            }
        }
        .padding()
        .onAppear { store.send(.onAppear) }
    }

    private func label(for s: LoggedSubscription) -> String {
        switch s.event {
        case .subscribed(let c, let ch):
            return "subscribed \(c.id.uuidString.prefix(8)) → \(ch.id.uuidString)"
        case .unsubscribed(let c, let ch):
            return "unsubscribed \(c.id.uuidString.prefix(8)) → \(ch.id.uuidString)"
        }
    }
}
