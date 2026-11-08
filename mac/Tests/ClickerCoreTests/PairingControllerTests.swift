import Testing
import Foundation
@testable import ClickerCore

private final class FakeStore: PairingStore {
    var paired: PairedWatch?
    var macID = Data(repeating: 9, count: 8)
    var broadcastEnabled = true
}

private final class FakeEnvironment: InputEnvironment {
    var canPostEvents = true
    var secureInputActive = false
}

private let idA = Data(repeating: 1, count: 8)
private let idB = Data(repeating: 2, count: 8)

private func hello(_ id: Data, _ name: String) -> Data {
    WireCodec.encode(.hello(id: id, name: name))
}

private final class Fixture {
    let store = FakeStore()
    let env = FakeEnvironment()
    var t = Date(timeIntervalSince1970: 0)
    let a = UUID()
    let b = UUID()
    lazy var controller = PairingController(store: store, environment: env, now: { [unowned self] in self.t })

    /// Pair idA/"A" through the normal flow, subscribed as `a`.
    func pairA() {
        controller.startPairingMode()
        controller.centralSubscribed(a)
        _ = controller.handleWrite(from: a, data: hello(idA, "A"))
        _ = controller.resolveApproval(approved: true)
    }
}

struct PairingControllerTests {
    @Test func helloOutsidePairingModeIsRejected() {
        let f = Fixture()
        let r = f.controller.handleWrite(from: f.a, data: hello(idA, "A"))
        #expect(r.att == .rejected)
        #expect(r.status == .rejected)
        #expect(r.approvalRequest == nil)
    }

    @Test func helloInPairingModeRequestsApproval() {
        let f = Fixture()
        f.controller.startPairingMode()
        let r = f.controller.handleWrite(from: f.a, data: hello(idA, "A"))
        #expect(r.att == .success)
        #expect(r.status == .pendingApproval)
        #expect(r.approvalRequest == ApprovalRequest(central: f.a, watch: PairedWatch(id: idA, name: "A"), replacing: nil))
        #expect(f.controller.pendingApproval == r.approvalRequest)
    }

    @Test func approvalPairsAndEndsPairingMode() {
        let f = Fixture()
        f.controller.startPairingMode()
        _ = f.controller.handleWrite(from: f.a, data: hello(idA, "A"))
        let updates = f.controller.resolveApproval(approved: true)
        #expect(updates == [StatusUpdate(central: f.a, status: .accepted)])
        #expect(f.controller.pairedWatch?.id == idA)
        #expect(f.controller.isPairingModeActive == false)
        #expect(f.controller.pendingApproval == nil)
    }

    @Test func approvalEndsPairingModeAdvertisingOff() {
        let f = Fixture()
        f.pairA()
        #expect(f.controller.advertisingMode == .off)
    }

    @Test func resolveWithoutPendingIsNoop() {
        let f = Fixture()
        #expect(f.controller.resolveApproval(approved: true).isEmpty)
        #expect(f.controller.pairedWatch == nil)
    }

    @Test func denyRejectsAndStartsCooldown() {
        let f = Fixture()
        f.controller.startPairingMode()
        _ = f.controller.handleWrite(from: f.a, data: hello(idA, "A"))
        #expect(f.controller.resolveApproval(approved: false) == [StatusUpdate(central: f.a, status: .rejected)])
        #expect(f.controller.pairedWatch == nil)
    }

    @Test func deniedWatchIsInCooldown() {
        let f = Fixture()
        f.controller.startPairingMode()
        _ = f.controller.handleWrite(from: f.a, data: hello(idA, "A"))
        _ = f.controller.resolveApproval(approved: false)
        f.t += 59
        let early = f.controller.handleWrite(from: f.a, data: hello(idA, "A"))
        #expect(f.controller.isPairingModeActive)
        #expect(early.att == .rejected)
        #expect(early.approvalRequest == nil)
        f.t += 2
        f.controller.startPairingMode()
        let late = f.controller.handleWrite(from: f.a, data: hello(idA, "A"))
        #expect(late.approvalRequest != nil)
    }

