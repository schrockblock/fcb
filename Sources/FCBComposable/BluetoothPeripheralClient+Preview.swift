import ComposableArchitecture
@preconcurrency import CoreBluetooth
import Foundation

extension BluetoothPeripheralClient {
    public static let previewValue: BluetoothPeripheralClient = {
        let sampleServiceID = CBUUID(string: "180F")
        let sampleService = Service(id: sampleServiceID,
                                    peripheralID: UUID(),
                                    isPrimary: true)
        return BluetoothPeripheralClient(
            state: {
                AsyncStream { continuation in
                    continuation.yield(.poweredOn)
                    continuation.finish()
                }
            },
            authorization: { .allowedAlways },
            add: { _ in sampleService },
            remove: { _ in },
            removeAll: { },
            startAdvertising: { _ in },
            stopAdvertising: { },
            isAdvertising: { true },
            respond: { _, _ in },
            updateValue: { _, _, _ in },
            readRequests: { AsyncStream { $0.finish() } },
            writeRequests: { AsyncStream { $0.finish() } },
            subscriptions: { AsyncStream { $0.finish() } },
            events: {
                AsyncStream { continuation in
                    continuation.yield(.didStartAdvertising(error: nil))
                    continuation.finish()
                }
            }
        )
    }()
}
