import CoreBluetoothMock
import Foundation

extension Service {
    /// `peripheralID` is explicit: the caller always knows it, and CBM's
    /// `CBMService.peripheral` back-pointer on standalone mocks is an
    /// internal placeholder whose accessors trap — never traverse it.
    init(_ s: CBMService, peripheralID: UUID) {
        self.init(id: s.uuid, peripheralID: peripheralID, isPrimary: s.isPrimary)
    }
}
