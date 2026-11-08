import AppKit
import ClickerCore
import Observation
import os

/// App state for the menu. Owns the `PairingController`, which is not
/// observable, and mirrors the parts of its state the UI shows.
@MainActor @Observable final class AppModel {
    private enum Key {
        static let keyScheme = "keyScheme"
        static let appLanguage = "appLanguage"
        static let pairingPromptAnswered = "pairingPromptAnswered"
    }

    private static let accessibilitySettings =
        URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!

    // MARK: Observable state

    /// Mirror of `BLEPeripheral.bluetooth`, updated by `refresh()`.
    private(set) var bluetooth: BluetoothState = .unknown

    /// Polled every 2 s.
    private(set) var canPostEvents: Bool

    var keyScheme: KeyScheme {
        didSet { defaults.set(keyScheme.rawValue, forKey: Key.keyScheme) }
    }

    var language: AppLanguage {
        didSet {
            defaults.set(language.rawValue, forKey: Key.appLanguage)
            l10n = L10n(language: language)
            pairingWindow?.setTitle(l10n("pairing.window.title"))
        }
    }

    var launchAtLogin: Bool {
        didSet {
            guard launchAtLogin != oldValue, launchAtLogin != LaunchAtLogin.isEnabled else { return }
            do {
                try LaunchAtLogin.set(launchAtLogin)
            } catch {
                Self.log.error("Launch at login change failed: \(error.localizedDescription, privacy: .public)")
                launchAtLogin = oldValue
            }
        }
    }

    private(set) var l10n: L10n

    // Mirror of `controller` state, updated by `refresh()`.
    private(set) var pairedWatch: PairedWatch?
    private(set) var isPairingMode = false
    private(set) var connectedName: String?
    private var broadcastEnabled = true

    /// What the pairing window shows while it is open.
    private(set) var pairingPhase: PairingPhase = .waiting

    var isBroadcastEnabled: Bool {
        get { broadcastEnabled }
        set {
            controller.isBroadcastEnabled = newValue
            controllerChanged()
        }
    }

    var status: MenuBarStatus {
        .derive(bluetooth: bluetooth, canPostEvents: canPostEvents, isPaired: pairedWatch != nil,
                isPairingMode: isPairingMode, isBroadcastEnabled: broadcastEnabled,
                connectedName: connectedName)
    }

    var statusTitle: String {
        if case let .connected(name) = status { return l10n(status.titleKey, name) }
        return l10n(status.titleKey)
    }

    // MARK: Non-observable

