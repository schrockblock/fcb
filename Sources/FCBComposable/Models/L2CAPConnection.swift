import Foundation

/// A live L2CAP connection. Not a model — a capability handle (carries
/// closures), so it is Identifiable but deliberately not Hashable/Equatable.
/// `incoming()` is single-consumer: the first call returns the live stream,
/// later calls return an already-finished stream. `close()` is silent
/// teardown — the only observable signal is `incoming` finishing.
public struct L2CAPConnection: Sendable, Identifiable {
    public let id: UUID
    public let peerID: UUID
    public let psm: UInt16
    public var incoming: @Sendable () -> AsyncStream<Data>
    public var send: @Sendable (Data) async throws -> Void
    public var close: @Sendable () async -> Void

    public init(
        id: UUID,
        peerID: UUID,
        psm: UInt16,
        incoming: @escaping @Sendable () -> AsyncStream<Data>,
        send: @escaping @Sendable (Data) async throws -> Void,
        close: @escaping @Sendable () async -> Void
    ) {
        self.id = id
        self.peerID = peerID
        self.psm = psm
        self.incoming = incoming
        self.send = send
        self.close = close
    }
}

extension L2CAPConnection {
    /// Wraps a pump into a connection handle. Opens the pump.
    static func make(pump: L2CAPChannelPump, peerID: UUID, psm: UInt16) -> L2CAPConnection {
        pump.open()
        return L2CAPConnection(
            id: UUID(),
            peerID: peerID,
            psm: psm,
            incoming: { pump.incomingStream() },
            send: { data in try pump.send(data) },
            close: { pump.close() }
        )
    }
}
