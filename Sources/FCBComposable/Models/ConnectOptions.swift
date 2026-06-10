import CoreBluetooth
import Foundation

public struct ConnectOptions: Sendable, Hashable {
    public let notifyOnConnection: Bool
    public let notifyOnDisconnection: Bool
    public let notifyOnNotification: Bool

    public init(notifyOnConnection: Bool = false,
                notifyOnDisconnection: Bool = false,
                notifyOnNotification: Bool = false) {
        self.notifyOnConnection = notifyOnConnection
        self.notifyOnDisconnection = notifyOnDisconnection
        self.notifyOnNotification = notifyOnNotification
    }

    public var dictionary: [String: Any] {
        [
            CBConnectPeripheralOptionNotifyOnConnectionKey: NSNumber(value: notifyOnConnection),
            CBConnectPeripheralOptionNotifyOnDisconnectionKey: NSNumber(value: notifyOnDisconnection),
            CBConnectPeripheralOptionNotifyOnNotificationKey: NSNumber(value: notifyOnNotification)
        ]
    }
}
