import Foundation

public enum HexCoding {
    public static func decode(_ input: String) -> Data? {
        let cleaned = input
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "0x", with: "", options: [.anchored, .caseInsensitive])
        guard cleaned.count.isMultiple(of: 2) else { return nil }
        var data = Data()
        data.reserveCapacity(cleaned.count / 2)
        var idx = cleaned.startIndex
        while idx < cleaned.endIndex {
            let next = cleaned.index(idx, offsetBy: 2)
            guard let byte = UInt8(cleaned[idx..<next], radix: 16) else { return nil }
            data.append(byte)
            idx = next
        }
        return data
    }

    public static func encode(_ data: Data) -> String {
        data.map { String(format: "%02X", $0) }.joined()
    }
}
