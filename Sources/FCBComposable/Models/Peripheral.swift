import Foundation

public enum ConnectionState: Sendable, Hashable {
    case disconnected
    case connecting
    case connected
    case disconnecting
}

public struct Peripheral: Sendable, Identifiable, Hashable {
    public let id: UUID
    public let name: String?
    public let state: ConnectionState

    public init(id: UUID, name: String?, state: ConnectionState) {
        self.id = id
        self.name = name
        self.state = state
    }
}
