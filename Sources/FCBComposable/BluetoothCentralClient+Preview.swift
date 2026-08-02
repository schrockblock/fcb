import ComposableArchitecture
@preconcurrency import CoreBluetooth
import Foundation

extension BluetoothCentralClient {
    public static let previewValue: BluetoothCentralClient = {
        let sampleID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
        let sample = Peripheral(id: sampleID, name: "Preview Device", state: .connected)
        let discovered = DiscoveredPeripheral(
            peripheral: sample,
            advertisementData: AdvertisementData(localName: "Preview Device", isConnectable: true),
            rssi: -55
        )
        return BluetoothCentralClient(
            state: { AsyncStream { continuation in
                continuation.yield(.poweredOn)
                continuation.finish()
            } },
            authorization: { .allowedAlways },
            scan: { _, _ in AsyncStream { continuation in
                continuation.yield(discovered)
                continuation.finish()
            } },
            stopScan: { },
            connect: { _, _ in sample },
            disconnect: { _ in },
            retrievePeripherals: { _ in [sample] },
            retrieveConnected: { _ in [sample] },
            discoverServices: { _, _ in [] },
            discoverCharacteristics: { _, _, _ in [] },
            readValue: { _, _ in Data() },
            writeValue: { _, _, _, _ in },
            setNotify: { _, _, _ in },
            maximumWriteValueLength: { _, _ in 512 },
            notifications: { _, _ in AsyncThrowingStream { continuation in
                continuation.finish()
            } },
            openL2CAPChannel: { _, _ in throw BluetoothError.l2capNotSupported },
            events: { AsyncStream { continuation in
                continuation.yield(.didConnect(sample))
                continuation.finish()
            } }
        )
    }()
}