    @Test func secondRequestWhilePendingIsRejected() {
        let f = Fixture()
        f.controller.startPairingMode()
        _ = f.controller.handleWrite(from: f.a, data: hello(idA, "A"))
        let r = f.controller.handleWrite(from: f.b, data: hello(idB, "B"))
        #expect(r.att == .rejected)
        #expect(r.status == .rejected)
        #expect(r.approvalRequest == nil)
    }

    @Test func repeatedHelloFromPendingWatchDoesNotOpenSecondWindow() {
        let f = Fixture()
        f.controller.startPairingMode()
        _ = f.controller.handleWrite(from: f.a, data: hello(idA, "A"))
        let r = f.controller.handleWrite(from: f.a, data: hello(idA, "A"))
        #expect(r.att == .success)
        #expect(r.status == .pendingApproval)
        #expect(r.approvalRequest == nil)
    }

    @Test func replacingShowsOldWatch() {
        let f = Fixture()
        f.pairA()
        f.controller.startPairingMode()
        let r = f.controller.handleWrite(from: f.b, data: hello(idB, "B"))
        #expect(r.approvalRequest?.replacing == PairedWatch(id: idA, name: "A"))
    }

    @Test func replacedWatchLosesAccess() {
        let f = Fixture()
        f.pairA()
        f.controller.startPairingMode()
        f.controller.centralSubscribed(f.b)
        _ = f.controller.handleWrite(from: f.b, data: hello(idB, "B"))
        _ = f.controller.resolveApproval(approved: true)
        #expect(f.controller.handleWrite(from: f.a, data: WireCodec.encode(.next)).att == .helloRequired)
        #expect(f.controller.handleWrite(from: f.b, data: WireCodec.encode(.next)).att == .success)
        #expect(f.controller.connectedWatchName == "B")
    }

    @Test func approvalReplacingNotifiesOldWatch() {
        let f = Fixture()
        f.pairA()
        f.controller.startPairingMode()
        f.controller.centralSubscribed(f.b)
        _ = f.controller.handleWrite(from: f.b, data: hello(idB, "B"))
        let updates = f.controller.resolveApproval(approved: true)
        #expect(updates.count == 2)
        #expect(updates.contains(StatusUpdate(central: f.b, status: .accepted)))
        #expect(updates.contains(StatusUpdate(central: f.a, status: .awaitingHello)))
        for update in updates {
            #expect(f.controller.status(for: update.central) == update.status)
        }
    }

    @Test func reconnectSamePairedWatchIsAccepted() {
        let f = Fixture()
        f.pairA()
        let r = f.controller.handleWrite(from: UUID(), data: hello(idA, "A"))
        #expect(r.att == .success)
        #expect(r.status == .accepted)
        #expect(r.approvalRequest == nil)
    }

    @Test func nextBeforeHelloNeedsAuthentication() {
        let f = Fixture()
        let r = f.controller.handleWrite(from: f.a, data: WireCodec.encode(.next))
        #expect(r.att == .helloRequired)
        #expect(r.action == nil)
    }

    @Test func nextWhilePendingNeedsAuthentication() {
        let f = Fixture()
        f.controller.startPairingMode()
        _ = f.controller.handleWrite(from: f.a, data: hello(idA, "A"))
        let r = f.controller.handleWrite(from: f.a, data: WireCodec.encode(.next))
        #expect(r.att == .helloRequired)
        #expect(r.action == nil)
    }

    @Test func nextAfterAcceptSendsAction() {
        let f = Fixture()
        f.pairA()
        #expect(f.controller.handleWrite(from: f.a, data: WireCodec.encode(.next)).action == .next)
        let prev = f.controller.handleWrite(from: f.a, data: WireCodec.encode(.previous))
        #expect(prev.att == .success)
        #expect(prev.action == .previous)
    }

