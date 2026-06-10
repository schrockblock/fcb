@preconcurrency import CoreBluetooth
import Foundation

public struct ScanOptions: Sendable, Hashable {
    public let allowDuplicates: Bool
    public let solicitedServiceUUIDs: [CBUUID]?

    public init(allowDuplicates: Bool = false, solicitedServiceUUIDs: [CBUUID]? = nil) {
        self.allowDuplicates = allowDuplicates
        self.solicitedServiceUUIDs = solicitedServiceUUIDs
    }

    public var dictionary: [String: Any] {
        var d: [String: Any] = [
            CBCentralManagerScanOptionAllowDuplicatesKey: NSNumber(value: allowDuplicates)
        ]
        if let solicitedServiceUUIDs {
            d[CBCentralManagerScanOptionSolicitedServiceUUIDsKey] = solicitedServiceUUIDs
        }
        return d
    }
}
