@preconcurrency import CoreBluetooth
import Foundation

public enum BluetoothError: Error, Sendable, Equatable {
    case unauthorized(CBManagerAuthorization)
    case poweredOff
    case unsupported
    case unknownPeripheral(UUID)
    case unknownService(CBUUID, peripheralID: UUID)
    case unknownCharacteristic(CBUUID, serviceID: CBUUID)
    case connectionFailed(peripheralID: UUID, underlying: NSError?)
    case disconnected(peripheralID: UUID, underlying: NSError?)
    case att(CBATTError.Code)
    case operationCancelled
    /// L2CAP is unavailable on this transport — thrown instead of crashing when
    /// a CoreBluetoothMock-backed (mocked) central is asked to open a channel
    /// (CBM's openL2CAPChannel is an unimplemented fatalError).
    case l2capNotSupported
    case underlying(NSError)
}

extension BluetoothError {
    public init(_ error: any Error) {
        let nsError = error as NSError
        switch nsError.domain {
        case CBErrorDomain:
            if let code = CBError.Code(rawValue: nsError.code), code == .operationCancelled {
                self = .operationCancelled
            } else {
                self = .underlying(nsError)
            }
        case CBATTErrorDomain:
            if let code = CBATTError.Code(rawValue: nsError.code) {
                self = .att(code)
            } else {
                self = .underlying(nsError)
            }
        default:
            self = .underlying(nsError)
        }
    }
}