    @Test func nextWithoutPostPermissionFails() {
        let f = Fixture()
        f.pairA()
        f.env.canPostEvents = false
        let r = f.controller.handleWrite(from: f.a, data: WireCodec.encode(.next))
        #expect(r.att == .unlikelyError)
        #expect(r.action == nil)
    }

    @Test func nextDuringSecureInputFails() {
        let f = Fixture()
        f.pairA()
        f.env.secureInputActive = true
        let r = f.controller.handleWrite(from: f.a, data: WireCodec.encode(.previous))
        #expect(r.att == .unlikelyError)
        #expect(r.action == nil)
    }

    @Test func malformedWriteReturnsDecodeError() {
        let f = Fixture()
        #expect(f.controller.handleWrite(from: f.a, data: Data()).att == .invalidAttributeValueLength)
        #expect(f.controller.handleWrite(from: f.a, data: Data([0x7F])).att == .requestNotSupported)
    }

    @Test func pairingModeExpires() {
        let f = Fixture()
        f.controller.startPairingMode()
        f.t += 119
        #expect(f.controller.isPairingModeActive)
        #expect(f.controller.pairingModeRemaining == 1)
        f.t += 2
        #expect(f.controller.isPairingModeActive == false)
        #expect(f.controller.advertisingMode == .off)
    }

    @Test func stopPairingModeEndsPairing() {
        let unpaired = Fixture()
        unpaired.controller.startPairingMode()
        #expect(unpaired.controller.stopPairingMode().isEmpty)
        #expect(unpaired.controller.isPairingModeActive == false)
        #expect(unpaired.controller.advertisingMode == .off)

        let paired = Fixture()
        paired.pairA()
        _ = paired.controller.centralUnsubscribed(paired.a)
        paired.controller.startPairingMode()
        #expect(paired.controller.stopPairingMode().isEmpty)
        #expect(paired.controller.isPairingModeActive == false)
        #expect(paired.controller.advertisingMode == .reconnect)
    }

    @Test func stopPairingModeCancelsPending() {
        let f = Fixture()
        f.controller.startPairingMode()
        f.controller.centralSubscribed(f.b)
        #expect(f.controller.handleWrite(from: f.b, data: hello(idB, "B")).approvalRequest != nil)

        #expect(f.controller.stopPairingMode() == [StatusUpdate(central: f.b, status: .rejected)])
        #expect(f.controller.pendingApproval == nil)
        #expect(f.controller.isPairingModeActive == false)
        #expect(f.controller.status(for: f.b) == .rejected)

        // No cooldown: a fresh pairing mode lets b open a new request.
        f.controller.startPairingMode()
        let r = f.controller.handleWrite(from: f.b, data: hello(idB, "B"))
        #expect(r.status == .pendingApproval)
        #expect(r.approvalRequest == ApprovalRequest(central: f.b, watch: PairedWatch(id: idB, name: "B"), replacing: nil))
    }

    @Test func pendingApprovalKeepsPairingModeAlive() {
        let f = Fixture()
        f.controller.startPairingMode()
        f.t += 100
        _ = f.controller.handleWrite(from: f.a, data: hello(idA, "A"))
        f.t = Date(timeIntervalSince1970: 200)
        #expect(f.controller.isPairingModeActive)
        _ = f.controller.resolveApproval(approved: false)
        #expect(f.controller.isPairingModeActive == false)
    }

    @Test func unsubscribeWhilePendingCancelsApproval() {
        let f = Fixture()
        f.controller.startPairingMode()
        f.controller.centralSubscribed(f.a)
        _ = f.controller.handleWrite(from: f.a, data: hello(idA, "A"))
        #expect(f.controller.centralUnsubscribed(f.a) == true)
        #expect(f.controller.pendingApproval == nil)
        let again = f.controller.handleWrite(from: f.a, data: hello(idA, "A"))
        #expect(again.att == .rejected)
        #expect(f.controller.centralUnsubscribed(f.b) == false)
    }

