import Foundation

public struct DiscoveredPeripheral: Sendable, Hashable {
    public let peripheral: Peripheral
    public let advertisementData: AdvertisementData
    public let rssi: Int

    public init(peripheral: Peripheral, advertisementData: AdvertisementData, rssi: Int) {
        self.peripheral = peripheral
        self.advertisementData = advertisementData
        self.rssi = rssi
    }
}
