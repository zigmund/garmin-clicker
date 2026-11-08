public enum BluetoothState: Sendable { case unknown, poweredOff, unauthorized, unsupported, poweredOn }

public enum MenuBarStatus: Equatable, Sendable {
    case connected(name: String)
    case waiting, notPaired, pairing, paused
    case bluetoothOff, bluetoothUnauthorized, noInputPermission

    public static func derive(
        bluetooth: BluetoothState,
        canPostEvents: Bool,
        isPaired: Bool,
        isPairingMode: Bool,
        isBroadcastEnabled: Bool,
        connectedName: String?
    ) -> MenuBarStatus {
        switch bluetooth {
        case .poweredOff, .unsupported: return .bluetoothOff
        case .unauthorized: return .bluetoothUnauthorized
        case .unknown, .poweredOn: break
        }
        if isPairingMode { return .pairing }
        if isPaired && !isBroadcastEnabled { return .paused }
        if !canPostEvents { return .noInputPermission }
        if let connectedName { return .connected(name: connectedName) }
        if !isPaired { return .notPaired }
        return .waiting
    }

    public var symbolName: String {
        switch self {
        case .connected: "applewatch.radiowaves.left.and.right"
        case .pairing: "dot.radiowaves.left.and.right"
        case .waiting: "applewatch"
        case .notPaired: "applewatch.slash"
        case .paused: "pause.circle"
        case .bluetoothOff, .bluetoothUnauthorized, .noInputPermission: "exclamationmark.triangle"
        }
    }

    public var titleKey: String {
        switch self {
        case .connected: "status.connected"
        case .waiting: "status.waiting"
        case .notPaired: "status.notPaired"
        case .pairing: "status.pairing"
        case .paused: "status.paused"
        case .bluetoothOff: "status.bluetoothOff"
        case .bluetoothUnauthorized: "status.bluetoothUnauthorized"
        case .noInputPermission: "status.noInputPermission"
        }
    }
}
