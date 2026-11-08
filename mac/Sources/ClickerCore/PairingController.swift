import Foundation

public protocol InputEnvironment {
    var canPostEvents: Bool { get }
    var secureInputActive: Bool { get }
}

public enum AdvertisingMode: Equatable, Sendable { case off, pairing, reconnect }

public struct ApprovalRequest: Equatable, Sendable {
    public var central: UUID
    public var watch: PairedWatch
    public var replacing: PairedWatch?

    public init(central: UUID, watch: PairedWatch, replacing: PairedWatch?) {
        self.central = central
        self.watch = watch
        self.replacing = replacing
    }
}

public struct StatusUpdate: Equatable, Sendable {
    public var central: UUID
    public var status: LinkStatus

    public init(central: UUID, status: LinkStatus) {
        self.central = central
        self.status = status
    }
}

public struct WriteResult: Equatable, Sendable {
    public var att: ATTResult
    public var action: SlideAction?
    public var status: LinkStatus?
    public var approvalRequest: ApprovalRequest?

    public init(att: ATTResult, action: SlideAction? = nil, status: LinkStatus? = nil,
                approvalRequest: ApprovalRequest? = nil) {
        self.att = att
        self.action = action
        self.status = status
        self.approvalRequest = approvalRequest
    }
}

public final class PairingController {
    public static let pairingDuration: TimeInterval = 120
    public static let denyCooldown: TimeInterval = 60

    private struct Session {
        var subscribed = false
        /// ID of the watch whose HELLO was accepted in this session.
        var helloWatchID: Data?
    }

    private let store: PairingStore
    private let environment: InputEnvironment
    private let now: () -> Date

    private var sessions: [UUID: Session] = [:]
    private var pairingDeadline: Date?
    private var cooldowns: [Data: Date] = [:]
    public private(set) var pendingApproval: ApprovalRequest?

    public init(store: PairingStore, environment: InputEnvironment, now: @escaping () -> Date = Date.init) {
        self.store = store
        self.environment = environment
        self.now = now
    }

    // MARK: State

    public var macID: Data { store.macID }
    public var pairedWatch: PairedWatch? { store.paired }

    public var isBroadcastEnabled: Bool {
        get { store.broadcastEnabled }
        set {
            store.broadcastEnabled = newValue
            if !newValue {
                sessions.removeAll()
                pendingApproval = nil
                pairingDeadline = nil
            }
        }
    }

    public var isPairingModeActive: Bool {
        pendingApproval != nil || (pairingDeadline.map { now() < $0 } ?? false)
    }

    public var pairingModeRemaining: TimeInterval? {
        guard let deadline = pairingDeadline else { return nil }
        let remaining = deadline.timeIntervalSince(now())
        return remaining > 0 ? remaining : nil
    }

    public var connectedWatchName: String? {
        guard let paired = store.paired else { return nil }
        let connected = sessions.values.contains { $0.subscribed && $0.helloWatchID == paired.id }
        return connected ? paired.name : nil
    }

    public var advertisingMode: AdvertisingMode {
        if isPairingModeActive { return .pairing }
        if !store.broadcastEnabled { return .off }
        if connectedWatchName != nil { return .off }
        return store.paired != nil ? .reconnect : .off
    }

    // MARK: Pairing mode

    public func startPairingMode() {
        store.broadcastEnabled = true
        pairingDeadline = now().addingTimeInterval(Self.pairingDuration)
    }

    public func stopPairingMode() {
        pairingDeadline = nil
    }

    // MARK: Central lifecycle

    public func centralSubscribed(_ central: UUID) {
        sessions[central, default: Session()].subscribed = true
    }

    /// Returns true when a pending approval for this central was cancelled (close the window).
    public func centralUnsubscribed(_ central: UUID) -> Bool {
        sessions[central] = nil
        guard let pending = pendingApproval, pending.central == central else { return false }
        cooldowns[pending.watch.id] = now().addingTimeInterval(Self.denyCooldown)
        pendingApproval = nil
        return true
    }

    /// Unpairs the watch. A pending approval is cancelled (its request named the
    /// forgotten watch as the one being replaced): that central gets `rejected`,
    /// without a cooldown, and may send HELLO again for a fresh request.
    public func forget() -> [StatusUpdate] {
        store.paired = nil
        let cancelled = pendingApproval?.central
        pendingApproval = nil
        var updates: [StatusUpdate] = []
        for (central, var session) in sessions {
            session.helloWatchID = nil
            sessions[central] = session
            if session.subscribed && central != cancelled {
                updates.append(StatusUpdate(central: central, status: .awaitingHello))
            }
        }
        if let cancelled { updates.append(StatusUpdate(central: cancelled, status: .rejected)) }
        return updates
    }

    // MARK: Writes

    public func handleWrite(from central: UUID, data: Data) -> WriteResult {
        let command: Command
        do {
            command = try WireCodec.decode(data)
        } catch {
            return WriteResult(att: error.att)
        }
        switch command {
        case let .hello(id, name):
            return handleHello(from: central, watch: PairedWatch(id: id, name: name))
        case .next:
            return handleSlide(from: central, action: .next)
        case .previous:
            return handleSlide(from: central, action: .previous)
        }
    }

    private func handleSlide(from central: UUID, action: SlideAction) -> WriteResult {
        guard let paired = store.paired, sessions[central]?.helloWatchID == paired.id else {
            return WriteResult(att: .insufficientAuthentication)
        }
        guard environment.canPostEvents, !environment.secureInputActive else {
            return WriteResult(att: .unlikelyError)
        }
        return WriteResult(att: .success, action: action)
    }

    private func handleHello(from central: UUID, watch: PairedWatch) -> WriteResult {
        let rejected = WriteResult(att: .insufficientAuthorization, status: .rejected)
        let pairingActive = isPairingModeActive
        if !store.broadcastEnabled && !pairingActive {
            sessions[central, default: Session()].helloWatchID = nil
            return rejected
        }
        if let paired = store.paired, paired.id == watch.id {
            sessions[central, default: Session()].helloWatchID = watch.id
            return WriteResult(att: .success, status: .accepted)
        }
        sessions[central, default: Session()].helloWatchID = nil
        guard pairingActive else { return rejected }
        if let until = cooldowns[watch.id], now() < until { return rejected }
        if let pending = pendingApproval {
            // Retry from the same watch while its window is open is not a second request.
            if pending.central == central && pending.watch.id == watch.id {
                return WriteResult(att: .success, status: .pendingApproval)
            }
            return rejected
        }
        let request = ApprovalRequest(central: central, watch: watch, replacing: store.paired)
        pendingApproval = request
        return WriteResult(att: .success, status: .pendingApproval, approvalRequest: request)
    }

    // MARK: Approval

    public func resolveApproval(approved: Bool) -> [StatusUpdate] {
        guard let pending = pendingApproval else { return [] }
        pendingApproval = nil
        if approved {
            store.paired = pending.watch
            cooldowns[pending.watch.id] = nil
            sessions[pending.central, default: Session()].helloWatchID = pending.watch.id
            pairingDeadline = nil
            return [StatusUpdate(central: pending.central, status: .accepted)]
        }
        cooldowns[pending.watch.id] = now().addingTimeInterval(Self.denyCooldown)
        return [StatusUpdate(central: pending.central, status: .rejected)]
    }
}
