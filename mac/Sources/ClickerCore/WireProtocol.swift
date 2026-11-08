import Foundation

public enum WireUUID {
    public static let service = "8B1F0001-2C4D-4E5A-9F61-7A3B2C1D0E01"
    public static let command = "8B1F0002-2C4D-4E5A-9F61-7A3B2C1D0E01"
    public static let status = "8B1F0003-2C4D-4E5A-9F61-7A3B2C1D0E01"
    public static let macInfo = "8B1F0004-2C4D-4E5A-9F61-7A3B2C1D0E01"
    public static let pairingAdvertisement = "8B1F00A0-2C4D-4E5A-9F61-7A3B2C1D0E01"
}

public enum Command: Equatable, Sendable {
    case hello(id: Data, name: String)
    case next
    case previous
}

/// ATT result codes returned to the watch on a Command write. Refusals use
/// application error codes (0x80…0x9F): the standard insufficient
/// authentication/authorization codes make the central's OS start pairing.
public enum ATTResult: UInt8, Sendable {
    case success = 0x00
    case requestNotSupported = 0x06
    case invalidAttributeValueLength = 0x0D
    case unlikelyError = 0x0E
    /// NEXT/PREV without an accepted HELLO in this session.
    case helloRequired = 0x80
    /// HELLO refused (not paired and not pairing mode, cooldown, another request open).
    case rejected = 0x81
}

public enum DecodeError: Error, Equatable, Sendable {
    case badLength
    case badName
    case unknownOpcode(UInt8)

    public var att: ATTResult {
        switch self {
        case .badLength, .badName: return .invalidAttributeValueLength
        case .unknownOpcode: return .requestNotSupported
        }
    }
}

public enum LinkStatus: UInt8, Sendable {
    case awaitingHello = 0
    case accepted = 1
    case rejected = 2
    case pendingApproval = 3
}

public struct MacInfo: Equatable, Sendable {
    public var id: Data
    public var name: String

    public init(id: Data, name: String) {
        self.id = id
        self.name = name
    }
}

public enum WireCodec {
    public static let defaultWatchName = "Garmin"

    static let idLength = 8
    static let maxWatchNameBytes = 11
    static let maxMacNameBytes = 14

    private static let opHello: UInt8 = 0x01
    private static let opNext: UInt8 = 0x02
    private static let opPrevious: UInt8 = 0x03

    public static func decode(_ data: Data) throws(DecodeError) -> Command {
        let bytes = [UInt8](data)
        guard let opcode = bytes.first else { throw .badLength }
        switch opcode {
        case opHello:
            guard bytes.count >= 1 + idLength, bytes.count <= 1 + idLength + maxWatchNameBytes else {
                throw .badLength
            }
            let id = Data(bytes[1..<(1 + idLength)])
            let nameBytes = Data(bytes[(1 + idLength)...])
            guard let name = String(data: nameBytes, encoding: .utf8) else { throw .badName }
            return .hello(id: id, name: name.isEmpty ? defaultWatchName : name)
        case opNext:
            guard bytes.count == 1 else { throw .badLength }
            return .next
        case opPrevious:
            guard bytes.count == 1 else { throw .badLength }
            return .previous
        default:
            throw .unknownOpcode(opcode)
        }
    }

    public static func encode(_ command: Command) -> Data {
        switch command {
        case .next:
            return Data([opNext])
        case .previous:
            return Data([opPrevious])
        case let .hello(id, name):
            return Data([opHello]) + id.prefix(idLength) + truncatedUTF8(name, maxBytes: maxWatchNameBytes)
        }
    }

    public static func encode(_ info: MacInfo) -> Data {
        Data(info.id.prefix(idLength)) + truncatedUTF8(info.name, maxBytes: maxMacNameBytes)
    }

    public static func decodeMacInfo(_ data: Data) throws(DecodeError) -> MacInfo {
        let bytes = [UInt8](data)
        guard bytes.count >= idLength, bytes.count <= idLength + maxMacNameBytes else { throw .badLength }
        guard let name = String(data: Data(bytes[idLength...]), encoding: .utf8) else { throw .badName }
        return MacInfo(id: Data(bytes[0..<idLength]), name: name)
    }

    /// UTF-8 bytes of the longest prefix of `string` that fits in `maxBytes`,
    /// cut on a character (grapheme) boundary.
    private static func truncatedUTF8(_ string: String, maxBytes: Int) -> Data {
        var result = Data()
        for character in string {
            let encoded = Data(String(character).utf8)
            if result.count + encoded.count > maxBytes { break }
            result.append(encoded)
        }
        return result
    }
}
