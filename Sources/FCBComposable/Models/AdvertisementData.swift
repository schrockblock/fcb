@preconcurrency import CoreBluetooth
import Foundation

public struct AdvertisementData: Sendable, Hashable {
    public let localName: String?
    public let serviceUUIDs: [CBUUID]
    public let manufacturerData: Data?
    public let txPowerLevel: Int?
    public let isConnectable: Bool?
    public let solicitedServiceUUIDs: [CBUUID]
    public let overflowServiceUUIDs: [CBUUID]
    public let serviceData: [CBUUID: Data]

    public init(
        localName: String? = nil,
        serviceUUIDs: [CBUUID] = [],
        manufacturerData: Data? = nil,
        txPowerLevel: Int? = nil,
        isConnectable: Bool? = nil,
        solicitedServiceUUIDs: [CBUUID] = [],
        overflowServiceUUIDs: [CBUUID] = [],
        serviceData: [CBUUID: Data] = [:]
    ) {
        self.localName = localName
        self.serviceUUIDs = serviceUUIDs
        self.manufacturerData = manufacturerData
        self.txPowerLevel = txPowerLevel
        self.isConnectable = isConnectable
        self.solicitedServiceUUIDs = solicitedServiceUUIDs
        self.overflowServiceUUIDs = overflowServiceUUIDs
        self.serviceData = serviceData
    }

    public init(dictionary: [String: Any]) {
        self.init(
            localName: dictionary[CBAdvertisementDataLocalNameKey] as? String,
            serviceUUIDs: dictionary[CBAdvertisementDataServiceUUIDsKey] as? [CBUUID] ?? [],
            manufacturerData: dictionary[CBAdvertisementDataManufacturerDataKey] as? Data,
            txPowerLevel: (dictionary[CBAdvertisementDataTxPowerLevelKey] as? NSNumber)?.intValue,
            isConnectable: (dictionary[CBAdvertisementDataIsConnectable] as? NSNumber)?.boolValue,
            solicitedServiceUUIDs: dictionary[CBAdvertisementDataSolicitedServiceUUIDsKey] as? [CBUUID] ?? [],
            overflowServiceUUIDs: dictionary[CBAdvertisementDataOverflowServiceUUIDsKey] as? [CBUUID] ?? [],
            serviceData: dictionary[CBAdvertisementDataServiceDataKey] as? [CBUUID: Data] ?? [:]
        )
    }
}
