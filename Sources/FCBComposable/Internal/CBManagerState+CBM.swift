@preconcurrency import CoreBluetooth
import CoreBluetoothMock

extension CBManagerState {
    /// Bridges CBM's standalone `CBMManagerState` enum to the public
    /// `CBManagerState` used in `BluetoothCentralClient`'s API.
    init(_ state: CBMManagerState) {
        switch state {
        case .unknown: self = .unknown
        case .resetting: self = .resetting
        case .unsupported: self = .unsupported
        case .unauthorized: self = .unauthorized
        case .poweredOff: self = .poweredOff
        case .poweredOn: self = .poweredOn
        }
    }
}
