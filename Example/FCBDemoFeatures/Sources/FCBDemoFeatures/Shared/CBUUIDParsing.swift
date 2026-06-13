@preconcurrency import CoreBluetooth
import Foundation

public enum CBUUIDParsing {
    public static func parse(_ input: String) -> CBUUID? {
        let trimmed = input.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }
        let isShort = trimmed.count == 4 && trimmed.allSatisfy { $0.isHexDigit }
        let isFull = trimmed.count == 36 && UUID(uuidString: trimmed) != nil
        guard isShort || isFull else { return nil }
        return CBUUID(string: trimmed)
    }

    public static func parseList(_ input: String) -> [CBUUID] {
        input
            .split(separator: ",")
            .compactMap { parse(String($0)) }
    }
}
