@preconcurrency import CoreBluetooth
import Foundation

extension Service {
    init(_ cb: CBService) {
        self.init(id: cb.uuid, peripheralID: cb.peripheral?.identifier ?? UUID(), isPrimary: cb.isPrimary)
    }
}
