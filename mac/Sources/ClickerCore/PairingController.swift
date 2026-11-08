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
    public static let denyCooldown: TimeInterval = 60

    private struct Session {
        var subscribed = false
        /// ID of the watch whose HELLO was accepted in this session.
        var helloWatchID: Data?
        /// Last HELLO outcome in this session was `rejected`.
        var rejected = false
    }

    private let store: PairingStore
    private let environment: InputEnvironment
    private let now: () -> Date

    private var sessions: [UUID: Session] = [:]
    private var pairingMode = false
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
                pairingMode = false
            }
        }
    }

    /// On from `startPairingMode()` until `stopPairingMode()`, an approval,
    /// or broadcasting turned off. No timeout: the app keeps it on while its
    /// pairing window is open.
    public var isPairingModeActive: Bool { pairingMode }

    public var connectedWatchName: String? {
        guard let paired = store.paired else { return nil }
        let connected = sessions.values.contains { $0.subscribed && $0.helloWatchID == paired.id }
        return connected ? paired.name : nil
    }

    /// Current Status value for `central`, as a read of the Status
    /// characteristic returns it. Every change of it for a subscribed central
    /// is reported for notification (`WriteResult.status` or a returned
    /// `StatusUpdate`); when the session ends (unsubscribe, broadcasting off)
    /// it silently falls back to `awaitingHello`.
    public func status(for central: UUID) -> LinkStatus {
        if pendingApproval?.central == central { return .pendingApproval }
        guard let session = sessions[central] else { return .awaitingHello }
        if let paired = store.paired, session.helloWatchID == paired.id { return .accepted }
        return session.rejected ? .rejected : .awaitingHello
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
        pairingMode = true
    }

    /// Ends pairing mode. A pending approval is cancelled like `forget()`
    /// does: that central gets `rejected`, without a cooldown.
    public func stopPairingMode() -> [StatusUpdate] {
        pairingMode = false
        guard let pending = pendingApproval else { return [] }
        pendingApproval = nil
        sessions[pending.central, default: Session()].rejected = true
        return [StatusUpdate(central: pending.central, status: .rejected)]
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
            session.rejected = false
            sessions[central] = session
            if session.subscribed && central != cancelled {
                updates.append(StatusUpdate(central: central, status: .awaitingHello))
            }
        }
        if let cancelled {
            sessions[cancelled, default: Session()].rejected = true
            updates.append(StatusUpdate(central: cancelled, status: .rejected))
        }
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
            return WriteResult(att: .helloRequired)
        }
        guard environment.canPostEvents, !environment.secureInputActive else {
            return WriteResult(att: .unlikelyError)
        }
        return WriteResult(att: .success, action: action)
    }

    private func handleHello(from central: UUID, watch: PairedWatch) -> WriteResult {
        let pairingActive = isPairingModeActive
        if let paired = store.paired, paired.id == watch.id, store.broadcastEnabled || pairingActive {
            setHello(central, watchID: watch.id, rejected: false)
            return WriteResult(att: .success, status: .accepted)
        }
        if let pending = pendingApproval, pending.central == central, pending.watch.id == watch.id {
            // Retry from the same watch while its window is open is not a second request.
            return WriteResult(att: .success, status: .pendingApproval)
        }
        let blocked = !pairingActive
            || cooldowns[watch.id].map { now() < $0 } ?? false
            || pendingApproval != nil
        if blocked {
            setHello(central, watchID: nil, rejected: true)
            return WriteResult(att: .rejected, status: .rejected)
        }
        setHello(central, watchID: nil, rejected: false)
        let request = ApprovalRequest(central: central, watch: watch, replacing: store.paired)
        pendingApproval = request
        return WriteResult(att: .success, status: .pendingApproval, approvalRequest: request)
    }

    private func setHello(_ central: UUID, watchID: Data?, rejected: Bool) {
        sessions[central, default: Session()].helloWatchID = watchID
        sessions[central, default: Session()].rejected = rejected
    }

    // MARK: Approval

    public func resolveApproval(approved: Bool) -> [StatusUpdate] {
        guard let pending = pendingApproval else { return [] }
        pendingApproval = nil
        if approved {
            // Subscribed centrals of the replaced watch lose access.
            var updates: [StatusUpdate] = []
            if let old = store.paired, old.id != pending.watch.id {
                for (central, session) in sessions where session.helloWatchID == old.id {
                    sessions[central]?.helloWatchID = nil
                    if session.subscribed {
                        updates.append(StatusUpdate(central: central, status: .awaitingHello))
                    }
                }
            }
            store.paired = pending.watch
            cooldowns[pending.watch.id] = nil
            setHello(pending.central, watchID: pending.watch.id, rejected: false)
            pairingMode = false
            return updates + [StatusUpdate(central: pending.central, status: .accepted)]
        }
        cooldowns[pending.watch.id] = now().addingTimeInterval(Self.denyCooldown)
        sessions[pending.central, default: Session()].rejected = true
        return [StatusUpdate(central: pending.central, status: .rejected)]
    }
}
