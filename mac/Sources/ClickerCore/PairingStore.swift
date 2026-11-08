import Foundation

public struct PairedWatch: Equatable, Sendable {
    public var id: Data
    public var name: String

    public init(id: Data, name: String) {
        self.id = id
        self.name = name
    }
}

public protocol PairingStore: AnyObject {
    var paired: PairedWatch? { get set }
    /// 8 bytes; generated and persisted on first access.
    var macID: Data { get }
    var broadcastEnabled: Bool { get set }
}

public final class UserDefaultsPairingStore: PairingStore {
    private let defaults: UserDefaults

    private enum Key {
        static let watchID = "pairedWatchID"
        static let watchName = "pairedWatchName"
        static let macID = "macID"
        static let broadcastEnabled = "broadcastEnabled"
    }

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public var paired: PairedWatch? {
        get {
            guard let id = defaults.data(forKey: Key.watchID) else { return nil }
            let name = defaults.string(forKey: Key.watchName) ?? WireCodec.defaultWatchName
            return PairedWatch(id: id, name: name)
        }
        set {
            if let newValue {
                defaults.set(newValue.id, forKey: Key.watchID)
                defaults.set(newValue.name, forKey: Key.watchName)
            } else {
                defaults.removeObject(forKey: Key.watchID)
                defaults.removeObject(forKey: Key.watchName)
            }
        }
    }

    public var macID: Data {
        if let existing = defaults.data(forKey: Key.macID), existing.count == 8 { return existing }
        let generated = Data((0..<8).map { _ in UInt8.random(in: 0...255) })
        defaults.set(generated, forKey: Key.macID)
        return generated
    }

    public var broadcastEnabled: Bool {
        get { defaults.object(forKey: Key.broadcastEnabled) as? Bool ?? true }
        set { defaults.set(newValue, forKey: Key.broadcastEnabled) }
    }
}
