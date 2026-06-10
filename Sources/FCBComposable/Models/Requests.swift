import Foundation

public struct ReadRequest: Sendable, Identifiable, Hashable {
    public let id: UUID
    public let central: Central
    public let characteristic: Characteristic
    public let offset: Int

    public init(id: UUID, central: Central, characteristic: Characteristic, offset: Int) {
        self.id = id
        self.central = central
        self.characteristic = characteristic
        self.offset = offset
    }
}

public struct WriteRequest: Sendable, Identifiable, Hashable {
    public let id: UUID
    public let central: Central
    public let characteristic: Characteristic
    public let offset: Int
    public let value: Data?

    public init(id: UUID, central: Central, characteristic: Characteristic, offset: Int, value: Data?) {
        self.id = id
        self.central = central
        self.characteristic = characteristic
        self.offset = offset
        self.value = value
    }
}
