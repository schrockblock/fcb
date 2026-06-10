import Foundation

public struct RestorationState: Sendable, Hashable {
    public let peripherals: [Peripheral]
    public let scanServiceUUIDs: [String]
    public let scanOptions: ScanOptions?

    public init(peripherals: [Peripheral] = [], scanServiceUUIDs: [String] = [], scanOptions: ScanOptions? = nil) {
        self.peripherals = peripherals
        self.scanServiceUUIDs = scanServiceUUIDs
        self.scanOptions = scanOptions
    }
}
