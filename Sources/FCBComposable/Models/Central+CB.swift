@preconcurrency import CoreBluetooth
import Foundation

extension Central {
    init(_ cb: CBCentral) {
        self.init(id: cb.identifier, maximumUpdateValueLength: cb.maximumUpdateValueLength)
    }
}
