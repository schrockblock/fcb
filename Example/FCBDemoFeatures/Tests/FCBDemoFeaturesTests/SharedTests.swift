import CoreBluetooth
import Foundation
import Testing
@testable import FCBDemoFeatures

struct HexCodingTests {
    @Test func decodeValidHex() {
        #expect(HexCoding.decode("DEADBEEF") == Data([0xDE, 0xAD, 0xBE, 0xEF]))
    }
    @Test func decodeLowercaseHex() {
        #expect(HexCoding.decode("deadbeef") == Data([0xDE, 0xAD, 0xBE, 0xEF]))
    }
    @Test func decodeWithSpaces() {
        #expect(HexCoding.decode("DE AD BE EF") == Data([0xDE, 0xAD, 0xBE, 0xEF]))
    }
    @Test func decodeWith0xPrefix() {
        #expect(HexCoding.decode("0xDEAD") == Data([0xDE, 0xAD]))
    }
    @Test func decodeInvalidLength() {
        #expect(HexCoding.decode("ABC") == nil)
    }
    @Test func decodeInvalidChars() {
        #expect(HexCoding.decode("GG") == nil)
    }
    @Test func decodeEmpty() {
        #expect(HexCoding.decode("") == Data())
    }
    @Test func encodeRoundTrip() {
        let original = Data([0x01, 0x02, 0x03])
        #expect(HexCoding.encode(original) == "010203")
    }
}

struct CBUUIDParsingTests {
    @Test func parseShortUUID() {
        #expect(CBUUIDParsing.parse("180F") == CBUUID(string: "180F"))
    }
    @Test func parseFullUUID() {
        let s = "0000180F-0000-1000-8000-00805F9B34FB"
        #expect(CBUUIDParsing.parse(s) == CBUUID(string: s))
    }
    @Test func parseInvalid() {
        #expect(CBUUIDParsing.parse("nope") == nil)
    }
    @Test func parseTrimsWhitespace() {
        #expect(CBUUIDParsing.parse("  180F  ") == CBUUID(string: "180F"))
    }
    @Test func parseListBasic() {
        let parsed = CBUUIDParsing.parseList("180F, 2A19")
        #expect(parsed == [CBUUID(string: "180F"), CBUUID(string: "2A19")])
    }
    @Test func parseListSkipsInvalid() {
        let parsed = CBUUIDParsing.parseList("180F, nope, 2A19")
        #expect(parsed == [CBUUID(string: "180F"), CBUUID(string: "2A19")])
    }
    @Test func parseListEmpty() {
        #expect(CBUUIDParsing.parseList("") == [])
    }
}
