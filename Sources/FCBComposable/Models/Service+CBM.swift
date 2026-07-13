import CoreBluetoothMock
import Foundation

extension Service {
    init(_ s: CBMService) {
        self.init(id: s.uuid, peripheralID: UUID(), isPrimary: s.isPrimary)
    }
}
