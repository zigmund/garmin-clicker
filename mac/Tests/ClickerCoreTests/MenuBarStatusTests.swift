import Testing
@testable import ClickerCore

struct MenuBarStatusTests {
    typealias S = MenuBarStatus
    @Test func deriveBluetoothOffWins() {
        #expect(S.derive(bluetooth: .poweredOff, canPostEvents: false, isPaired: true, isPairingMode: true, isBroadcastEnabled: true, connectedName: "A") == .bluetoothOff)
        #expect(S.derive(bluetooth: .unsupported, canPostEvents: true, isPaired: true, isPairingMode: false, isBroadcastEnabled: true, connectedName: nil) == .bluetoothOff)
    }
    @Test func deriveUnauthorized() {
        #expect(S.derive(bluetooth: .unauthorized, canPostEvents: false, isPaired: true, isPairingMode: true, isBroadcastEnabled: true, connectedName: "A") == .bluetoothUnauthorized)
    }
    @Test func derivePairingBeatsPermission() {
        #expect(S.derive(bluetooth: .poweredOn, canPostEvents: false, isPaired: false, isPairingMode: true, isBroadcastEnabled: true, connectedName: nil) == .pairing)
    }
    @Test func derivePaused() {
        #expect(S.derive(bluetooth: .poweredOn, canPostEvents: false, isPaired: true, isPairingMode: false, isBroadcastEnabled: false, connectedName: nil) == .paused)
    }
    @Test func deriveNoInputPermission() {
        #expect(S.derive(bluetooth: .poweredOn, canPostEvents: false, isPaired: true, isPairingMode: false, isBroadcastEnabled: true, connectedName: "A") == .noInputPermission)
    }
    @Test func deriveConnected() {
        #expect(S.derive(bluetooth: .poweredOn, canPostEvents: true, isPaired: true, isPairingMode: false, isBroadcastEnabled: true, connectedName: "A") == .connected(name: "A"))
    }
    @Test func deriveNotPaired() {
        #expect(S.derive(bluetooth: .poweredOn, canPostEvents: true, isPaired: false, isPairingMode: false, isBroadcastEnabled: true, connectedName: nil) == .notPaired)
    }
    @Test func deriveWaiting() {
        #expect(S.derive(bluetooth: .poweredOn, canPostEvents: true, isPaired: true, isPairingMode: false, isBroadcastEnabled: true, connectedName: nil) == .waiting)
        #expect(S.derive(bluetooth: .unknown, canPostEvents: true, isPaired: true, isPairingMode: false, isBroadcastEnabled: true, connectedName: nil) == .waiting)
    }
    @Test func symbolsAndKeys() {
        #expect(S.connected(name: "A").symbolName == "applewatch.radiowaves.left.and.right")
        #expect(S.pairing.symbolName == "dot.radiowaves.left.and.right")
        #expect(S.waiting.symbolName == "applewatch")
        #expect(S.notPaired.symbolName == "applewatch.slash")
        #expect(S.paused.symbolName == "pause.circle")
        for s in [S.bluetoothOff, .bluetoothUnauthorized, .noInputPermission] {
            #expect(s.symbolName == "exclamationmark.triangle")
        }
        #expect(S.connected(name: "A").titleKey == "status.connected")
        #expect(S.bluetoothOff.titleKey == "status.bluetoothOff")
    }
}
