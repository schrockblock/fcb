import Foundation

public struct Central: Sendable, Identifiable, Hashable {
    public let id: UUID
    public let maximumUpdateValueLength: Int

    public init(id: UUID, maximumUpdateValueLength: Int) {
        self.id = id
        self.maximumUpdateValueLength = maximumUpdateValueLength
    }
}