    @Test func broadcastOffStopsEverything() {
        let f = Fixture()
        f.pairA()
        f.controller.isBroadcastEnabled = false
        #expect(f.controller.advertisingMode == .off)
        #expect(f.store.broadcastEnabled == false)
        #expect(f.controller.pairedWatch?.id == idA)
        let r = f.controller.handleWrite(from: f.a, data: hello(idA, "A"))
        #expect(r.att == .rejected)
        #expect(r.status == .rejected)
    }

    @Test func startPairingReenablesBroadcast() {
        let f = Fixture()
        f.store.broadcastEnabled = false
        f.controller.startPairingMode()
        #expect(f.controller.isBroadcastEnabled)
        #expect(f.controller.advertisingMode == .pairing)
    }

    @Test func advertisingModeTransitions() {
        let f = Fixture()
        #expect(f.controller.advertisingMode == .off)
        f.controller.startPairingMode()
        #expect(f.controller.advertisingMode == .pairing)
        f.controller.centralSubscribed(f.a)
        _ = f.controller.handleWrite(from: f.a, data: hello(idA, "A"))
        _ = f.controller.resolveApproval(approved: true)
        #expect(f.controller.advertisingMode == .off)
        _ = f.controller.centralUnsubscribed(f.a)
        #expect(f.controller.advertisingMode == .reconnect)
    }

    @Test func connectedNameRequiresSubscriptionAndAccept() {
        let f = Fixture()
        f.controller.startPairingMode()
        _ = f.controller.handleWrite(from: f.a, data: hello(idA, "A"))
        _ = f.controller.resolveApproval(approved: true)
        #expect(f.controller.connectedWatchName == nil)
        f.controller.centralSubscribed(f.a)
        #expect(f.controller.connectedWatchName == "A")
    }

    @Test func forgetClearsPairingAndNotifies() {
        let f = Fixture()
        f.pairA()
        #expect(f.controller.forget() == [StatusUpdate(central: f.a, status: .awaitingHello)])
        #expect(f.controller.pairedWatch == nil)
        #expect(f.controller.handleWrite(from: f.a, data: WireCodec.encode(.next)).att == .helloRequired)
        #expect(f.controller.advertisingMode == .off)
    }

    @Test func forgetCancelsPendingApproval() {
        let f = Fixture()
        f.pairA()
        f.controller.startPairingMode()
        f.controller.centralSubscribed(f.b)
        #expect(f.controller.handleWrite(from: f.b, data: hello(idB, "B")).approvalRequest != nil)

        let updates = f.controller.forget()
        #expect(updates.count == 2)
        #expect(updates.contains(StatusUpdate(central: f.a, status: .awaitingHello)))
        #expect(updates.contains(StatusUpdate(central: f.b, status: .rejected)))
        #expect(f.controller.pendingApproval == nil)

        // No cooldown: a new HELLO from b opens a fresh request with nothing to replace.
        let r = f.controller.handleWrite(from: f.b, data: hello(idB, "B"))
        #expect(r.status == .pendingApproval)
        #expect(r.approvalRequest == ApprovalRequest(central: f.b, watch: PairedWatch(id: idB, name: "B"), replacing: nil))
    }

    // MARK: Status read (the watch reads Status after a failed write)

    @Test func statusOfUnknownCentralIsAwaitingHello() {
        let f = Fixture()
        #expect(f.controller.status(for: f.a) == .awaitingHello)
        f.controller.centralSubscribed(f.a)
        #expect(f.controller.status(for: f.a) == .awaitingHello)
    }

    @Test func statusFollowsApprovalFlow() {
        let f = Fixture()
        f.controller.startPairingMode()
        f.controller.centralSubscribed(f.a)
        _ = f.controller.handleWrite(from: f.a, data: hello(idA, "A"))
        #expect(f.controller.status(for: f.a) == .pendingApproval)
        _ = f.controller.resolveApproval(approved: true)
        #expect(f.controller.status(for: f.a) == .accepted)
    }

