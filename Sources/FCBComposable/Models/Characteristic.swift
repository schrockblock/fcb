@preconcurrency import CoreBluetooth
import Foundation

public struct Characteristic: Sendable, Identifiable, Hashable {
    public let id: CBUUID
    public let serviceID: CBUUID
    public let peripheralID: UUID
    public let properties: CBCharacteristicProperties
    public let value: Data?
    public let isNotifying: Bool

    public init(id: CBUUID, serviceID: CBUUID, peripheralID: UUID,
                properties: CBCharacteristicProperties, value: Data?, isNotifying: Bool) {
        self.id = id
        self.serviceID = serviceID
        self.peripheralID = peripheralID
        self.properties = properties
        self.value = value
        self.isNotifying = isNotifying
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(serviceID)
        hasher.combine(peripheralID)
        hasher.combine(properties.rawValue)
        hasher.combine(value)
        hasher.combine(isNotifying)
    }

    public static func == (lhs: Characteristic, rhs: Characteristic) -> Bool {
        lhs.id == rhs.id &&
        lhs.serviceID == rhs.serviceID &&
        lhs.peripheralID == rhs.peripheralID &&
        lhs.properties == rhs.properties &&
        lhs.value == rhs.value &&
        lhs.isNotifying == rhs.isNotifying
    }
}
