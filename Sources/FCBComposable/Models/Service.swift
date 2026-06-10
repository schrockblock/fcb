@preconcurrency import CoreBluetooth
import Foundation

public struct Service: Sendable, Identifiable, Hashable {
    public let id: CBUUID
    public let peripheralID: UUID
    public let isPrimary: Bool

    public init(id: CBUUID, peripheralID: UUID, isPrimary: Bool) {
        self.id = id
        self.peripheralID = peripheralID
        self.isPrimary = isPrimary
    }
}
