@preconcurrency import CoreBluetooth
import Foundation

public struct MutableCharacteristic: Sendable, Hashable {
    public let id: CBUUID
    public let properties: CBCharacteristicProperties
    public let permissions: CBAttributePermissions
    public let value: Data?

    public init(id: CBUUID, properties: CBCharacteristicProperties, permissions: CBAttributePermissions, value: Data?) {
        self.id = id
        self.properties = properties
        self.permissions = permissions
        self.value = value
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(properties.rawValue)
        hasher.combine(permissions.rawValue)
        hasher.combine(value)
    }

    public static func == (lhs: MutableCharacteristic, rhs: MutableCharacteristic) -> Bool {
        lhs.id == rhs.id &&
        lhs.properties == rhs.properties &&
        lhs.permissions == rhs.permissions &&
        lhs.value == rhs.value
    }
}

public struct MutableService: Sendable, Hashable {
    public let id: CBUUID
    public let isPrimary: Bool
    public let characteristics: [MutableCharacteristic]

    public init(id: CBUUID, isPrimary: Bool, characteristics: [MutableCharacteristic]) {
        self.id = id
        self.isPrimary = isPrimary
        self.characteristics = characteristics
    }
}