    private static let log = Logger(subsystem: "com.zigmund.GarminClicker", category: "app")

    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let environment = SystemEnvironment()
    @ObservationIgnored let controller: PairingController
    @ObservationIgnored let macName = Host.current().localizedName ?? "Mac"
    @ObservationIgnored private var ble: BLEPeripheral?
    @ObservationIgnored private var pairingWindow: PairingWindow?
    @ObservationIgnored private var firstRunPrompt: AnyObject?
    @ObservationIgnored private var ticker: Task<Void, Never>?

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        controller = PairingController(store: UserDefaultsPairingStore(defaults: defaults),
                                       environment: SystemEnvironment())
        keyScheme = defaults.string(forKey: Key.keyScheme).flatMap(KeyScheme.init(rawValue:)) ?? .default
        let language = defaults.string(forKey: Key.appLanguage).flatMap(AppLanguage.init(rawValue:)) ?? .system
        self.language = language
        l10n = L10n(language: language)
        launchAtLogin = LaunchAtLogin.isEnabled
        canPostEvents = SystemEnvironment().canPostEvents
        ble = BLEPeripheral(
            controller: controller,
            macName: macName,
            onAction: { [weak self] in self?.perform($0) },
            onApprovalRequest: { [weak self] in self?.presentApproval($0) },
            onApprovalCancelled: { [weak self] in self?.refresh() },
            onChange: { [weak self] in self?.controllerChanged() })
        refresh()
        startTicker()
    }

    // MARK: Actions

    /// Opens the pairing window, or brings it to the front, and makes sure
    /// pairing mode is on. Pairing mode lasts until the window closes.
    func openPairingWindow() {
        if !controller.isPairingModeActive {
            pairingPhase = .waiting
            controller.startPairingMode()
            controllerChanged()
        }
        showPairingWindow()
    }

    /// Closes the pairing window, which stops pairing mode.
    func closePairingWindow() {
        pairingWindow?.close()
    }

    /// Answers the request shown in the pairing window.
    func answerPairingRequest(_ request: ApprovalRequest, approved: Bool) {
        // Never resolve a different request than the one the user saw.
        guard pairingPhase == .request(request), controller.pendingApproval == request else { return }
        let updates = controller.resolveApproval(approved: approved)
        // Allow ends pairing mode; Deny keeps waiting for a watch.
        pairingPhase = approved ? .paired(request.watch) : .waiting
        controllerChanged(sending: updates)
    }

    func forgetWatch() {
        controllerChanged(sending: controller.forget())
    }

    func requestInputPermission() {
        _ = CGRequestPostEventAccess()
        NSWorkspace.shared.open(Self.accessibilitySettings)
    }

    func perform(_ action: SlideAction) {
        KeySender.send(keyScheme.keystroke(for: action))
    }

    /// First run: offer pairing once when no watch is paired.
    func onLaunch() {
        guard pairedWatch == nil, firstRunPrompt == nil,
              !defaults.bool(forKey: Key.pairingPromptAnswered) else { return }
        firstRunPrompt = Prompts.askStartPairing(l10n) { [weak self] start in
            guard let self else { return }
            firstRunPrompt = nil
            defaults.set(true, forKey: Key.pairingPromptAnswered)
            if start { openPairingWindow() }
        }
    }

    // MARK: Hooks for the Bluetooth layer

    /// Re-reads controller and Bluetooth state into the observable mirror.
    /// The pairing window returns to waiting if its request is no longer
    /// pending (forget, watch unsubscribed — anything that cleared or
    /// replaced `controller.pendingApproval` without an answer) and closes if
    /// pairing mode ended other than by pairing (broadcasting turned off), or
    /// if the pairing it reports is gone (forget). Call after every
    /// controller change made outside `AppModel`.
    func refresh() {
        if let ble, bluetooth != ble.bluetooth { bluetooth = ble.bluetooth }
        if pairedWatch != controller.pairedWatch { pairedWatch = controller.pairedWatch }
        if isPairingMode != controller.isPairingModeActive { isPairingMode = controller.isPairingModeActive }
        if connectedName != controller.connectedWatchName { connectedName = controller.connectedWatchName }
        if broadcastEnabled != controller.isBroadcastEnabled { broadcastEnabled = controller.isBroadcastEnabled }

        if case let .request(shown) = pairingPhase, controller.pendingApproval != shown {
            pairingPhase = .waiting
        }
        let showsCurrentPairing = if case let .paired(watch) = pairingPhase {
            controller.pairedWatch == watch
        } else {
            false
        }
        if pairingWindow != nil, !controller.isPairingModeActive, !showsCurrentPairing {
            closePairingWindow()
        }
    }

    /// Shows a request the controller just created in the pairing window.
    func presentApproval(_ request: ApprovalRequest) {
        guard controller.pendingApproval == request else { return }
        pairingPhase = .request(request)
        showPairingWindow()
    }

    // MARK: Private

    private func showPairingWindow() {
        if let pairingWindow {
            pairingWindow.bringToFront()
            return
        }
        pairingWindow = PairingWindow(model: self) { [weak self] in self?.pairingWindowClosed() }
    }

    /// The pairing window closed by any means: stop pairing. A pending
    /// request is rejected, without a cooldown. After a pairing the mode is
    /// already off and this changes nothing.
    private func pairingWindowClosed() {
        pairingWindow = nil
        pairingPhase = .waiting
        controllerChanged(sending: controller.stopPairingMode())
    }

    /// Single funnel after any controller change: notifies `updates` to the
    /// watches, brings the service and advertising in line with the new
    /// state and refreshes the mirror and the pairing window.
    private func controllerChanged(sending updates: [StatusUpdate] = []) {
        ble?.send(updates)
        ble?.refreshAdvertising()
        refresh()
    }

    /// Every 2 s polls the event posting permission and the login item
    /// status (both can change in System Settings).
    private func startTicker() {
        ticker = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(2))
                guard let self else { return }
                let allowed = environment.canPostEvents
                if canPostEvents != allowed { canPostEvents = allowed }
                let registered = LaunchAtLogin.isEnabled
                if launchAtLogin != registered { launchAtLogin = registered }
            }
        }
    }
}