    @Test func statusAfterDenyIsRejected() {
        let f = Fixture()
        f.controller.startPairingMode()
        _ = f.controller.handleWrite(from: f.a, data: hello(idA, "A"))
        _ = f.controller.resolveApproval(approved: false)
        #expect(f.controller.status(for: f.a) == .rejected)
    }

    @Test func statusAfterRejectedHelloIsRejected() {
        let f = Fixture()
        _ = f.controller.handleWrite(from: f.a, data: hello(idA, "A"))
        #expect(f.controller.status(for: f.a) == .rejected)

        f.controller.startPairingMode()
        _ = f.controller.handleWrite(from: f.a, data: hello(idA, "A"))
        _ = f.controller.handleWrite(from: f.b, data: hello(idB, "B"))
        #expect(f.controller.status(for: f.a) == .pendingApproval)
        #expect(f.controller.status(for: f.b) == .rejected)
    }

    @Test func statusOfReconnectedPairedWatchIsAccepted() {
        let f = Fixture()
        f.pairA()
        let c = UUID()
        f.controller.centralSubscribed(c)
        #expect(f.controller.status(for: c) == .awaitingHello)
        _ = f.controller.handleWrite(from: c, data: hello(idA, "A"))
        #expect(f.controller.status(for: c) == .accepted)
    }

    @Test func statusResetsOnUnsubscribeAndBroadcastOff() {
        let f = Fixture()
        f.pairA()
        #expect(f.controller.centralUnsubscribed(f.a) == false)
        #expect(f.controller.status(for: f.a) == .awaitingHello)

        f.controller.centralSubscribed(f.a)
        _ = f.controller.handleWrite(from: f.a, data: hello(idA, "A"))
        f.controller.isBroadcastEnabled = false
        #expect(f.controller.status(for: f.a) == .awaitingHello)
    }

    @Test func statusAfterForgetMatchesNotifications() {
        let f = Fixture()
        f.pairA()
        f.controller.startPairingMode()
        f.controller.centralSubscribed(f.b)
        _ = f.controller.handleWrite(from: f.b, data: hello(idB, "B"))
        let updates = f.controller.forget()
        for update in updates {
            #expect(f.controller.status(for: update.central) == update.status)
        }
        #expect(f.controller.status(for: f.a) == .awaitingHello)
        #expect(f.controller.status(for: f.b) == .rejected)
    }

    @Test func replacedWatchStatusIsNoLongerAccepted() {
        let f = Fixture()
        f.pairA()
        f.controller.startPairingMode()
        _ = f.controller.handleWrite(from: f.b, data: hello(idB, "B"))
        _ = f.controller.resolveApproval(approved: true)
        #expect(f.controller.status(for: f.b) == .accepted)
        #expect(f.controller.status(for: f.a) == .awaitingHello)
    }

    @Test func macIDProxiesStore() {
        let f = Fixture()
        #expect(f.controller.macID == f.store.macID)
    }

    @Test func userDefaultsStoreRoundTrip() {
        let suite = "test-\(UUID())"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = UserDefaultsPairingStore(defaults: defaults)
        #expect(store.paired == nil)
        store.paired = PairedWatch(id: idA, name: "A")
        #expect(store.paired == PairedWatch(id: idA, name: "A"))
        store.paired = nil
        #expect(store.paired == nil)

        #expect(store.broadcastEnabled == true)
        store.broadcastEnabled = false
        #expect(UserDefaultsPairingStore(defaults: defaults).broadcastEnabled == false)

        let id = store.macID
        #expect(id.count == 8)
        let other = UserDefaultsPairingStore(defaults: defaults)
        #expect(other.macID == id)
        let controller = PairingController(store: other, environment: FakeEnvironment())
        #expect(controller.macID == id)
    }
}
