import Testing
import Foundation
@testable import ClickerCore

struct WireProtocolTests {
    private let watchID = Data(repeating: 0xAB, count: 8)

    @Test func decodeNext() throws { #expect(try WireCodec.decode(Data([0x02])) == .next) }
    @Test func decodePrevious() throws { #expect(try WireCodec.decode(Data([0x03])) == .previous) }

    @Test func decodeHelloWithName() throws {
        let data = Data([0x01]) + watchID + Data("fenix 6".utf8)
        #expect(try WireCodec.decode(data) == .hello(id: watchID, name: "fenix 6"))
    }

    @Test func decodeHelloEmptyNameUsesDefault() throws {
        let data = Data([0x01]) + watchID
        #expect(try WireCodec.decode(data) == .hello(id: watchID, name: "Garmin"))
    }

    @Test func decodeRejectsEmpty() {
        #expect(throws: DecodeError.badLength) { try WireCodec.decode(Data()) }
    }

    @Test func decodeRejectsShortHello() {
        let data = Data([0x01]) + Data(repeating: 0xAB, count: 7)
        #expect(data.count == 8)
        #expect(throws: DecodeError.badLength) { try WireCodec.decode(data) }
    }

    @Test func decodeRejectsLongHello() {
        let data = Data([0x01]) + Data(repeating: 0x41, count: 20)
        #expect(data.count == 21)
        #expect(throws: DecodeError.badLength) { try WireCodec.decode(data) }
    }

    @Test func decodeRejectsNextWithTail() {
        #expect(throws: DecodeError.badLength) { try WireCodec.decode(Data([0x02, 0x00])) }
    }

    @Test func decodeRejectsInvalidUTF8Name() {
        let data = Data([0x01]) + watchID + Data([0xFF, 0xFE])
        #expect(throws: DecodeError.badName) { try WireCodec.decode(data) }
    }

    @Test func decodeRejectsUnknownOpcode() {
        #expect(throws: DecodeError.unknownOpcode(0x7F)) { try WireCodec.decode(Data([0x7F])) }
        #expect(DecodeError.unknownOpcode(0x7F).att == .requestNotSupported)
        #expect(DecodeError.badLength.att == .invalidAttributeValueLength)
        #expect(DecodeError.badName.att == .invalidAttributeValueLength)
    }

    /// Application error codes (0x80…) so the central's OS never treats a
    /// refusal as a request to pair or encrypt the link.
    @Test func attResultCodes() {
        #expect(ATTResult.success.rawValue == 0x00)
        #expect(ATTResult.requestNotSupported.rawValue == 0x06)
        #expect(ATTResult.invalidAttributeValueLength.rawValue == 0x0D)
        #expect(ATTResult.unlikelyError.rawValue == 0x0E)
        #expect(ATTResult.helloRequired.rawValue == 0x80)
        #expect(ATTResult.rejected.rawValue == 0x81)
    }

    @Test func encodeRoundTrip() throws {
        let commands: [Command] = [.next, .previous, .hello(id: watchID, name: "fenix 6")]
        for command in commands {
            #expect(try WireCodec.decode(WireCodec.encode(command)) == command)
        }
    }

    @Test func encodeTruncatesLongNameOnCharacterBoundary() throws {
        let data = WireCodec.encode(.hello(id: watchID, name: "Фёдор Фёдорович"))
        #expect(data.count <= 20)
        _ = try WireCodec.decode(data)
    }

    @Test func macInfoRoundTrip() throws {
        let name = "Oleg’s MacBook Pro"
        let data = WireCodec.encode(MacInfo(id: watchID, name: name))
        #expect(data.count <= 22)
        let decoded = try WireCodec.decodeMacInfo(data)
        #expect(decoded.id == watchID)
        #expect(name.hasPrefix(decoded.name))
        #expect(!decoded.name.isEmpty)
    }

    @Test func macInfoRejectsShort() {
        #expect(throws: DecodeError.badLength) {
            try WireCodec.decodeMacInfo(Data(repeating: 0, count: 7))
        }
    }
}
